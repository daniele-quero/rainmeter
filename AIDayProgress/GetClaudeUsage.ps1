param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-ClaudeCredentials {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Claude credentials were not found at '$Path'. Run 'claude auth login'."
    }

    $credentials = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($null -eq $credentials.claudeAiOauth) {
        throw "Claude credentials contain no OAuth session. Run 'claude auth login'."
    }
    return $credentials
}

function Test-ClaudeToken {
    param($OAuth)

    $expiresAt = 0L
    return -not [string]::IsNullOrWhiteSpace($OAuth.accessToken) -and
        [long]::TryParse([string]$OAuth.expiresAt, [ref]$expiresAt) -and
        $expiresAt -gt [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + 30000
}

function Get-ClaudeNumber {
    param($Value, [string]$Name)

    $number = 0.0
    if ($null -eq $Value -or $Value -is [bool] -or -not [double]::TryParse(
        [string]$Value,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
    ) -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0) {
        throw "Claude returned no valid numeric '$Name' value."
    }
    return $number
}

function Update-ClaudeCredentials {
    param([string]$Path)

    # Serialize widget refreshes so a rotated refresh token is not reused.
    $mutexName = 'Local\Rainmeter-AIDayProgress-ClaudeOAuth-' + [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $mutex = [System.Threading.Mutex]::new($false, $mutexName)
    $ownsMutex = $false
    $temporaryPath = $null
    try {
        try {
            $ownsMutex = $mutex.WaitOne(45000)
        }
        catch [System.Threading.AbandonedMutexException] {
            $ownsMutex = $true
        }
        if (-not $ownsMutex) {
            throw 'Timed out waiting for another Claude token refresh.'
        }

        $credentials = Get-ClaudeCredentials $Path
        $oauth = $credentials.claudeAiOauth
        if (Test-ClaudeToken $oauth) {
            return $oauth
        }
        if ([string]::IsNullOrWhiteSpace($oauth.refreshToken)) {
            throw "The Claude session has no refresh token. Run 'claude auth login'."
        }

        $previousAccessToken = $oauth.accessToken
        $previousRefreshToken = $oauth.refreshToken
        $temporaryPath = Join-Path (Split-Path -Parent $Path) ([System.IO.Path]::GetRandomFileName())
        $temporaryFile = [System.IO.File]::Open($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $temporaryFile.Dispose()
        # Avoid security-module autoloading through PSModulePath inherited from another PowerShell version.
        $credentialAcl = [System.Security.AccessControl.FileSecurity]::new($Path, [System.Security.AccessControl.AccessControlSections]::Access)
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            [System.IO.File]::SetAccessControl($temporaryPath, $credentialAcl)
        }
        else {
            [System.IO.FileSystemAclExtensions]::SetAccessControl([System.IO.FileInfo]::new($temporaryPath), $credentialAcl)
        }

        $body = @{
            grant_type = 'refresh_token'
            refresh_token = $previousRefreshToken
            client_id = '9d1c250a-e61b-44d9-88ed-5944d1962f5e'
        } | ConvertTo-Json -Compress
        try {
            $refreshed = Invoke-RestMethod -Uri 'https://platform.claude.com/v1/oauth/token' -Method Post -ContentType 'application/json' -Body $body -UserAgent 'Rainmeter-AIDayProgress' -TimeoutSec 30
        }
        catch {
            $response = $_.Exception.Response
            if ($null -ne $response -and [int]$response.StatusCode -eq 429) {
                $retryAfter = if ($response.Headers -is [System.Collections.Specialized.NameValueCollection]) {
                    $response.Headers['Retry-After']
                }
                else {
                    [string]$response.Headers.RetryAfter
                }
                $retryMessage = if ($retryAfter) { " Retry-After: $retryAfter." } else { '' }
                throw "Claude OAuth token refresh is rate limited (HTTP 429).$retryMessage Try again later; if this persists, run 'claude auth login'."
            }
            if ($null -ne $response -and [int]$response.StatusCode -in @(400, 401)) {
                throw "Claude OAuth token refresh was rejected (HTTP $([int]$response.StatusCode)). Run 'claude auth login'."
            }
            throw
        }
        if ($refreshed.access_token -isnot [string] -or [string]::IsNullOrWhiteSpace($refreshed.access_token)) {
            throw 'Claude returned no valid refreshed access token.'
        }
        $expiresIn = Get-ClaudeNumber $refreshed.expires_in 'expires_in'
        if ($expiresIn -le 30) {
            throw 'Claude returned an expired or expiring access token.'
        }
        $expiresAt = [DateTimeOffset]::UtcNow.AddSeconds($expiresIn).ToUnixTimeMilliseconds()
        $refreshToken = $previousRefreshToken
        if ($null -ne $refreshed.PSObject.Properties['refresh_token']) {
            if ($refreshed.refresh_token -isnot [string] -or [string]::IsNullOrWhiteSpace($refreshed.refresh_token)) {
                throw 'Claude returned no valid refreshed refresh token.'
            }
            $refreshToken = $refreshed.refresh_token
        }

        $credentials = Get-ClaudeCredentials $Path
        $oauth = $credentials.claudeAiOauth
        if ($oauth.accessToken -cne $previousAccessToken -or $oauth.refreshToken -cne $previousRefreshToken) {
            if (Test-ClaudeToken $oauth) {
                return $oauth
            }
            throw "Claude credentials changed during token refresh. Retry or run 'claude auth login'."
        }
        $oauth | Add-Member -NotePropertyName accessToken -NotePropertyValue $refreshed.access_token -Force
        $oauth | Add-Member -NotePropertyName refreshToken -NotePropertyValue $refreshToken -Force
        $oauth | Add-Member -NotePropertyName expiresAt -NotePropertyValue $expiresAt -Force
        if ($refreshed.scope -is [string] -and -not [string]::IsNullOrWhiteSpace($refreshed.scope)) {
            $oauth | Add-Member -NotePropertyName scopes -NotePropertyValue @($refreshed.scope -split '\s+' | Where-Object { $_ }) -Force
        }

        [System.IO.File]::WriteAllText(
            $temporaryPath,
            ($credentials | ConvertTo-Json -Depth 100),
            [System.Text.UTF8Encoding]::new($false)
        )
        [System.IO.File]::Replace($temporaryPath, $Path, [System.Management.Automation.Language.NullString]::Value)
        return $oauth
    }
    finally {
        try {
            if ([System.IO.File]::Exists($temporaryPath)) {
                [System.IO.File]::Delete($temporaryPath)
            }
        }
        finally {
            if ($ownsMutex) {
                $mutex.ReleaseMutex()
            }
            $mutex.Dispose()
        }
    }
}

try {
    $configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
    $credentialsPath = Join-Path $configDir '.credentials.json'
    $oauth = (Get-ClaudeCredentials $credentialsPath).claudeAiOauth
    if (-not (Test-ClaudeToken $oauth)) {
        $oauth = Update-ClaudeCredentials $credentialsPath
    }

    $headers = @{
        Authorization = "Bearer $($oauth.accessToken)"
        'anthropic-beta' = 'oauth-2025-04-20'
        'User-Agent' = 'Rainmeter-AIDayProgress'
    }
    $api = Invoke-RestMethod -Uri 'https://api.anthropic.com/api/oauth/usage' -Headers $headers -TimeoutSec 30

    $extra = $api.extra_usage
    if ($null -ne $extra -and $extra.is_enabled -eq $true -and $null -ne $extra.utilization) {
        $value = Get-ClaudeNumber $extra.utilization 'extra_usage.utilization'
    }
    elseif ($null -ne $api.five_hour -and $null -ne $api.five_hour.utilization) {
        $value = Get-ClaudeNumber $api.five_hour.utilization 'five_hour.utilization'
    }
    else {
        throw 'Claude returned no usage percentage for this account.'
    }

    $formattedValue = [Math]::Round($value, 2).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    [Console]::Out.Write($formattedValue)
}
catch {
    [Console]::Error.WriteLine("Unable to get Claude usage: $($_.Exception.Message)")
    exit 1
}
