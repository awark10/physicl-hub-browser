# Builds dist\PhysiclHubBrowser_v<version>.mzp: the script files plus an mzp.run that runs the
# installer from the extracted temp folder. Usage: powershell -ExecutionPolicy Bypass -File build_mzp.ps1
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$m = Select-String -Path (Join-Path $root 'PHB_UI.ms') -Pattern 'global PHB_version = "([0-9.]+)"'
if (-not $m) { throw 'PHB_version not found in PHB_UI.ms' }
$version = $m.Matches[0].Groups[1].Value

$stage = Join-Path ([IO.Path]::GetTempPath()) ('phb_mzp_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    foreach ($f in 'Install_PhysiclHubBrowser.ms', 'PhysiclHubBrowser.mcr', 'PHB_Client.ms', 'PHB_UI.ms') {
        Copy-Item (Join-Path $root $f) $stage
    }
    # mzp.run: Max extracts the package to a temp folder and runs the installer from there;
    # the installer copies the files into userMacros
    @(
        # No "version" line: mzp.run only accepts a plain number there, not 1.1.4
        "name ""Physicl Hub Browser v$version"""
        'description "Backplates, decals, grass, buildings and textures from the Physicl Knowledge Hub"'
        'run "Install_PhysiclHubBrowser.ms"'
        'drop "Install_PhysiclHubBrowser.ms"'
        'clear temp on MAX exit'
    ) | Set-Content -Path (Join-Path $stage 'mzp.run') -Encoding ASCII

    $dist = Join-Path $root 'dist'
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    $zip = Join-Path $dist "PhysiclHubBrowser_v$version.zip"
    $mzp = [IO.Path]::ChangeExtension($zip, '.mzp')
    Remove-Item $zip, $mzp -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
    Move-Item $zip $mzp
    Write-Output $mzp
}
finally {
    Remove-Item -Recurse -Force $stage
}
