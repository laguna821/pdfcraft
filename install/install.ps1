<#
  Achmage PDFCraft installer for Windows 10/11 (x64; ARM64 runs it under emulation).

    irm https://raw.githubusercontent.com/laguna821/pdfcraft/main/install/install.ps1 | iex

  Downloads the latest release from GitHub, checks its SHA-256 against SHA256SUMS.txt and installs
  the MSI (one administrator prompt). Files fetched by PowerShell carry no "downloaded from the
  internet" mark, so SmartScreen does not stop the unsigned installer.

  Options (set before running, e.g. `$env:ACHMAGE_PORTABLE = 1; irm … | iex`):
    ACHMAGE_PORTABLE=1     no administrator rights: unpack the portable build into
                           %LOCALAPPDATA%\Programs\Achmage PDFCraft and add a Start menu shortcut
    ACHMAGE_VERSION=0.1.0  a specific release instead of the latest
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = 'laguna821/pdfcraft'
$Api = if ($env:ACHMAGE_VERSION) { "https://api.github.com/repos/$Repo/releases/tags/v$($env:ACHMAGE_VERSION.TrimStart('v'))" } else { "https://api.github.com/repos/$Repo/releases/latest" }

Write-Host '==> Achmage PDFCraft: looking up the release on GitHub'
$release = Invoke-RestMethod -Uri $Api -Headers @{ 'User-Agent' = 'achmage-pdfcraft-installer' }
$portable = [bool]$env:ACHMAGE_PORTABLE
$pattern = if ($portable) { '-windows-x64-portable\.zip$' } else { '-windows-x64\.msi$' }
$asset = $release.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
$sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1
if (-not $asset) { throw "no Windows package in release $($release.tag_name)" }

$work = Join-Path ([IO.Path]::GetTempPath()) ("achmage-pdfcraft-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$ok = $false
try {
  $file = Join-Path $work $asset.name
  Write-Host "==> downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)"
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -UseBasicParsing
  if ($sums) {
    $sumFile = Join-Path $work 'SHA256SUMS.txt'
    Invoke-WebRequest -Uri $sums.browser_download_url -OutFile $sumFile -UseBasicParsing
    $line = Get-Content $sumFile | Where-Object { $_ -match ([regex]::Escape($asset.name) + '$') } | Select-Object -First 1
    if (-not $line) { throw "SHA256SUMS.txt has no entry for $($asset.name)" }
    $expected = ($line -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant()
    if ($expected -ne $actual) { throw "checksum mismatch for $($asset.name)" }
    Write-Host '==> checksum OK'
  }

  if ($portable) {
    $dest = Join-Path $env:LOCALAPPDATA 'Programs\Achmage PDFCraft'
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    $unpack = Join-Path $work 'unpack'
    Expand-Archive -Path $file -DestinationPath $unpack
    $inner = Get-ChildItem $unpack -Directory | Select-Object -First 1
    $source = if ($inner -and (Test-Path (Join-Path $inner.FullName 'pdfcraft.exe'))) { $inner.FullName } else { $unpack }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path (Join-Path $source '*') -Destination $dest -Recurse -Force
    $exe = Join-Path $dest 'pdfcraft.exe'
    $shell = New-Object -ComObject WScript.Shell
    $programs = [Environment]::GetFolderPath('Programs')
    $link = $shell.CreateShortcut((Join-Path $programs 'Achmage PDFCraft.lnk'))
    $link.TargetPath = $exe
    $link.WorkingDirectory = $dest
    $link.Save()
    Write-Host "==> installed to $dest (Start menu: Achmage PDFCraft)"
  } else {
    Write-Host '==> installing (Windows will ask for administrator permission once)'
    $log = Join-Path $work 'install.log'
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$file`"", '/passive', '/norestart', '/l*v', "`"$log`"") -Verb RunAs -Wait -PassThru
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "msiexec failed with exit code $($p.ExitCode) (log: $log)" }
    Write-Host '==> installed: Start menu and desktop shortcut "Achmage PDFCraft"'
  }
  $ok = $true
} finally {
  # Kept on failure, for the msiexec log.
  if ($ok) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
}
