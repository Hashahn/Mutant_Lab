---
name: roblox-studio-mcp
description: Guide for interacting with the active Roblox Studio session using the built-in Studio MCP server tools (reading/editing DataModel scripts, controlling playtests, inspecting console logs).
---

# Roblox Studio MCP Integration Guide

Use this skill when interacting with an active Roblox Studio session via the Studio MCP server.

## Prerequisites
1. Roblox Studio must be open with the target place loaded.
2. In Studio: **Assistant** window (top-right) -> **`...` (More)** -> **Manage MCP Servers** -> Ensure **"Enable Studio as MCP server"** is turned ON.
3. The server runs via `StudioMCP.exe` over stdio transport.

## Available MCP Tools & Best Practices

### 1. Script Inspection & Editing
- **`script_read`**: Reads script content by dot-notation path (e.g. `ReplicatedStorage.MutantLab.Shared.Config.GameConfig`). Can read whole files or line ranges.
- **`multi_edit`**: Performs atomic multi-edits on scripts in the DataModel.
  * *Note for Mutant Lab*: Git filesystem (`src/`) is always the source of truth! If edits are made via MCP in Studio, ensure they match or sync with files in `src/` so they are not overwritten by Rojo.
- **`script_search`**: Fuzzy search for scripts in the DataModel hierarchy.
- **`script_grep`**: Pattern and string search across all scripts in the game.

### 2. Playtesting & Runtime Verification
- **`get_studio_mode`**: Checks if Studio is currently in `Edit` mode or `Play` mode.
- **`start_stop_play`**: Toggles between Edit mode and Play mode.
  * Use to start playtests to verify game behavior in real-time.
  * Always stop play mode after tests are completed.
- **`get_console_output`**: Fetches runtime logs, warnings, and errors from the Output window during or after playtests.
  * Critical for checking if initialization succeeded and whether any exceptions occurred in server/client scripts.
- **`run_script_in_play_mode`**: Runs interactive Luau code while play mode is active to inspect variables, server state, or test RemoteFunctions.

### 3. Generative Tools
- `generate_mesh`, `generate_material`, `generate_procedural_model`: Prompt-based asset generation within Studio.
