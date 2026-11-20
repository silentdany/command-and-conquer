@echo off
rem Met a jour Command & Conquer depuis GitHub.
rem A placer dans le dossier Interface\AddOns de Forever, puis double-cliquer.
rem Met aussi a jour l'add-on de test CnCProbe s'il est installe.
rem Copie ensuite le rapport de test de la derniere session (SavedVariables)
rem dans le presse-papiers : il suffit de le coller a Claude.
setlocal
for %%I in ("%~dp0.") do set "DIRNAME=%%~nxI"
if /I not "%DIRNAME%"=="AddOns" (
  echo Ce fichier doit etre dans le dossier Interface\AddOns.
  pause
  exit /b 1
)
set "BRANCH=main"
set "URL=https://github.com/silentdany/command-and-conquer/archive/refs/heads/%BRANCH%.zip"
set "TMPZIP=%TEMP%\cnc-update.zip"
set "TMPDIR=%TEMP%\cnc-update"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%TMPZIP%';" ^
  "if (Test-Path '%TMPDIR%') { Remove-Item -Recurse -Force '%TMPDIR%' };" ^
  "Expand-Archive -Path '%TMPZIP%' -DestinationPath '%TMPDIR%';" ^
  "$root = (Get-ChildItem '%TMPDIR%' | Select-Object -First 1).FullName;" ^
  "$src = Join-Path $root 'CommandAndConquer';" ^
  "$dst = Join-Path '%~dp0' 'CommandAndConquer';" ^
  "if (Test-Path $dst) { Remove-Item -Recurse -Force $dst };" ^
  "Copy-Item -Recurse $src $dst;" ^
  "$probe = Join-Path '%~dp0' 'CnCProbe';" ^
  "if (Test-Path $probe) { Remove-Item -Recurse -Force $probe; Copy-Item -Recurse (Join-Path $root 'probe\CnCProbe') $probe; Write-Host 'CnCProbe mis a jour.' };" ^
  "Copy-Item (Join-Path $root 'tools\update-cnc.bat') (Join-Path '%~dp0' 'update-cnc.new.bat') -Force;" ^
  "$v = (Select-String -Path (Join-Path $dst 'CommandAndConquer.toc') -Pattern '^## Version: (.*)').Matches[0].Groups[1].Value;" ^
  "Write-Host ('Command & Conquer ' + $v + ' installe. Tape /reload en jeu.');" ^
  "$wtf = Join-Path (Resolve-Path (Join-Path '%~dp0' '..\..')).Path 'WTF\Account';" ^
  "if (Test-Path $wtf) {" ^
  "  $files = @('CommandAndConquer.lua', 'CnCProbe.lua') | ForEach-Object { Get-ChildItem -Path $wtf -Recurse -Filter $_ -ErrorAction SilentlyContinue | Where-Object { $_.DirectoryName -like '*SavedVariables' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 } | Where-Object { $_ };" ^
  "  if ($files) { ($files | ForEach-Object { '-- ' + $_.FullName; Get-Content -Raw $_.FullName }) -join [Environment]::NewLine | Set-Clipboard; Write-Host 'Rapport de la derniere session copie dans le presse-papiers : colle-le a Claude.' }" ^
  "  else { Write-Host 'Pas encore de rapport (il est ecrit a la deconnexion ou au /reload).' }" ^
  "}"
if errorlevel 1 echo La mise a jour a echoue (voir le message ci-dessus).
if exist "%~dp0update-cnc.new.bat" (
  rem Le script se met a jour lui-meme en dernier (cmd lit le .bat au fil de l'eau).
  pause
  move /y "%~dp0update-cnc.new.bat" "%~f0" >nul & exit /b
)
pause
