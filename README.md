# uruncode

Run Claude Code or Codex CLI through the UrunAI gateway with one local API key setup.

`uruncode` stores your UrunAI API key locally, sets the required environment/configuration for the selected CLI, and launches either `claude` or `codex`.

> Requires the target CLI to already be installed:
> - Claude Code: https://docs.claude.com/en/docs/claude-code
> - Codex CLI: https://developers.openai.com/codex

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.sh | bash
```

Installs `uruncode` into `~/.local/bin`. If that directory is not on your `PATH`, the installer prints the line to add.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex
```

Installs `uruncode` into `%LOCALAPPDATA%\Programs\uruncode` and adds it to your user `PATH`. Open a new terminal afterward.

## Use

First run asks for your UrunAI API key and saves it:

```bash
uruncode
```

Then choose:

```text
1) Claude Code
2) Codex CLI
```

You can launch a tool directly:

```bash
uruncode claude .
uruncode codex .
```

For Codex, when the first argument after `codex` is a directory, `uruncode` starts Codex with `--cd <dir>` and the `uruncode` profile.

## API Key

The key is resolved in this order:

1. `uruncode config <KEY>` saves a key inline.
2. The stored config file from a previous run.
3. `URUNAI_API_KEY` from the environment, then saved for next time.
4. Interactive prompt.

Manage the stored key and restore CLI config backups:

```bash
uruncode change-key
uruncode change-key <KEY>
uruncode reset
```

`config`, `set-key`, and `change` are accepted as aliases for `change-key`.

| Platform      | Stored key path                         |
| ------------- | --------------------------------------- |
| macOS/Linux   | `~/.config/uruncode/config`             |
| Windows       | `%APPDATA%\uruncode\config`             |

The key is stored in plaintext on your machine with user-only permissions where supported. Treat it like any other local credential.

## Config Backup and Reset

Before `uruncode` changes Claude Code or Codex CLI config, it saves an original snapshot under the local uruncode config directory. The backup is created once and is not overwritten by later runs.

Backed up files:

- Claude Code: `~/.claude/settings.json`
- Codex CLI: `$CODEX_HOME/config.toml` or `~/.codex/config.toml`
- Codex CLI uruncode profile: `$CODEX_HOME/uruncode.config.toml` or `~/.codex/uruncode.config.toml`

`uruncode reset` restores those backups, removes files that did not exist before uruncode created them, and deletes the stored UrunAI API key.

## What It Configures

Defaults:

```sh
URUNAI_BASE_URL="https://api.urunai.my.id/v1"
URUNAI_CLAUDE_MODEL="aim-cdx-mini"
URUNAI_CODEX_MODEL="aim-cdx-mini"
```

Claude Code launch:

```sh
ANTHROPIC_BASE_URL="$URUNAI_BASE_URL"
ANTHROPIC_AUTH_TOKEN="<your UrunAI API key>"
```

Then runs:

```bash
claude "$@"
```

Codex launch creates or refreshes `$CODEX_HOME/uruncode.config.toml` or `~/.codex/uruncode.config.toml`:

```toml
model = "gpt-5.5"
model_provider = "urunai"

[model_providers.urunai]
name = "UrunAI"
base_url = "https://api.urunai.my.id/v1"
wire_api = "responses"
env_key = "URUNAI_API_KEY"
```

Then runs:

```bash
codex --profile uruncode --cd .
```

## Update

```bash
uruncode update
```

Override the installer URL when needed:

```bash
URUNCODE_INSTALL_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh uruncode update
```

## Uninstall

### macOS / Linux

```bash
rm ~/.local/bin/uruncode
rm -rf ~/.config/uruncode
rm -f ~/.codex/uruncode.config.toml
```

### Windows (PowerShell)

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Programs\uruncode"
Remove-Item -Recurse -Force "$env:APPDATA\uruncode"
Remove-Item -Force "$env:USERPROFILE\.codex\uruncode.config.toml"
```
