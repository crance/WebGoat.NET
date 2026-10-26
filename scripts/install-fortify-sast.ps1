$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($env:NEXUS_REPOSITORY_URL -notlike 'https://*') {
    throw 'NEXUS_REPOSITORY_URL must use HTTPS.'
}
if ([string]::IsNullOrWhiteSpace($env:NEXUS_INSTALLER_REPOSITORY)) {
    throw 'Configure NEXUS_INSTALLER_REPOSITORY for the installer download.'
}
if (-not ($env:NEXUS_USERNAME -and $env:NEXUS_PASSWORD)) {
    throw 'Configure NEXUS_USERNAME and NEXUS_PASSWORD for the installer download.'
}
if ($env:SAST_VERSION -notmatch '^\d+\.\d+(\.\d+)?$') {
    throw 'SAST_VERSION must be a release version such as 26.2 or 26.2.0.'
}
if ($env:SAST_INSTALLER_SHA256 -notmatch '^[a-fA-F0-9]{64}$') {
    throw 'Set fortify.sast_sha256 in appsec/versions.json to the trusted installer SHA-256 before downloading.'
}
$release = [version]$env:SAST_VERSION
$installerVersion = '{0}.{1}.{2}' -f $release.Major, $release.Minor, [Math]::Max(0, $release.Build)
$installerName = "OpenText_SAST_Fortify_windows-x64_$installerVersion.exe"
$installerUrl = "$($env:NEXUS_REPOSITORY_URL.TrimEnd('/'))/repository/$env:NEXUS_INSTALLER_REPOSITORY/fortify/$env:SAST_VERSION/$installerName"

$headers = @{}
if (-not [string]::IsNullOrWhiteSpace($env:S3_HTTP_HEADERS)) {
    try {
        $headers = ConvertFrom-Json -InputObject $env:S3_HTTP_HEADERS -AsHashtable
        if ($headers -isnot [System.Collections.IDictionary]) { throw 'Expected a JSON object.' }
    } catch {
        throw 'S3_HTTP_HEADERS must contain a JSON object of HTTP headers.'
    }
}

function ConvertTo-CurlConfigValue([string]$Value) {
    '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

$setupDir = Join-Path $env:RUNNER_TEMP 'fortify-sast-setup'
$installDir = Join-Path $env:RUNNER_TEMP 'fortify-sast'
New-Item -ItemType Directory -Path $setupDir -Force | Out-Null
$installer = Join-Path $setupDir $installerName
$license = Join-Path $setupDir 'fortify.license'
$options = Join-Path $setupDir 'install.options'
try {
    try {
        # Pass the private URL and credentials through stdin, not process arguments.
        $requestConfig = @(
            'url = ' + (ConvertTo-CurlConfigValue $installerUrl)
            'user = ' + (ConvertTo-CurlConfigValue "$($env:NEXUS_USERNAME):$($env:NEXUS_PASSWORD)")
        )
        foreach ($header in $headers.GetEnumerator()) {
            $requestConfig += 'header = ' + (ConvertTo-CurlConfigValue "$($header.Key): $($header.Value)")
        }
        $downloadErrors = Join-Path $setupDir 'curl-errors.txt'
        $status = ($requestConfig -join "`n") | & curl.exe --disable --config - `
            --silent --show-error --proto '=https' --tlsv1.2 `
            --connect-timeout 10 --max-time 600 --output $installer --write-out '%{http_code}' 2> $downloadErrors
        if ($LASTEXITCODE -ne 0 -or "$status".Trim() -ne '200') { throw 'Installer download did not succeed.' }
    } catch {
        throw 'SAST installer download failed. Check the Nexus repository, versioned asset path, and credentials.'
    }
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne $env:SAST_INSTALLER_SHA256) {
        throw 'SAST installer SHA-256 mismatch. The installer will not be executed.'
    }

    if ([string]::IsNullOrWhiteSpace($env:FORTIFY_LICENSE)) {
        throw 'FORTIFY_LICENSE is empty. Set the FORTIFY_LICENSE secret to the contents of the Fortify license file.'
    }
    [IO.File]::WriteAllText($license, $env:FORTIFY_LICENSE)

    # Report the license as received so a format/encoding problem is distinguishable
    # from a license the installer rejects. Nothing sensitive is printed.
    $licenseBytes = [IO.File]::ReadAllBytes($license)
    $licenseText = [IO.File]::ReadAllText($license)
    $licenseSha = (Get-FileHash -LiteralPath $license -Algorithm SHA256).Hash
    Write-Host "License sha256:  $licenseSha"
    Write-Host "Has CR (CRLF?):  $($licenseText.Contains([char]13))"
    Write-Host "Has UTF-8 BOM:   $($licenseBytes.Length -ge 3 -and $licenseBytes[0] -eq 0xEF -and $licenseBytes[1] -eq 0xBB -and $licenseBytes[2] -eq 0xBF)"

    if ($env:SSC_URL -notlike 'https://*' -or $env:SSC_URL -match '[\r\n]') {
        throw 'SSC_URL must use HTTPS and contain no newlines.'
    }
    $template = Join-Path $PSScriptRoot '../appsec/fortify-sast.options.template'
    $installOptions = Get-Content -LiteralPath $template -Raw
    $installOptions = $installOptions.Replace('@LICENSE_PATH@', $license)
    $installOptions = $installOptions.Replace('@INSTALL_DIR@', $installDir)
    $installOptions = $installOptions.Replace('@SSC_URL@', $env:SSC_URL)
    $installOptions | Set-Content -LiteralPath $options -Encoding utf8 -NoNewline
    $process = Start-Process -FilePath $installer -ArgumentList @(
        '--mode', 'unattended', '--optionfile', "`"$options`""
    ) -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "SAST installation failed with exit code $($process.ExitCode)."
    }

    $bin = Join-Path $installDir 'bin'
    $version = & (Join-Path $bin 'sourceanalyzer.exe') -v
    if ($LASTEXITCODE -ne 0 -or "$version" -notmatch "\b$([regex]::Escape($env:SAST_VERSION))\b") {
        throw 'Installed sourceanalyzer does not match the configured SAST version.'
    }
    $version

    # Report where the installer put the license, so a later license failure is
    # traceable to a real path instead of an assumption.
    $licenseCandidates = @(
        (Join-Path $installDir 'fortify.license')
        (Join-Path $installDir 'Core\config\fortify.license')
        (Join-Path $installDir 'config\fortify.license')
    )
    $foundLicense = $false
    foreach ($candidate in $licenseCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $foundLicense = $true
            Write-Host "Installed license: $candidate"
        }
    }
    if (-not $foundLicense) {
        Write-Warning 'Installer did not place a license in the install directory; sourceanalyzer may need an explicit license path.'
    }

    $bin >> $env:GITHUB_PATH
} finally {
    Remove-Item -LiteralPath $setupDir -Recurse -Force -ErrorAction SilentlyContinue
}
