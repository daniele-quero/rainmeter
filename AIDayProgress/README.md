# AIDayProgress

Rainmeter widget showing month progress and AI usage (GitHub Copilot and Claude):

```
Day 30% - Copilot 13.87% - Claude 14.65%
```

Each usage value turns red independently when it exceeds the month progress.
Otherwise Copilot is light blue and Claude is orange. The percent sign is part
of each meter's `%1%` text, and every segment is a separate meter positioned
relative to the previous one (`X=12R`), so spacing stays correct with values
up to `99.99%`.

## Refresh

- Day progress is recalculated every minute.
- Copilot usage is fetched every 15 minutes.
- Claude usage is fetched every 60 minutes.
- Clicking anywhere on the skin refreshes day progress and both usage values.
  No tooltip is shown.

## Copilot

Configure the account and credit limit in
[AIDayProgress.ini](AIDayProgress.ini):

```ini
[Variables]
UsageAccount=daniele-quero_Alten
UsageCreditLimit=35000
```

[GetCopilotUsage.ps1](GetCopilotUsage.ps1) calculates AI credit usage as
`credits_used / CreditLimit * 100`, rounded to two decimals. The limit is a
user-defined reference, not a budget retrieved from GitHub. Consumption above
the limit is not clamped to 100%. Legacy request-based billing still uses
`100 - percent_remaining`. Authentication uses the selected account's token
without switching the active GitHub CLI account.

```powershell
.\GetCopilotUsage.ps1 -UsageAccount 'daniele-quero_Alten' -CreditLimit 35000
```

## Claude

[GetClaudeUsage.ps1](GetClaudeUsage.ps1) reads the OAuth session saved by the
Claude CLI (`~\.claude\.credentials.json`, or `CLAUDE_CONFIG_DIR`) and calls the
undocumented `https://api.anthropic.com/api/oauth/usage` endpoint, which may
change without notice. It returns `extra_usage.utilization`, rounded to two
decimals (used spend / monthly limit). If the account has no extra usage, it
falls back to `five_hour.utilization`. Tokens are never printed.

If the access token has expired or expires within 30 seconds, the script
renews it using the CLI's OAuth client and refresh token at
`https://platform.claude.com/v1/oauth/token`. This endpoint is also undocumented.
Unlike `claude auth status`, this performs a token refresh without sending a
model request or requiring `claude.exe` on Rainmeter's PATH.

Refreshed tokens are saved only to the existing CLI credentials file, using
atomic replacement and preserving its permissions and other fields. Widget
refreshes are serialized, and a valid session updated by the CLI during a
refresh is reused rather than overwritten. Both HTTP requests time out after
30 seconds. If the refresh token is missing or revoked, run `claude auth login`.
Rate limiting (HTTP 429) is reported with `Retry-After` when provided, without
an immediate retry loop. Persistent refresh rate limits may also require
`claude auth login`.

```powershell
.\GetClaudeUsage.ps1
```

## Errors

Both scripts return only the numeric percentage, without a trailing newline.
On failure they write a diagnostic to stderr and exit with code 1, not a
fabricated zero.

Refresh the skin after changing its configuration.
