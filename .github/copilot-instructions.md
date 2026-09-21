# Copilot instructions for this repository

## Project overview

This repository is a Rainmeter skin pack, not a traditional application with a compiled build or package manager. The main project content is organized as skin folders and helper scripts.



## High-level architecture

The repository is built around Rainmeter's configuration-driven model:

- Skin configuration is stored in `.ini` files.
- Each skin typically defines sections such as `[Rainmeter]`, `[Metadata]`, `[Variables]`, `[Measure...]`, and `[Meter...]`.
- Styles are centralized via `MeterStyle` sections so that repeated UI options are shared instead of duplicated.
- Asset references use Rainmeter variables like `#@#` and `#CURRENTPATH#` to point to resources and local files.
- The Copilot widget uses a PowerShell command as a measurement source and updates a meter from its result; this pattern is important when editing scripting-driven UI.

Detailed, reusable Rainmeter and GitHub CLI pitfalls are documented in the
repository-root [AGENTS.md](../AGENTS.md). Read it before changing a
script-driven skin, especially its guidance on variable syntax, no-newline
command output, startup actions, and account-safe `gh` authentication.

## Key conventions

- Keep the skin structure consistent with the existing Rainmeter layout: `@Resources` for shared assets, skin folders for individual UI modules, and per-skin `*.ini` files for config.
- Prefer reusing `MeterStyle` and `Measure` definitions instead of copying repeated options across meters.
- When working in `illustro`, use Rainmeter-native paths and variable syntax rather than Windows filesystem paths.
- Preserve the existing metadata conventions (`[Metadata]`, `Name`, `Author`, `Information`, `Version`) when editing skins.
- For the Copilot usage widget, keep the script and Rainmeter measure names aligned with the existing `MeasureCopilotUsage` / `MeasureDayProgress` patterns.
- Avoid adding build tooling or package metadata unless the repository already includes one; this project is intentionally lightweight and editor-driven.
