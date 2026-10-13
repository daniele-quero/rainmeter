# CopilotDayProgress

Rainmeter widget showing month progress and GitHub Copilot usage.

Configure the account and credit limit in
[CopilotDayProgress.ini](CopilotDayProgress.ini):

```ini
[Variables]
UsageAccount=daniele-quero_Alten
UsageCreditLimit=35000
```

[GetCopilotUsage.ps1](GetCopilotUsage.ps1) calculates AI credit usage as
`credits_used / CreditLimit * 100`, rounded to two decimals. The limit is a
user-defined reference, not a budget retrieved from GitHub. Consumption above
the limit is not clamped to 100%. Legacy request-based billing still uses
`100 - percent_remaining`.

The script returns only the numeric percentage, without a trailing newline,
for the original `MeasureCopilotUsage` measure and `%1% Usage` meter. The
original layout, update interval, click action and red/green comparison with
month progress are unchanged. No additional display meters or Lua scripts
are needed.

To check usage directly:

```powershell
.\GetCopilotUsage.ps1 -UsageAccount 'daniele-quero_Alten' -CreditLimit 35000
```

The limit must be positive and finite. API failures write a diagnostic to
stderr and return exit code 1, not a fabricated zero. Authentication uses the
selected account's token without switching the active GitHub CLI account.

Refresh the skin after changing its configuration.
