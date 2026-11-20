// Short original UI sounds, synthesised with WebAudio when they play.
// No sound file, nothing from the game. Muted state kept in localStorage;
// the audio context only starts after a key press or a click (browser rule).

const STORE = "cnc-sound";
let ctx = null;
let muted = localStorage.getItem(STORE) === "off";

export function isMuted() {
  return muted;
}

export function setMuted(value) {
  muted = value;
  try {
    localStorage.setItem(STORE, muted ? "off" : "on");
  } catch {
    // private mode: the choice is not kept
  }
}

// Call from a user gesture (keydown, pointerdown).
export function unlockAudio() {
  if (ctx || muted) return;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (AC) ctx = new AC();
}

// One note: a sine or triangle with a quick attack and a soft decay.
function tone(freq, start, length, { type = "triangle", volume = 0.18, slideTo = null } = {}) {
  const t = ctx.currentTime + start;
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t);
  if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t + length);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(volume, t + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + length);
  osc.connect(gain).connect(ctx.destination);
  osc.start(t);
  osc.stop(t + length + 0.02);
}

const SOUNDS = {
  // the call leaves: a short rising whoosh
  send: () => tone(420, 0, 0.12, { type: "sine", volume: 0.12, slideTo: 900 }),
  // right call: two bright notes
  success: () => {
    tone(659, 0, 0.18);
    tone(988, 0.09, 0.3);
  },
  // wrong call: a low falling buzz
  error: () => {
    tone(196, 0, 0.22, { type: "sawtooth", volume: 0.07, slideTo: 140 });
    tone(185, 0.05, 0.22, { type: "square", volume: 0.04, slideTo: 130 });
  },
  // every 5 in a row: a quick rising arpeggio
  streak: () => [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.12 + i * 0.07, 0.28, { volume: 0.14 })),
};

export function play(name) {
  if (muted || !ctx || !SOUNDS[name]) return;
  if (ctx.state === "suspended") ctx.resume();
  SOUNDS[name]();
}
