// TGA (as written by tools/make_media.py) to PNG, with Node only, so the
// web build needs no Python (Vercel). Handles uncompressed and RLE
// true-colour TGA, 24 or 32 bits, either origin.
import { deflateSync } from "node:zlib";

const CRC_TABLE = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

export function decodeTga(buf) {
  const idLength = buf[0], imageType = buf[2];
  const width = buf.readUInt16LE(12), height = buf.readUInt16LE(14);
  const bpp = buf[16] / 8, topOrigin = (buf[17] & 0x20) !== 0;
  if (![2, 10].includes(imageType) || ![3, 4].includes(bpp)) throw new Error(`unsupported TGA (type ${imageType}, ${bpp * 8} bits)`);
  const colorMapLength = buf.readUInt16LE(5) * Math.ceil(buf[7] / 8);
  let pos = 18 + idLength + colorMapLength;
  const n = width * height;
  const src = Buffer.alloc(n * bpp);
  if (imageType === 2) {
    buf.copy(src, 0, pos, pos + n * bpp);
  } else {
    let i = 0;
    while (i < n) {
      const head = buf[pos++], count = (head & 0x7f) + 1;
      if (head & 0x80) {
        for (let k = 0; k < count; k++) buf.copy(src, (i + k) * bpp, pos, pos + bpp);
        pos += bpp;
      } else {
        buf.copy(src, i * bpp, pos, pos + count * bpp);
        pos += count * bpp;
      }
      i += count;
    }
  }
  const rgba = Buffer.alloc(n * 4);
  for (let y = 0; y < height; y++) {
    const row = topOrigin ? y : height - 1 - y;
    for (let x = 0; x < width; x++) {
      const s = (row * width + x) * bpp, d = (y * width + x) * 4;
      rgba[d] = src[s + 2];
      rgba[d + 1] = src[s + 1];
      rgba[d + 2] = src[s];
      rgba[d + 3] = bpp === 4 ? src[s + 3] : 255;
    }
  }
  return { width, height, rgba };
}

export function encodePng({ width, height, rgba }) {
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr.set([8, 6, 0, 0, 0], 8);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}
