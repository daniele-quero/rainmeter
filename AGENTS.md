# Agent guidance for this Rainmeter repository

## Scope

This repository contains Rainmeter skins and small helper scripts. There is no
compiled build or package-manager test suite; validate changes by inspecting
the loaded Rainmeter configuration, running helper scripts directly, and
refreshing the affected skin.

## Rainmeter syntax and loading

- Rainmeter variables use `#VariableName#`, not `[VariableName]`. Square
  brackets identify sections and measures. For example:
  `-UsageAccount "#UsageAccount#"`.
- Use `#CURRENTPATH#` for files next to a skin. A Lua script measure must use
  `Measure=Script` and `ScriptFile=#CURRENTPATH#name.lua`; declaring Lua as a
  generic `Plugin` measure leaves the value at zero.
- A measure that must run at startup needs an explicit startup action such as
  `OnRefreshAction`; an `OnUpdateAction` with a long `UpdateDivider` is not
  sufficient for the first fetch.
- When a skin is outside the default Rainmeter directory, add its parent to
  `SkinPath` in the active `Rainmeter.ini`, then refresh/activate the exact
  config. Verify the persisted `[SkinName]` section and `Active=1` rather than
  assuming the edited file is the one Rainmeter loaded.
- `AlwaysOnTop=2`, `KeepOnScreen=1`, and `Draggable=0` are useful for fixed
  dashboard widgets. Persisted per-skin settings can override expectations,
  so inspect the active config section after changing them.

## Dynamic string meters

- `RunCommand` output is a data measure, not a complete display string.
  PowerShell helpers should emit only the numeric value.
- Emit command output with `Write-Host ... -NoNewline` (or an equivalent
  no-newline write). A trailing CR/LF can interfere with Rainmeter's string
  substitution and make content after `%1%` disappear.
- Rainmeter's measure placeholder is `%1%`; a literal percent sign is `%%`.
- If text after a `RunCommand` placeholder renders unreliably, do not fight
  the parser: split the UI into separate meters (numeric value, percent
  symbol, separator, and label). This also makes spacing and alignment
  deterministic.
- Avoid `ClipString=1` while diagnosing missing labels. Use explicit `X`,
  `W`, and `H` values and a compact fixed `SkinWidth` instead of relying on
  implicit clipping or dynamic sizing.

## GitHub CLI and Copilot usage

- Never use `gh auth switch` from an automated widget. It changes the user's
  global active account and can disrupt unrelated terminal work.
- Retrieve the selected account's token directly:
  `gh auth token --hostname github.com --user <account>`.
  Use it only for the request (for example, as an in-process
  `Authorization: Bearer ...` header) and never commit or persist it.
- Rainmeter may have a reduced PATH. Resolve `gh.exe` explicitly or configure
  a reliable executable path; do not assume an interactive terminal's PATH.
- Validate the API identity (`login`) matches the requested account before
  using the result. For this widget, read
  `quota_snapshots.premium_interactions.percent_remaining` and calculate
  `100 - percent_remaining`.
- Keep API failures explicit; do not turn missing authentication or malformed
  data into a fake zero. Test both the helper's exit code/value and the active
  `gh` account after execution.

## Verification checklist

1. Run the PowerShell helper directly and inspect its exact output, type,
   length, and exit code.
2. Confirm the Rainmeter INI uses `#...#` variables, `Measure=Script` for Lua,
   correct `%1%`/`%%` formatting, and explicit meter geometry.
3. Refresh or activate the exact skin and check Rainmeter's persisted config.
4. Confirm the widget's account-specific API request does not change the
   user's active GitHub account.
