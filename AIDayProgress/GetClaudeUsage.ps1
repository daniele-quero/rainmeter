param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-ClaudeCredentials {
    $configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
    $path = Join-Path $configDir '.credentials.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Claude credentials were not found at '$path'. Run 'claude auth login'."
    }

    $oauth = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).claudeAiOauth
    if ($null -eq $oauth) {
        throw "Claude credentials contain no OAuth session. Run 'claude auth login'."
    }
    return $oauth
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

try {
    $oauth = Get-ClaudeCredentials

    if (-not (Test-ClaudeToken $oauth)) {
        # The Claude CLI renews its own session; Rainmeter's PATH may be reduced.
        $claudeCommand = Get-Command claude.exe -ErrorAction SilentlyContinue
        $claudeExecutable = if ($claudeCommand) {
            $claudeCommand.Source
        }
        else {
            @(
                "$env:LOCALAPPDATA\Microsoft\WinGet\Links\claude.exe",
                "$env:USERPROFILE\.local\bin\claude.exe"
            ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        }
        if ($claudeExecutable) {
            & $claudeExecutable auth status *> $null
            $oauth = Get-ClaudeCredentials
        }
        if (-not (Test-ClaudeToken $oauth)) {
            throw "The Claude access token is expired. Run 'claude auth login'."
        }
    }

    $headers = @{
        Authorization = "Bearer $($oauth.accessToken)"
        'anthropic-beta' = 'oauth-2025-04-20'
        'User-Agent' = 'Rainmeter-AIDayProgress'
    }
    $api = Invoke-RestMethod -Uri 'https://api.anthropic.com/api/oauth/usage' -Headers $headers

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
