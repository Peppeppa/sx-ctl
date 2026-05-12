# sx-ctl

`sx-ctl` is a lightweight, modular command-line framework for running shell scripts from a GitHub repository without cloning or manually pulling the public repository.

The project is shell-based and designed to work without Python, Node.js, `jq`, `fzf` or `git` as mandatory runtime dependencies.

## Goals

- Run public shell scripts from a GitHub repository.
- Allow direct usage through `curl`.
- Allow local installation of a small `sx-ctl` wrapper.
- Load only the files that are needed.
- Support normal `sh` and `bash` scripts.
- Use a simple manifest instead of scanning the repository.
- Support an optional local private overlay.
- Keep public framework logic and private user scripts separated.
- Keep the architecture simple, inspectable and maintainable.

## Repository Structure

```text
sx-ctl/
├── README.md
├── install.sh
├── uninstall.sh
├── sx-ctl.sh
├── sx-ctl-basic.sh
├── manifest.txt
├── lib/
│   ├── core.sh
│   └── private.sh
├── scripts/
│   ├── admin/
│   │   ├── doctor.sh
│   │   ├── private-clone.sh
│   │   ├── private-init.sh
│   │   ├── private-pull.sh
│   │   ├── private-remove.sh
│   │   ├── private-status.sh
│   │   └── validate-manifest.sh
│   ├── misc/
│   │   └── hello.sh
│   ├── system/
│   │   └── info.sh
│   └── test/
│       └── test.sh
├── templates/
│   └── script-template.sh
└── docs/
    ├── requirements.md
    ├── architecture.md
    └── roadmap.md
```

## Installation

Install the `sx-ctl` wrapper to `~/.local/bin/sx-ctl`:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/install.sh | sh
```

After installation:

```sh
sx-ctl -h
sx-ctl -ls
sx-ctl -la
```

If `sx-ctl` is not found after installation, make sure `~/.local/bin` is in your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Add that line to your shell configuration file, for example:

```text
~/.profile
~/.shrc
~/.bashrc
~/.zshrc
```

## Uninstall

Remove the installed wrapper:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/uninstall.sh | sh
```

Or manually:

```sh
rm -f ~/.local/bin/sx-ctl
```

This does not remove private overlays or user configuration under:

```text
~/.config/sx-ctl/
```

## Direct Usage Without Installation

You can run the public entrypoint directly:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh
```

Run a specific tool:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh -s -- system.info
```

Pass arguments to a tool:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh -s -- misc.hello Peppeppa
```

## Usage

Show help:

```sh
sx-ctl -h
```

Show version:

```sh
sx-ctl -v
```

Start the interactive category menu:

```sh
sx-ctl
```

Show compact tool tree:

```sh
sx-ctl -ls
```

Compatibility aliases:

```sh
sx-ctl list
sx-ctl ls
```

Show detailed tool tree:

```sh
sx-ctl -la
```

Compatibility aliases:

```sh
sx-ctl listall
sx-ctl la
```

Run a tool directly:

```sh
sx-ctl system.info
```

Run a tool with arguments:

```sh
sx-ctl misc.hello Peppeppa
```

Explicit run syntax:

```sh
sx-ctl -r misc.hello Peppeppa
```

Compatibility alias:

```sh
sx-ctl run misc.hello Peppeppa
```

## Example Output

Compact list:

```text
sx-ctl tools
└── public
    ├── admin
    │   ├── admin.doctor
    │   ├── admin.private-clone
    │   ├── admin.private-init
    │   ├── admin.private-pull
    │   ├── admin.private-remove
    │   ├── admin.private-status
    │   └── admin.validate-manifest
    ├── misc
    │   └── misc.hello
    ├── system
    │   └── system.info
    └── test
        └── test.test
```

Detailed list:

```text
sx-ctl tools
└── public
    ├── misc
    │   └── misc.hello - Hello Demo [low]
    │       Ein simples Bash-Testscript
    └── system
        └── system.info - Systeminformationen [low]
            Zeigt grundlegende Systeminformationen an
```

## Public Tools

Current public tools are registered in:

```text
manifest.txt
```

Examples:

```sh
sx-ctl system.info
sx-ctl misc.hello
sx-ctl misc.hello Peppeppa
```

Admin/helper tools:

```sh
sx-ctl admin.doctor
sx-ctl admin.validate-manifest
sx-ctl admin.private-status
sx-ctl admin.private-init
sx-ctl admin.private-clone <git-url>
sx-ctl admin.private-pull
sx-ctl admin.private-remove
```

## Private Overlay

`sx-ctl` can optionally load private tools from a local private overlay.

Default path:

```text
~/.config/sx-ctl/overlays/private/
```

Example structure:

```text
~/.config/sx-ctl/overlays/private/
├── env
├── manifest.txt
├── scripts/
│   ├── personal/
│   │   └── hello.sh
│   └── admin/
│       └── status.sh
└── templates/
```

If this file exists:

```text
~/.config/sx-ctl/overlays/private/manifest.txt
```

private tools are loaded in addition to public tools.

## Create a Local Private Overlay

Create a local private overlay without Git:

```sh
sx-ctl admin.private-init
```

Check status:

```sh
sx-ctl admin.private-status
```

List all tools:

```sh
sx-ctl -la
```

Run the default private example script:

```sh
sx-ctl private.personal.hello
```

## Clone an Existing Private Repo

If you already have a private Git repository, clone it as your private overlay:

```sh
sx-ctl admin.private-clone git@github.com:USER/sx-ctl-private.git
```

Example:

```sh
sx-ctl admin.private-clone git@github.com:Peppeppa/sx-ctl-private.git
```

Update the private overlay:

```sh
sx-ctl admin.private-pull
```

Remove the local private overlay:

```sh
sx-ctl admin.private-remove
```

This removes only the local overlay directory. It does not delete the remote GitHub repository.

## Private Tool IDs

Tool IDs must be globally unique.

Public tools use normal IDs:

```text
admin.doctor
system.info
misc.hello
```

Private tools must start with:

```text
private.
```

Recommended private ID format:

```text
private.<category>.<name>
```

Examples:

```text
private.personal.hello
private.personal.weather
private.admin.status
private.work.deploy
```

This avoids conflicts between public and private tools.

Invalid private IDs:

```text
admin.status
personal.weather
```

Valid private IDs:

```text
private.admin.status
private.personal.weather
```

## Manifest Format

The manifest is pipe-separated:

```text
id|source|category|label|path|description|shell|deps|risk
```

Example public entry:

```text
system.info|public|system|Systeminformationen|scripts/system/info.sh|Zeigt grundlegende Systeminformationen an|sh|uname,df|low
```

Example private entry:

```text
private.personal.hello|private|personal|Private Hello|scripts/personal/hello.sh|Ein privates Beispielscript|sh|sh|low
```

Fields:

| Field | Description |
|---|---|
| `id` | Stable tool ID |
| `source` | `public` or `private` |
| `category` | Tool category |
| `label` | Human-readable display name |
| `path` | Relative script path |
| `description` | Short description |
| `shell` | `sh` or `bash` |
| `deps` | Documented dependencies |
| `risk` | `low`, `medium` or `high` |

Rules:

- Manifest fields must not contain the pipe character `|`.
- Every entry must have exactly 9 fields.
- `source` must be `public` or `private`.
- `shell` must be `sh` or `bash`.
- `risk` must be `low`, `medium` or `high`.
- Script paths must be relative.
- Script paths must not contain `..`.
- Private IDs must start with `private.`.
- Public IDs must not start with `private.`.
- Tool IDs must be globally unique.

## Validate Manifests

Run:

```sh
sx-ctl admin.validate-manifest
```

This checks public and private manifests for:

```text
- correct header
- correct field count
- empty required fields
- valid source
- valid shell
- valid risk level
- safe relative paths
- public/private namespace rules
- duplicate tool IDs
- existing local script files where possible
```

## Doctor Check

Run:

```sh
sx-ctl admin.doctor
```

This checks the local sx-ctl environment:

```text
- required and optional commands
- curl/wget availability
- local repo context
- installed wrapper
- PATH setup
- private overlay status
- manifest validation
```

## Creating New Scripts

Use the simple template:

```sh
cp templates/script-template.sh scripts/category/name.sh
chmod +x scripts/category/name.sh
```

Edit the metadata header and write your code inside:

```sh
main() {
  # Write your script code here.
}
```

Then add a manifest entry:

```text
category.name|public|category|Human readable name|scripts/category/name.sh|Short description|sh|sh|low
```

For private scripts, add the entry to the private manifest:

```text
private.category.name|private|category|Human readable name|scripts/category/name.sh|Short description|sh|sh|low
```

## Script Template

Minimal structure:

```sh
#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl script
# ID:          category.name
# Name:        Human readable name
# Description: Short description of what this script does
# Dependencies: sh
# Risk:        low
# ============================================================

main() {
  echo "Hello from category.name"
}

main "$@"
```

## Shell Compatibility

`sx-ctl` supports:

```text
sh
bash
```

Use POSIX `sh` where possible.

Use `bash` only when Bash-specific features are needed. If a script requires Bash, the manifest must say:

```text
bash
```

Example:

```text
misc.hello|public|misc|Hello Demo|scripts/misc/hello.sh|Ein simples Bash-Testscript|bash|bash|low
```

## Security Notes

`sx-ctl` executes shell scripts. Only run scripts from repositories you trust.

Important design choices:

- No automatic dependency installation.
- No automatic loading of private `env` files by the core.
- Private scripts may load their own private `env` file explicitly.
- Private scripts are executed locally.
- Public scripts are fetched from the configured raw GitHub source.
- Script paths are restricted to relative paths.
- Script paths must not contain `..`.
- Private and public tool IDs are separated by namespace rules.

Private `env` example:

```sh
SX_HOME_CITY="Berlin"
SX_COUNTRY="Germany"
SX_WEATHER_UNITS="metric"
```

Private scripts can load it explicitly:

```sh
ENV_FILE="${SX_PRIVATE_ENV:-$HOME/.config/sx-ctl/overlays/private/env}"

if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
fi
```

## Environment Variables

| Variable | Description |
|---|---|
| `SX_RAW_BASE` | Override public raw GitHub base URL |
| `SX_LOCAL_ROOT` | Use a local sx-ctl repo root for development/testing |
| `SX_PRIVATE_ROOT` | Override private overlay path |
| `SX_PRIVATE_ENV` | Override private env file path |
| `SX_INSTALL_DIR` | Override install directory |
| `SX_INSTALL_BIN` | Override installed binary path |

Example local development:

```sh
SX_LOCAL_ROOT="$PWD" ./sx-ctl.sh -la
```

Example temporary private overlay:

```sh
SX_PRIVATE_ROOT="$PWD/.tmp-private-overlay" ./sx-ctl.sh admin.private-status
```

## Development

Run syntax checks:

```sh
sh -n sx-ctl.sh
sh -n sx-ctl-basic.sh
sh -n install.sh
sh -n uninstall.sh
sh -n lib/core.sh
```

Run manifest validation:

```sh
./sx-ctl.sh admin.validate-manifest
```

Run doctor:

```sh
./sx-ctl.sh admin.doctor
```

Run example tools:

```sh
./sx-ctl.sh system.info
./sx-ctl.sh misc.hello
./sx-ctl.sh misc.hello Peppeppa
```

## Roadmap

Implemented or in progress:

```text
- Documentation and repository structure
- Public manifest
- Public example scripts
- Core implementation
- Basic frontend
- Main entrypoint
- Installer and uninstaller
- Optional private overlay
- Public admin helper scripts
- Manifest validation
- Doctor check
- Script template
```

Planned:

```text
- fzf frontend
- improved README/docs
- smoke tests
- ShellCheck integration
- GitHub Actions
- script generator
- improved help file structure
- optional caching/offline mode
- checksums or signature strategy
- aliases
- versioned releases
```

## License

Add a license before publishing this project for wider use.
