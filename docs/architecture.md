# Architecture

## Overview

`sx-ctl` is a lightweight command-line launcher for running shell scripts hosted in this GitHub repository.

The main idea is that users can run tools without cloning the repository and without manually pulling updates. The launcher downloads only the files that are required for the current command.

`sx-ctl` supports two usage modes:

1. Direct execution via `curl`
2. Installed usage through a local `sx-ctl` command

The project is intentionally designed to stay small, portable and easy to extend.

---

## Goals

- Provide a simple command-line interface for running scripts from this repository.
- Allow scripts to be updated centrally through GitHub.
- Avoid requiring users to clone or pull the repository.
- Support minimal Linux systems through a basic frontend.
- Support an enhanced terminal UI when optional tools like `fzf` are available.
- Allow quick addition of normal `sh` or `bash` scripts.
- Keep the architecture understandable for a small software engineering project.

---

## Non-Goals

The first version of `sx-ctl` does not aim to provide:

- automatic dependency installation
- a shared runtime library for all scripts
- local caching
- execution of scripts from external repositories
- graphical user interfaces
- complex plugin management
- user authentication
- package management
- rollback functionality

These features may be considered later, but they are intentionally out of scope for version 1.

---

## Repository Structure

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

---

## Components

### `sx-ctl.sh`

`sx-ctl.sh` is the main entrypoint of the project.

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
- display tool IDs, categories, labels and descriptions
- improve usability for larger tool collections
- call the shared core logic to execute tools

If `fzf` is not available, the main entrypoint should normally fall back to the basic frontend.

If the user explicitly requests fzf mode with `--fzf`, the tool should print a clear error message when `fzf` is missing.

---

### `lib/core.sh`

`lib/core.sh` contains the shared core logic.

Responsibilities:

- define the base URL for raw GitHub files
- fetch remote files using `curl` or `wget`
- load `manifest.txt`
- list available tools
- resolve a tool ID to a script path
- determine which shell should execute a script
- download the selected script to a temporary file
- execute the selected script
- clean up temporary files
- forward arguments to the selected script
- return the exit status of the executed script

The core should not contain UI-specific logic.

It should not decide how the user selects a tool. It should only provide functions that frontends can call.

---

### `manifest.txt`

`manifest.txt` is the registry of available tools.

It is the single source of truth for:

- available tool IDs
- categories
- display names
- script paths
- descriptions
- required shell
- optional dependency information
- risk level

Planned format:

```text
id|category|label|path|description|shell|deps|risk
```

Example:

```text
system.info|system|Systeminformationen|scripts/system/info.sh|Zeigt Systeminformationen|sh|uname,df|low
network.ports|network|Offene Ports|scripts/network/ports.sh|Zeigt offene Ports|sh|ss,netstat|low
docker.cleanup|docker|Docker Cleanup|scripts/docker/cleanup.sh|Entfernt ungenutzte Docker-Ressourcen|bash|docker|medium
misc.hello|misc|Hello Demo|scripts/misc/hello.sh|Ein simples Testscript|bash|bash|low
```

Field meaning:

| Field | Description |
|---|---|
| `id` | Stable command identifier, for example `system.info` |
| `category` | Logical group, for example `system`, `network`, `docker` |
| `label` | Human-readable name shown in menus |
| `path` | Path to the script inside the repository |
| `description` | Short explanation of what the script does |
| `shell` | Shell used to execute the script, usually `sh` or `bash` |
| `deps` | Informational list of dependencies |
| `risk` | Risk level such as `low`, `medium` or `high` |

The manifest is intentionally kept as a pipe-separated text file instead of JSON, because it can be parsed with standard shell tools.

---

### `scripts/`

The `scripts/` directory contains the actual tools.

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

1. exist in the repository
2. be listed in `manifest.txt`
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
  | loads manifest.txt
  | lists tools or resolves selected tool ID
  | downloads selected script
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
  | loads manifest.txt
  | resolves system.info
  | downloads scripts/system/info.sh
  v
scripts/system/info.sh
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
Core resolves script path from manifest
  |
  v
Core downloads selected script
  |
  v
Core executes script with configured shell
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

---

## Data Flow

`sx-ctl` should only download files that are needed for the current operation.

For an interactive call:

```text
sx-ctl
```

Expected downloads:

```text
sx-ctl.sh
sx-ctl-basic.sh or sx-ctl-fzf.sh
lib/core.sh
manifest.txt
selected script
```

For direct tool execution:

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

The following should not be downloaded:

```text
.git/
repository history
other branches
unselected scripts
the full repository archive
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
- metadata such as category, description and risk can be stored centrally

Consequence:

- adding a new script requires updating `manifest.txt`
- the manifest must be kept consistent with the files in `scripts/`

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

### 5. Keep Frontend and Core Separate

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

### 6. Provide Basic Mode as Compatibility Baseline

`sx-ctl-basic.sh` is the baseline frontend.

Reason:

- the tool should work on minimal Linux systems
- optional UI tools may not be installed
- basic mode is easier to test and debug

Consequence:

- all core functionality must be usable without `fzf`
- fzf mode is a convenience feature, not a requirement

---

### 7. Do Not Add a Shared Runtime Library in Version 1

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

### 8. Do Not Automatically Install Dependencies in Version 1

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

### 9. Download Only Required Files

`sx-ctl` downloads only the files needed for the current command.

Reason:

- avoids cloning the repository
- keeps execution fast
- ensures users always run the latest remote version

Consequence:

- each command may require network access
- no offline mode is available in version 1
- GitHub availability affects execution

---

### 10. Execute Scripts as Separate Processes

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
- missing script path in manifest
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
```

---

## Security Considerations

`sx-ctl` downloads and executes shell scripts from a GitHub repository.

This means users must trust the repository and its maintainers.

The README should clearly document this behavior.

Important security rules for the project:

- Do not hide the fact that remote code is executed.
- Do not run `sudo` automatically from the launcher.
- Scripts that perform destructive actions should ask for confirmation.
- Risky scripts should be marked with `medium` or `high` in the manifest.
- Users should be able to inspect scripts in the repository before running them.

---

## Limitations

Version 1 has the following known limitations:

- requires network access for normal operation
- does not support offline execution
- does not cache scripts locally
- does not verify script checksums
- does not support automatic dependency installation
- does not support external script repositories
- does not provide rollback to older script versions
- depends on GitHub raw file availability

---

## Future Ideas

Possible future improvements:

- local cache mode
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
- offline mode for installed tools

These ideas are not part of version 1 but may be useful later.
