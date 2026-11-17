@echo off
rem Met a jour Command & Conquer depuis GitHub.
rem A placer dans le dossier Interface\AddOns de Forever, puis double-cliquer.
setlocal
for %%I in ("%~dp0.") do set "DIRNAME=%%~nxI"
if /I not "%DIRNAME%"=="AddOns" (
  echo Ce fichier doit etre dans le dossier Interface\AddOns.
  pause
  exit /b 1
)
set "URL=https://github.com/silentdany/command-and-conquer/archive/refs/heads/claude/vigilant-archimedes-96uwzo.zip"
set "TMPZIP=%TEMP%\cnc-update.zip"
set "TMPDIR=%TEMP%\cnc-update"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%TMPZIP%';" ^
  "if (Test-Path '%TMPDIR%') { Remove-Item -Recurse -Force '%TMPDIR%' };" ^
  "Expand-Archive -Path '%TMPZIP%' -DestinationPath '%TMPDIR%';" ^
  "$src = Join-Path (Get-ChildItem '%TMPDIR%' | Select-Object -First 1).FullName 'CommandAndConquer';" ^
  "$dst = Join-Path '%~dp0' 'CommandAndConquer';" ^
  "if (Test-Path $dst) { Remove-Item -Recurse -Force $dst };" ^
  "Copy-Item -Recurse $src $dst;" ^
  "$v = (Select-String -Path (Join-Path $dst 'CommandAndConquer.toc') -Pattern '^## Version: (.*)').Matches[0].Groups[1].Value;" ^
  "Write-Host ('Command & Conquer ' + $v + ' installe. Tape /reload en jeu.')"
if errorlevel 1 echo La mise a jour a echoue (voir le message ci-dessus).
pause
