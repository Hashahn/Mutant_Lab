param([switch]$Format)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    $stylua = Join-Path $projectRoot '.tools/stylua.exe'
    $lune = Join-Path $projectRoot '.tools/lune.exe'
    $rojo = Join-Path $projectRoot '.tools/rojo.exe'
    foreach ($tool in @($stylua, $lune, $rojo)) {
        if (-not (Test-Path -LiteralPath $tool)) { throw 'Run scripts/bootstrap.ps1 first.' }
    }
    if ($Format) { & $stylua src tests } else { & $stylua --check src tests }
    if ($LASTEXITCODE -ne 0) { throw 'StyLua failed.' }
    & $lune run tests/run
    if ($LASTEXITCODE -ne 0) { throw 'Luau tests failed.' }
    New-Item -ItemType Directory -Force -Path build | Out-Null
    & $rojo build default.project.json -o build/MutantLab.rbxlx
    if ($LASTEXITCODE -ne 0) { throw 'Rojo build failed.' }
    Write-Host 'All automated checks passed. Studio multiplayer tests are still required.'
} finally { Pop-Location }
