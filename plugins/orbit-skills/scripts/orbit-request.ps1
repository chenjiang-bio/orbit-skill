[CmdletBinding()]
param(
    [ValidateSet('GET', 'POST')]
    [string]$Method = 'GET',

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$Query = '',
    [ValidateRange(1, 2147483647)]
    [int]$Timeout = 30,
    [switch]$AllowPost,
    [string]$BodyFile,
    [switch]$BodyStdin,
    [switch]$Multipart,
    [string[]]$FormField = @(),
    [string[]]$FormFile = @(),
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$DefaultBaseUrl = 'https://db-orbit.com'
$LocalConfig = Join-Path $PSScriptRoot 'orbit-request.local.env'
$LocalBaseUrl = $null
if (Test-Path -LiteralPath $LocalConfig -PathType Leaf) {
    foreach ($configLine in [System.IO.File]::ReadAllLines($LocalConfig)) {
        if (-not $configLine -or $configLine.StartsWith('#')) { continue }
        if ($configLine.StartsWith('ORBIT_BASE_URL=') -and -not $LocalBaseUrl) {
            $LocalBaseUrl = $configLine.Substring('ORBIT_BASE_URL='.Length)
            if (($LocalBaseUrl.StartsWith('"') -and $LocalBaseUrl.EndsWith('"')) -or ($LocalBaseUrl.StartsWith("'") -and $LocalBaseUrl.EndsWith("'"))) {
                $LocalBaseUrl = $LocalBaseUrl.Substring(1, $LocalBaseUrl.Length - 2)
            }
        }
        else {
            [Console]::Error.WriteLine('orbit-request httpStatus=none curlExit=none method=GET path=none timeout=30 error=invalid_local_config')
            exit 10
        }
    }
}
$BaseUrl = if ($env:ORBIT_BASE_URL) { $env:ORBIT_BASE_URL } elseif ($LocalBaseUrl) { $LocalBaseUrl } else { $DefaultBaseUrl }

function Write-Status {
    param(
        [string]$HttpStatus = 'none',
        [string]$CurlExit = 'none',
        [string]$Error = ''
    )

    $line = "orbit-request httpStatus=$HttpStatus curlExit=$CurlExit method=$Method path=$Path timeout=$Timeout"
    if ($Error) { $line += " error=$Error" }
    [Console]::Error.WriteLine($line)
}

function Exit-LocalError {
    param([string]$Reason)
    Write-Status -Error $Reason
    exit 10
}

function Test-ReadableFile {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $false }
    try {
        $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $stream.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function Split-FormEntry {
    param([string]$Entry, [string]$ErrorName)
    if (-not $Entry -or $Entry.Contains("`n") -or $Entry.Contains("`r")) { Exit-LocalError $ErrorName }
    $separator = $Entry.IndexOf('=')
    if ($separator -lt 1) { Exit-LocalError $ErrorName }
    $name = $Entry.Substring(0, $separator)
    $value = $Entry.Substring($separator + 1)
    if ($name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') { Exit-LocalError 'invalid_form_name' }
    return @($name, $value)
}

if ($Help) {
    @'
Usage:
  orbit-request.ps1 -Method GET -Path /api/... [-Query 'key=value&...'] [-Timeout 30]
  orbit-request.ps1 -Method POST -Path /api/... -AllowPost [-BodyFile request.json] [-Timeout 30]
  orbit-request.ps1 -Method POST -Path /api/... -AllowPost -Multipart [-FormField 'name=value'] [-FormFile 'name=path'] [-Timeout 30]

Writes the native response body to stdout and one status line to stderr.
Windows PowerShell JSON POST bodies must use a UTF-8 body file; -BodyStdin is rejected.
Exit codes: 0=2xx HTTP response, 10=invalid local arguments, 20=curl/transport failure, 21=non-2xx HTTP response.
'@ | Write-Output
    exit 0
}

if (-not $Path.StartsWith('/api/')) { Exit-LocalError 'path_must_start_with_api' }
if ($Path.Contains('?') -or $Path.Contains('..')) { Exit-LocalError 'unsafe_path' }
if ($Query.Contains("`n") -or $Query.Contains("`r")) { Exit-LocalError 'unsafe_query' }
if ($Method -eq 'POST' -and -not $AllowPost) { Exit-LocalError 'post_requires_allow_post' }
if ($BodyFile -and $BodyStdin) { Exit-LocalError 'multiple_body_sources' }
if ($Multipart -and ($BodyFile -or $BodyStdin)) { Exit-LocalError 'mixed_body_modes' }
if (-not $Multipart -and (($FormField.Count -gt 0) -or ($FormFile.Count -gt 0))) { Exit-LocalError 'form_requires_multipart' }
if ($Method -eq 'GET' -and ($BodyFile -or $BodyStdin -or $Multipart)) { Exit-LocalError 'get_cannot_have_body' }
# Windows PowerShell 5.1 can irreversibly transcode non-ASCII pipeline text
# before this child process receives stdin. Require byte-stable UTF-8 files.
if ($BodyStdin) { Exit-LocalError 'body_stdin_unsupported_on_windows' }
if ($BodyFile -and -not (Test-ReadableFile -FilePath $BodyFile)) { Exit-LocalError 'unreadable_body_file' }
if ($Multipart -and (($FormField.Count + $FormFile.Count) -eq 0)) { Exit-LocalError 'empty_multipart' }

$parsedFields = @()
foreach ($entry in $FormField) {
    $parsedFields += ,(Split-FormEntry -Entry $entry -ErrorName 'invalid_form_field')
}
$parsedFiles = @()
foreach ($entry in $FormFile) {
    $parts = Split-FormEntry -Entry $entry -ErrorName 'invalid_form_file'
    if (-not (Test-ReadableFile -FilePath $parts[1])) { Exit-LocalError 'unreadable_form_file' }
    $parsedFiles += ,$parts
}

if ($BaseUrl -notmatch '^https?://[^/?#]+$') { Exit-LocalError 'invalid_base_url' }
$ApiKey = $env:ORBIT_REQUEST_API_KEY
if ($null -ne $ApiKey -and ($ApiKey.Contains("`n") -or $ApiKey.Contains("`r"))) { Exit-LocalError 'invalid_api_key' }
if ([string]::IsNullOrWhiteSpace($ApiKey)) { Exit-LocalError 'missing_api_key' }
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $curl) { Exit-LocalError 'curl_not_found' }

$url = "$BaseUrl$Path"
if ($Query) { $url += "?$Query" }
$responseFile = [System.IO.Path]::GetTempFileName()

try {
    $arguments = @(
        '--silent', '--show-error', '--request', $Method,
        '--header', 'Accept: application/json',
        '--header', "Authorization: Bearer $ApiKey",
        '--max-time', "$Timeout",
        '--output', $responseFile,
        '--write-out', '%{http_code}',
        $url
    )

    if ($Method -eq 'POST') {
        if ($Multipart) {
            foreach ($parts in $parsedFields) {
                $arguments += @('--form-string', "$($parts[0])=$($parts[1])")
            }
            foreach ($parts in $parsedFiles) {
                $arguments += @('--form', "$($parts[0])=@$($parts[1])")
            }
        }
        else {
            $arguments += @('--header', 'Content-Type: application/json')
            if ($BodyFile) {
                $arguments += @('--data-binary', "@$BodyFile")
            }
        }
    }

    $httpStatus = (& curl.exe @arguments | Out-String).Trim()
    $curlExit = $LASTEXITCODE
    if (Test-Path -LiteralPath $responseFile) {
        $responseBytes = [System.IO.File]::ReadAllBytes($responseFile)
        [Console]::OpenStandardOutput().Write($responseBytes, 0, $responseBytes.Length)
    }

    if ($curlExit -ne 0) {
        $reportedStatus = if ($httpStatus) { $httpStatus } else { 'none' }
        Write-Status -HttpStatus $reportedStatus -CurlExit "$curlExit" -Error 'transport'
        exit 20
    }

    Write-Status -HttpStatus $httpStatus -CurlExit '0'
    if ($httpStatus -match '^2\d\d$') { exit 0 }
    exit 21
}
catch {
    Write-Status -Error 'wrapper_failure'
    exit 20
}
finally {
    if (Test-Path -LiteralPath $responseFile) { Remove-Item -LiteralPath $responseFile -Force -ErrorAction SilentlyContinue }
}
