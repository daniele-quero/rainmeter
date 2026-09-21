param(
    [string]$UsageAccount = 'daniele-quero_Alten'
)

$ErrorActionPreference = 'Stop'
$hostName = 'github.com'
$ghExecutable = (Get-Command gh -ErrorAction Stop).Source
$usagePercent = $null
$requestError = $null

try {
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
    $percentRemaining = [double]$api.quota_snapshots.premium_interactions.percent_remaining
    if ($percentRemaining -lt 0 -or $percentRemaining -gt 100) {
        throw "GitHub returned an out-of-range premium interaction percent_remaining value: $percentRemaining."
    }

    if ($api.login -ine $UsageAccount) {
        throw "GitHub returned data for '$($api.login)' instead of '$UsageAccount'."
    }

    $usagePercent = [Math]::Round(100 - $percentRemaining, 2)
}
catch {
    $requestError = $_.Exception.Message
}

if ($requestError) {
    [Console]::Error.WriteLine("Unable to get GitHub Copilot usage: $requestError")
    exit 1
}


Write-Host $usagePercent.ToString([System.Globalization.CultureInfo]::InvariantCulture) -NoNewline
