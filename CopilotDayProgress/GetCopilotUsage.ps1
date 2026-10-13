param(
    [string]$UsageAccount = 'daniele-quero_Alten',
    [double]$CreditLimit = 35000
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$hostName = 'github.com'

function Get-QuotaNumber {
    param($Quota, [string]$Name)

    $property = $Quota.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value -or $property.Value -is [bool]) {
        throw "GitHub returned no numeric premium interaction '$Name' value."
    }

    $number = 0.0
    if (-not [double]::TryParse(
        [string]$property.Value,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$number
    ) -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0) {
        throw "GitHub returned an invalid premium interaction '$Name' value."
    }

    return $number
}

try {
    if ([double]::IsNaN($CreditLimit) -or [double]::IsInfinity($CreditLimit) -or $CreditLimit -le 0) {
        throw 'CreditLimit must be a positive, finite number of AI credits.'
    }

    $ghCommand = Get-Command gh.exe -ErrorAction SilentlyContinue
    if ($ghCommand) {
        $ghExecutable = $ghCommand.Source
    }
    else {
        $ghExecutable = @(
            "$env:ProgramFiles\GitHub CLI\gh.exe",
            "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe",
            "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
        ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        if (-not $ghExecutable) {
            throw 'GitHub CLI executable was not found. Install GitHub CLI or add gh.exe to PATH.'
        }
    }

    $token = & $ghExecutable auth token --hostname $hostName --user $UsageAccount 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "GitHub CLI has no token for '$UsageAccount'. Authenticate it with gh auth login."
    }

    $headers = @{
        Authorization = "Bearer $token"
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'Rainmeter-CopilotDayProgress'
    }

    $api = Invoke-RestMethod -Uri 'https://api.github.com/copilot_internal/user' -Headers $headers
    if ($api.login -ine $UsageAccount) {
        throw "GitHub returned data for '$($api.login)' instead of '$UsageAccount'."
    }

    $quota = $api.quota_snapshots.premium_interactions
    if ($null -eq $quota) {
        throw 'GitHub returned no premium interaction quota snapshot.'
    }

    if ($api.token_based_billing -eq $true -or $quota.token_based_billing -eq $true) {
        $creditsUsed = Get-QuotaNumber $quota 'credits_used'
        $value = 100 * $creditsUsed / $CreditLimit
    }
    else {
        if ($quota.unlimited -eq $true) {
            throw 'GitHub reports an unlimited premium interaction quota; no usage percentage is available.'
        }
        $percentRemaining = Get-QuotaNumber $quota 'percent_remaining'
        if ($percentRemaining -gt 100) {
            throw "GitHub returned an out-of-range premium interaction percent_remaining value: $percentRemaining."
        }
        $value = 100 - $percentRemaining
    }

    $formattedValue = [Math]::Round($value, 2).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    [Console]::Out.Write($formattedValue)
}
catch {
    [Console]::Error.WriteLine("Unable to get GitHub Copilot usage: $($_.Exception.Message)")
    exit 1
}
