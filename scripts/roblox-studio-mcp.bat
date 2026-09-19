@echo off
setlocal
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Roblox\Versions\*\StudioMCP.exe\" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName"`) do (
    "%%F" %*
    exit /b %ERRORLEVEL%
)
