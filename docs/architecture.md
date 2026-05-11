# Architecture

## Overview

`sx-ctl` is a lightweight command-line launcher for running shell scripts from a GitHub repository.

The main idea is that users can run tools without cloning the public repository and without manually pulling updates. The public launcher downloads only the files that are required for the current command.

`sx-ctl` supports two main usage modes:

1. Direct execution via `curl`
2. Installed usage through a local `sx-ctl` command

The public repository contains the core framework, public scripts, documentation, templates and installer logic.

Additionally, `sx-ctl` supports an optional local private overlay. This overlay can contain private scripts, private configuration and private admin tools. If the private overlay exists, its tools are shown together with the public tools. If it does not exist, `sx-ctl` works normally with public tools only.

The project is intentionally designed to stay small, portable, modular and easy to extend.

---

## Goals

- Provide a simple command-line interface for running shell scripts.
- Allow public scripts to be updated centrally through the public GitHub repository.
- Avoid requiring users to clone or pull the public repository.
- Download only files required for the selected action.
- Support minimal Linux systems through a basic frontend.
- Support an enhanced terminal UI when optional tools like `fzf` are available.
- Allow quick addition of normal `sh` or `bash` scripts.
- Support an optional local private overlay for personal scripts and configuration.
- Keep public-only usage working even when no private overlay exists.
- Keep the architecture understandable for a small software engineering project.

---

## Non-Goals

The first version of `sx-ctl` does not aim to provide:

- automatic dependency installation
- a shared runtime library for all scripts
- local caching
- offline execution
- execution of scripts from arbitrary external repositories
- graphical user interfaces
- complex plugin management
- GitHub API token handling
- automatic secret synchronization
- package management
- rollback functionality
- checksum verification
- full multi-overlay management

These features may be considered later, but they are intentionally out of scope for version 1.

---

## Repository Structure

Public repository:

```text
sx-ctl/
├── README.md
├── install.sh
├── sx-ctl.sh
├── sx-ctl-basic.sh
├── sx-ctl-fzf.sh
├── manifest.txt
├── lib/
│   └── core.sh
├── scripts/
│   ├── system/
│   │   └── info.sh
│   ├── network/
│   │   └── ports.sh
│   ├── docker/
│   │   └── cleanup.sh
│   └── misc/
│       └── hello.sh
├── templates/
│   └── script-template.sh
└── docs/
    ├── requirements.md
    ├── architecture.md
    └── roadmap.md
```

Optional local private overlay:

```text
~/.config/sx-ctl/overlays/private/
├── env
├── manifest.txt
├── scripts/
│   ├── personal/
│   │   └── weather.sh
│   └── admin/
│       ├── add-script.sh
│       ├── validate-manifest.sh
│       ├── update-private.sh
│       └── status.sh
└── templates/
    └── private-script-template.sh
```

The private overlay is not part of the public repository. It can be managed through a separate private Git repository, for example:

```sh
git clone git@github.com:Peppeppa/sx-ctl-private.git ~/.config/sx-ctl/overlays/private
```

---

## Components

### `sx-ctl.sh`

`sx-ctl.sh` is the main public entrypoint of the project.

Responsibilities:

- handle global command-line options
- decide which frontend should be used
- route to `sx-ctl-basic.sh` or `sx-ctl-fzf.sh`
- forward arguments to the selected frontend
- support direct execution via `curl`

Example usage:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh
```

With arguments:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh -s -- system.info
```

The entrypoint should remain small. It should only choose and load the appropriate frontend.

---

### `sx-ctl-basic.sh`

`sx-ctl-basic.sh` is the minimal frontend.

It is the compatibility baseline of the project.

Responsibilities:

- run without optional UI dependencies
- display available tools
- support direct execution by tool ID
- provide a simple interactive prompt
- call the shared core logic to execute tools

The basic frontend should only rely on commonly available shell tools such as:

- `sh`
- `awk`
- `printf`
- `read`
- `curl` or `wget`
- `mktemp`

It should not require:

- `fzf`
- `jq`
- `git`
- Python
- Node.js

---

### `sx-ctl-fzf.sh`

`sx-ctl-fzf.sh` is the enhanced frontend.

Responsibilities:

- provide a searchable terminal UI using `fzf`
- display tool IDs, sources, categories, labels and risk levels
- improve usability for larger tool collections
- call the shared core logic to execute tools

If `fzf` is not available, the main entrypoint should normally fall back to the basic frontend.

If the user explicitly requests fzf mode with `--fzf`, the tool should print a clear error message when `fzf` is missing.

The fzf frontend is optional. It must not be required for core functionality.

---

### `lib/core.sh`

`lib/core.sh` contains the shared core logic.

Responsibilities:

- define the public raw GitHub base URL
- fetch remote files using `curl` or `wget`
- load the public manifest
- discover the optional private overlay
- load the private manifest if it exists
- combine public and private manifest entries
- list available tools
- resolve a tool ID to a manifest entry
- determine script source, path and shell
- execute public scripts from GitHub raw URLs
- execute private scripts from the local private overlay
- clean up temporary files
- forward arguments to the selected script
- return the exit status of the executed script
- print clear error messages

The core should not contain UI-specific logic.

It should not decide how the user selects a tool. It should only provide functions that frontends can call.

The core should not automatically load private environment files. Private scripts may load private configuration themselves when needed.

---

### `manifest.txt`

`manifest.txt` is the registry of available tools.

It is the single source of truth for:

- available tool IDs
- script source
- categories
- display names
- script paths
- descriptions
- required shell
- optional dependency information
- risk level

Planned format:

```text
id|source|category|label|path|description|shell|deps|risk
```

Public manifest example:

```text
system.info|public|system|Systeminformationen|scripts/system/info.sh|Zeigt Systeminformationen|sh|uname,df|low
network.ports|public|network|Offene Ports|scripts/network/ports.sh|Zeigt offene Ports|sh|ss,netstat|low
docker.cleanup|public|docker|Docker Cleanup|scripts/docker/cleanup.sh|Entfernt ungenutzte Docker-Ressourcen|bash|docker|medium
misc.hello|public|misc|Hello Demo|scripts/misc/hello.sh|Ein simples Testscript|bash|bash|low
```

Private manifest example:

```text
private.weather|private|personal|Privates Wetter|scripts/personal/weather.sh|Nutzt privaten Wohnort aus env|sh|curl|low
admin.add-script|private|admin|Script hinzufügen|scripts/admin/add-script.sh|Fügt ein neues privates Script dem Manifest hinzu|bash|bash,git|medium
admin.validate-manifest|private|admin|Manifest prüfen|scripts/admin/validate-manifest.sh|Prüft private Manifest-Einträge|sh|awk|low
admin.update-private|private|admin|Private Tools aktualisieren|scripts/admin/update-private.sh|Führt git pull im privaten Overlay aus|sh|git|low
```

Field meaning:

| Field | Description |
|---|---|
| `id` | Stable command identifier, for example `system.info` or `private.weather` |
| `source` | Script source, for example `public` or `private` |
| `category` | Logical group, for example `system`, `network`, `docker`, `personal`, `admin` |
| `label` | Human-readable name shown in menus |
| `path` | Path to the script inside the public repository or private overlay |
| `description` | Short explanation of what the script does |
| `shell` | Shell used to execute the script, usually `sh` or `bash` |
| `deps` | Informational list of dependencies |
| `risk` | Risk level such as `low`, `medium` or `high` |

The manifest is intentionally kept as a pipe-separated text file instead of JSON, because it can be parsed with standard shell tools.

Manifest rules:

- Field values should not contain the pipe character `|`.
- Public tools should use `source=public`.
- Private tools should use `source=private`.
- Tool IDs should be unique across public and private manifests.
- Script paths must be relative paths.
- Private script paths must not contain `..`.
- Private script paths must not be absolute paths.

---

### `scripts/`

The `scripts/` directory contains the actual public tools.

Scripts may be organized by category:

```text
scripts/
├── system/
├── network/
├── docker/
└── misc/
```

Scripts do not need to follow a special framework.

A script only needs to:

1. exist in the repository or private overlay
2. be listed in a manifest
3. be executable with the shell defined in the manifest

Both POSIX `sh` scripts and `bash` scripts are supported.

Example POSIX shell script:

```sh
#!/usr/bin/env sh
set -eu

echo "System information"
uname -a
```

Example Bash script:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Hello from Bash"
```

---

### `templates/script-template.sh`

`templates/script-template.sh` is an optional template for new scripts.

The template is not required, but recommended for scripts that:

- have dependencies
- modify system state
- delete data
- require confirmation prompts
- should be well documented

The template may include:

- metadata comments
- a `main` function
- simple dependency checks
- confirmation prompts
- consistent error handling

Example structure:

```sh
#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl script
# ID:          category.name
# Name:        Human readable name
# Description: Short explanation
# Dependencies: sh, awk, curl
# Risk:        low|medium|high
# ============================================================

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command missing: $1" >&2
    exit 1
  }
}

confirm() {
  prompt="$1"
  printf "%s [y/N] " "$prompt"
  read ans

  case "$ans" in
    y|Y|yes|YES|j|J|ja|JA)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

main() {
  echo "Hello from sx-ctl script template"
}

main "$@"
```

---

### `install.sh`

`install.sh` installs a local wrapper command named `sx-ctl`.

The installer should not download the whole repository.

Instead, it should create a small wrapper script in:

```text
~/.local/bin/sx-ctl
```

The wrapper should fetch the latest remote entrypoint and forward all arguments.

Conceptual wrapper:

```sh
#!/usr/bin/env sh
set -eu

URL="https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" | sh -s -- "$@"
elif command -v wget >/dev/null 2>&1; then
  wget -qO- "$URL" | sh -s -- "$@"
else
  echo "Error: curl or wget is required." >&2
  exit 1
fi
```

After installation, users can run:

```sh
sx-ctl
sx-ctl list
sx-ctl system.info
sx-ctl --basic
sx-ctl --fzf
```

---

## Private Overlay

The private overlay is an optional local extension mechanism.

Default path:

```text
~/.config/sx-ctl/overlays/private
```

The private overlay can contain:

- private scripts
- a private manifest
- private configuration
- private admin tools
- private script templates

Example structure:

```text
~/.config/sx-ctl/overlays/private/
├── env
├── manifest.txt
├── scripts/
│   ├── personal/
│   │   └── weather.sh
│   └── admin/
│       ├── add-script.sh
│       ├── validate-manifest.sh
│       ├── update-private.sh
│       └── status.sh
└── templates/
    └── private-script-template.sh
```

If the private manifest exists, its tools are included in the global tool list.

If the private manifest does not exist, the private overlay is ignored silently.

Private scripts are executed locally. They are not downloaded from the public repository.

The private overlay can be managed by a separate private Git repository:

```sh
git clone git@github.com:Peppeppa/sx-ctl-private.git ~/.config/sx-ctl/overlays/private
```

Git is not required for public usage. Git is only needed for setting up or updating the private overlay.

---

## Private Configuration

Private configuration should not be stored in the public repository.

The private overlay may contain an environment file:

```text
~/.config/sx-ctl/overlays/private/env
```

Example:

```sh
SX_HOME_CITY="Berlin"
SX_COUNTRY="Germany"
SX_WEATHER_UNITS="metric"
```

The core does not automatically load this file.

Scripts that need private configuration can load it explicitly:

```sh
ENV_FILE="${SX_PRIVATE_ENV:-$HOME/.config/sx-ctl/overlays/private/env}"

if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
fi
```

This keeps the core simple and avoids exposing private values to scripts that do not need them.

Personal configuration such as a city name may be stored in the private overlay. Real secrets such as API tokens or passwords should be handled carefully and may require a stronger approach in future versions, such as local-only storage or encryption.

---

## Private Admin Tools

Private admin tools are planned to live in the private overlay.

Examples:

```text
admin.add-script
admin.validate-manifest
admin.update-private
admin.status
```

These tools are not required for the public core to work.

### `admin.add-script`

Purpose:

- interactively create a new private script
- create the target file from a private template
- add an entry to the private manifest
- show Git status and next steps

Possible workflow:

```text
Tool ID: private.weather
Category: personal
Label: Privates Wetter
Path: scripts/personal/weather.sh
Description: Uses private city from env
Shell: sh
Dependencies: curl
Risk: low
```

Expected result:

```text
Created script:
  scripts/personal/weather.sh

Updated manifest:
  manifest.txt

Next steps:
  git add manifest.txt scripts/personal/weather.sh
  git commit -m "Add private.weather"
  git push
```

### `admin.validate-manifest`

Purpose:

- validate field count
- detect duplicate IDs
- validate source values
- validate shell values
- check whether referenced scripts exist
- detect unsafe paths

### `admin.update-private`

Purpose:

- run `git pull --ff-only` inside the private overlay
- print update status
- fail clearly if the private overlay is not a Git repository

### `admin.status`

Purpose:

- show private overlay path
- show whether private manifest exists
- show number of private tools
- show Git status if available
- show whether private env exists

---

## Execution Flow

### Direct Execution via `curl`

```text
User
  |
  | curl .../sx-ctl.sh | sh
  v
sx-ctl.sh
  |
  | chooses frontend
  v
sx-ctl-basic.sh or sx-ctl-fzf.sh
  |
  | loads lib/core.sh
  v
core.sh
  |
  | loads public manifest
  | loads private manifest if available
  | lists tools or resolves selected tool ID
  | downloads public script or locates private script
  v
tool script
```

---

### Installed Execution

```text
User
  |
  | sx-ctl system.info
  v
local wrapper at ~/.local/bin/sx-ctl
  |
  | downloads latest sx-ctl.sh
  v
sx-ctl.sh
  |
  | chooses frontend
  v
sx-ctl-basic.sh or sx-ctl-fzf.sh
  |
  | loads lib/core.sh
  v
core.sh
  |
  | loads public manifest
  | loads private manifest if available
  | resolves selected tool ID
  | executes selected script
  v
tool script
```

---

### Public Tool Execution

```text
User runs:
  sx-ctl system.info

core.sh:
  loads public manifest
  resolves system.info
  detects source=public
  downloads scripts/system/info.sh from GitHub raw
  executes it with configured shell
```

---

### Private Tool Execution

```text
User runs:
  sx-ctl private.weather

core.sh:
  loads public manifest
  loads private manifest if available
  resolves private.weather
  detects source=private
  resolves local path inside private overlay
  validates path
  executes local private script with configured shell
```

---

### Tool Selection Flow

```text
User starts sx-ctl
  |
  v
Frontend displays available tools
  |
  v
User selects a tool
  |
  v
Frontend passes tool ID to core
  |
  v
Core resolves manifest entry
  |
  v
Core checks source
  |
  ├── source=public  -> download public script from GitHub raw
  |
  └── source=private -> execute local private script
```

---

## Command Interface

Planned command interface:

```sh
sx-ctl
```

Starts interactive mode.

```sh
sx-ctl list
```

Lists available tools.

```sh
sx-ctl system.info
```

Runs the tool with ID `system.info`.

```sh
sx-ctl run system.info
```

Alternative explicit run syntax.

```sh
sx-ctl private.weather
```

Runs a private tool if the private overlay is available.

```sh
sx-ctl --basic
```

Forces the basic frontend.

```sh
sx-ctl --fzf
```

Forces the fzf frontend.

```sh
sx-ctl help
```

Shows help information.

```sh
sx-ctl version
```

Shows version information.

Future possible commands:

```sh
sx-ctl overlay status
sx-ctl overlay update
sx-ctl doctor
```

These are not required for version 1.

---

## Data Flow

`sx-ctl` should only download files that are needed for the current operation.

For an interactive public-only call:

```text
sx-ctl
```

Expected public downloads:

```text
sx-ctl.sh
sx-ctl-basic.sh or sx-ctl-fzf.sh
lib/core.sh
manifest.txt
selected public script
```

If the private overlay exists, the private manifest may be read locally:

```text
~/.config/sx-ctl/overlays/private/manifest.txt
```

For direct public tool execution:

```text
sx-ctl system.info
```

Expected downloads:

```text
sx-ctl.sh
selected frontend
lib/core.sh
manifest.txt
scripts/system/info.sh
```

For private tool execution:

```text
sx-ctl private.weather
```

Expected public downloads:

```text
sx-ctl.sh
selected frontend
lib/core.sh
manifest.txt
```

Expected local reads:

```text
~/.config/sx-ctl/overlays/private/manifest.txt
~/.config/sx-ctl/overlays/private/scripts/personal/weather.sh
```

The following should not be downloaded:

```text
.git/
repository history
other branches
unselected scripts
the full repository archive
private repository contents through public sx-ctl
```

---

## Design Decisions

### 1. Use Shell Scripts

`sx-ctl` is implemented with shell scripts.

Reason:

- shell is available on nearly all Linux systems
- no large runtime is required
- scripts can be inspected easily
- the tool itself is meant to manage shell scripts

Consequence:

- the implementation must avoid non-portable shell features in compatibility-critical files
- Bash-specific features should only be used in scripts marked as `bash`

---

### 2. Support Both `sh` and `bash`

`sx-ctl` supports scripts written for POSIX `sh` and Bash.

Reason:

- POSIX `sh` is better for portability
- Bash is useful for quicker scripts and more comfortable syntax

Consequence:

- the manifest contains a `shell` field
- the core must check whether `bash` is available before running Bash scripts
- scripts should clearly define which shell they require

---

### 3. Use a Manifest Instead of Scanning the Repository

`sx-ctl` uses `manifest.txt` as a registry.

Reason:

- raw GitHub URLs do not provide easy directory listing
- scanning a remote repository would require GitHub API usage or cloning
- the manifest makes available tools explicit
- metadata such as source, category, description and risk can be stored centrally

Consequence:

- adding a new script requires updating a manifest
- manifests must be kept consistent with the files in `scripts/`

---

### 4. Use a Pipe-Separated Manifest Instead of JSON

The manifest uses a pipe-separated text format.

Reason:

- it can be parsed with `awk`, `cut` and standard shell tools
- JSON would require `jq` or more complex parsing
- the project should work on minimal systems

Consequence:

- field values should not contain the pipe character `|`
- the format is less expressive than JSON
- validation must be simple

---

### 5. Add a `source` Field to the Manifest

The manifest includes a `source` field.

Reason:

- public and private tools need to be handled differently
- public tools are downloaded from GitHub raw URLs
- private tools are executed from a local overlay
- future sources such as `homelab` or `work` may become possible

Consequence:

- the core must route execution based on the source field
- unsupported source values must produce clear errors

---

### 6. Keep Frontend and Core Separate

Frontend scripts handle user interaction.

The core handles fetching, manifest parsing and script execution.

Reason:

- avoids duplicating core logic
- makes it easier to add new frontends later
- keeps the basic and fzf UI focused on presentation

Consequence:

- frontends need to load `lib/core.sh`
- core functions should be stable and UI-independent

---

### 7. Provide Basic Mode as Compatibility Baseline

`sx-ctl-basic.sh` is the baseline frontend.

Reason:

- the tool should work on minimal Linux systems
- optional UI tools may not be installed
- basic mode is easier to test and debug

Consequence:

- all core functionality must be usable without `fzf`
- fzf mode is a convenience feature, not a requirement

---

### 8. Support Optional Private Overlay

`sx-ctl` supports an optional private overlay.

Reason:

- users may want personal scripts and configuration
- private scripts should not live in the public repository
- private values such as a city name should not be committed publicly
- SSH-based private Git repositories can be used to sync the overlay between machines

Consequence:

- public-only usage must work without the overlay
- the core must check whether the private manifest exists
- private scripts are executed locally
- private paths must be validated

---

### 9. Do Not Automatically Load Private Env Files in the Core

The core does not automatically load private env files.

Reason:

- not every script needs private configuration
- loading env globally may expose private values unnecessarily
- scripts should explicitly choose which config they need

Consequence:

- scripts that need private configuration must load it themselves
- this keeps the core simpler and safer

---

### 10. Do Not Add a Shared Runtime Library in Version 1

Tool scripts do not import a shared `sx-ctl` runtime library.

Reason:

- a runtime library would increase complexity
- quick scripts should be easy to add
- dependency checks can be done inside individual scripts when needed

Consequence:

- some helper code may be duplicated
- important scripts should use `templates/script-template.sh`
- future versions may introduce shared helpers if duplication becomes a problem

---

### 11. Do Not Automatically Install Dependencies in Version 1

`sx-ctl` does not automatically install missing dependencies.

Reason:

- package managers differ between distributions
- automatic installation may require `sudo`
- implicit package installation is risky
- version 1 should stay simple and predictable

Consequence:

- scripts should print clear error messages when dependencies are missing
- the manifest can document dependencies
- users install missing packages manually

---

### 12. Download Only Required Public Files

`sx-ctl` downloads only the public files needed for the current command.

Reason:

- avoids cloning the public repository
- keeps execution fast
- ensures users always run the latest remote public version

Consequence:

- each public command may require network access
- no offline mode is available in version 1
- GitHub availability affects public execution

---

### 13. Execute Scripts as Separate Processes

Selected tools are executed as separate shell processes.

Reason:

- prevents tool scripts from modifying the launcher process
- avoids variable and function collisions
- makes behavior easier to reason about

Consequence:

- scripts cannot directly modify core state
- arguments must be passed explicitly

---

## Error Handling Strategy

`sx-ctl` should provide clear error messages for common problems.

Examples:

- missing `curl` and `wget`
- missing `fzf` when `--fzf` is explicitly requested
- unknown tool ID
- duplicate tool ID
- missing public manifest
- missing private manifest when a private tool is requested
- missing script path in manifest
- missing public script
- missing private script
- unsafe private script path
- unsupported source value
- unsupported shell value
- missing `bash` for Bash-based scripts
- network errors while fetching files
- failed script execution

Error messages should explain what happened and, when possible, how the user can fix it.

Example:

```text
Error: unknown tool ID: docker.clean

Available tools:
  system.info
  docker.cleanup
  private.weather
```

---

## Security Considerations

`sx-ctl` downloads and executes shell scripts.

Public tools are downloaded from the public GitHub repository.

Private tools are executed from the local private overlay if available.

This means users must trust:

- the public `sx-ctl` repository
- their local private overlay contents

The README should clearly document this behavior.

Important security rules for the project:

- Do not hide the fact that remote code is executed.
- Do not run `sudo` automatically from the launcher.
- Scripts that perform destructive actions should ask for confirmation.
- Risky scripts should be marked with `medium` or `high` in the manifest.
- Users should be able to inspect scripts in the repository or private overlay before running them.
- Private paths must be validated before execution.
- Private env files should not be loaded globally by the core.
- Real secrets such as tokens or passwords should be handled carefully.

---

## Limitations

Version 1 has the following known limitations:

- requires network access for public operation
- does not support offline execution
- does not cache public scripts locally
- does not verify script checksums
- does not support automatic dependency installation
- does not support arbitrary external script repositories
- does not provide rollback to older script versions
- depends on GitHub raw file availability for public tools
- supports only one planned private overlay by convention
- does not manage private Git repositories automatically in the public core
- does not provide encrypted secret handling

---

## Future Ideas

Possible future improvements:

- local cache mode
- offline mode
- checksum verification
- versioned releases
- GitHub Actions for shellcheck and tests
- `sx-ctl doctor` command for environment checks
- category filtering
- fzf preview window
- manifest validation
- support for aliases
- support for script arguments in the manifest
- optional dependency helper functions
- multiple overlays:
  - `private`
  - `homelab`
  - `work`
- overlay management commands:
  - `sx-ctl overlay list`
  - `sx-ctl overlay status`
  - `sx-ctl overlay update`
- public admin tools for manifest validation
- encrypted private configuration support
- stronger secret management integration
