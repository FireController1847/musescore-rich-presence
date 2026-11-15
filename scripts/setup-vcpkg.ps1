$ErrorActionPreference = 'Stop'
$root = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { Join-Path $HOME 'vcpkg' }
$toolchain = Join-Path $root 'scripts/buildsystems/vcpkg.cmake'
if (-not (Test-Path -LiteralPath $toolchain)) {
    if ($env:VCPKG_ROOT -or (Test-Path -LiteralPath $root)) {
        throw "Invalid vcpkg checkout: $root. Set VCPKG_ROOT to a valid checkout or use an empty default location."
    }
    git clone --branch 2026.03.18 https://github.com/microsoft/vcpkg.git $root
    if ($LASTEXITCODE -ne 0) { throw 'vcpkg clone failed.' }
}
if (-not (Test-Path -LiteralPath (Join-Path $root 'vcpkg.exe'))) {
    & (Join-Path $root 'bootstrap-vcpkg.bat') -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw 'vcpkg bootstrap failed.' }
}
Write-Host "vcpkg is ready at $root. Select dev-vcpkg or release-vcpkg to install Qt dependencies."
