$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $projectRoot '.tools'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
$manifest = Get-Content -LiteralPath (Join-Path $projectRoot 'tools.json') -Raw | ConvertFrom-Json
foreach ($toolName in @('rojo', 'lune', 'stylua')) {
    $toolInfo = $manifest.$toolName
    $archive = Join-Path $toolsDir "$toolName.zip"
    Write-Host "Downloading $toolName $($toolInfo.version)..."
    Invoke-WebRequest -Uri $toolInfo.url -OutFile $archive -UseBasicParsing
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $toolInfo.sha256) { throw "SHA256 mismatch for $toolName" }
    Expand-Archive -LiteralPath $archive -DestinationPath $toolsDir -Force
}
Write-Host 'Tools are installed in .tools (no global installation).'
