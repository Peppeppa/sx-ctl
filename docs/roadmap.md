# Roadmap

## Phase 1: Documentation and Repository Structure

Goal: Create the initial public project structure and keep the project understandable before implementation starts.

- [x] Create `docs/requirements.md`
- [x] Create `docs/architecture.md`
- [x] Create `docs/roadmap.md`
- [x] Update `README.md` with a short project description
- [x] Add planned repository structure to `README.md`
- [x] Create base folders:
  - [x] `lib/`
  - [x] `scripts/`
  - [x] `templates/`
  - [x] `docs/`

---

## Phase 2: Public Manifest and Example Scripts

Goal: Define the public script registry and add the first runnable scripts.

- [ ] Create `manifest.txt`
- [ ] Use this manifest format:

```text
id|source|category|label|path|description|shell|deps|risk
```

- [ ] Add first public manifest entries:
  - [ ] `system.info`
  - [ ] `misc.hello`
- [ ] Create `scripts/system/info.sh`
- [ ] Create `scripts/misc/hello.sh`
- [ ] Ensure example scripts run with the shell defined in the manifest
- [ ] Add clear script headers to the example scripts
- [ ] Check that no manifest field contains the pipe character `|`
- [ ] Document the manifest fields in `README.md`

---

## Phase 3: Core Implementation

Goal: Implement the shared logic that all frontends will use.

- [ ] Create `lib/core.sh`
- [ ] Define public repository settings:
  - [ ] GitHub user: `Peppeppa`
  - [ ] Repository: `sx-ctl`
  - [ ] Branch: `main`
  - [ ] Raw base URL
- [ ] Implement `sx_fetch`
  - [ ] Use `curl` if available
  - [ ] Use `wget` as fallback
  - [ ] Print a clear error if neither is available
- [ ] Implement `sx_manifest_public`
  - [ ] Fetch public `manifest.txt`
- [ ] Implement `sx_private_root`
  - [ ] Default path: `$HOME/.config/sx-ctl/overlays/private`
- [ ] Implement `sx_manifest_private`
  - [ ] Return private manifest only if it exists
  - [ ] Do nothing if private overlay is missing
- [ ] Implement `sx_manifest_all`
  - [ ] Combine public and private manifests
- [ ] Implement `sx_list`
  - [ ] Show ID, source, category and label
- [ ] Implement `sx_find_entry`
  - [ ] Resolve one tool ID to one manifest line
- [ ] Implement field extraction from manifest entries
  - [ ] `id`
  - [ ] `source`
  - [ ] `category`
  - [ ] `label`
  - [ ] `path`
  - [ ] `description`
  - [ ] `shell`
  - [ ] `deps`
  - [ ] `risk`
- [ ] Implement `sx_run`
  - [ ] Resolve tool ID
  - [ ] Detect source
  - [ ] Run public tools from GitHub raw URL
  - [ ] Run private tools from local overlay path
  - [ ] Forward script arguments
  - [ ] Return script exit code
- [ ] Implement public script execution
  - [ ] Download selected script to temporary file
  - [ ] Execute it with `sh` or `bash`
  - [ ] Clean up temporary file
- [ ] Implement private script execution
  - [ ] Resolve local path inside private overlay
  - [ ] Refuse unsafe paths such as absolute paths or `..`
  - [ ] Execute it with `sh` or `bash`
- [ ] Implement shell handling
  - [ ] Support `sh`
  - [ ] Support `bash`
  - [ ] Print a clear error for unsupported shell values
  - [ ] Print a clear error if `bash` is required but missing
- [ ] Implement useful error messages
  - [ ] Unknown tool ID
  - [ ] Missing manifest
  - [ ] Missing script
  - [ ] Network failure
  - [ ] Unsupported source
  - [ ] Unsupported shell

---

## Phase 4: Basic Frontend

Goal: Build the minimal UI that works without optional dependencies.

- [ ] Create `sx-ctl-basic.sh`
- [ ] Load `lib/core.sh`
- [ ] Support direct listing:

```sh
sx-ctl-basic.sh list
```

- [ ] Support direct execution by ID:

```sh
sx-ctl-basic.sh system.info
```

- [ ] Support explicit run syntax:

```sh
sx-ctl-basic.sh run system.info
```

- [ ] Support forwarding arguments to scripts:

```sh
sx-ctl-basic.sh run system.info --verbose
```

- [ ] Add simple interactive mode when no arguments are given
- [ ] Interactive mode should:
  - [ ] Show available tools
  - [ ] Ask for a tool ID
  - [ ] Run selected tool
  - [ ] Exit cleanly on empty input
- [ ] Add `help` output
- [ ] Add `version` output
- [ ] Keep the basic frontend POSIX-compatible where possible
- [ ] Avoid dependencies on:
  - [ ] `fzf`
  - [ ] `jq`
  - [ ] `git`
  - [ ] Python
  - [ ] Node.js

---

## Phase 5: Main Entrypoint

Goal: Create the public entrypoint used by curl and by the installed wrapper.

- [ ] Create `sx-ctl.sh`
- [ ] Implement remote loading of frontend files
- [ ] Support default mode
  - [ ] Use `fzf` frontend if available later
  - [ ] Fall back to basic frontend
- [ ] Support forced basic mode:

```sh
sx-ctl.sh --basic
```

- [ ] Support forced fzf mode:

```sh
sx-ctl.sh --fzf
```

- [ ] Forward all remaining arguments to selected frontend
- [ ] Support direct curl usage:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh
```

- [ ] Support direct curl usage with arguments:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh -s -- system.info
```

- [ ] Print clear error messages if frontend loading fails
- [ ] Keep `sx-ctl.sh` small and focused

---

## Phase 6: Installer

Goal: Allow users to install a local `sx-ctl` command without cloning the repository.

- [ ] Create `install.sh`
- [ ] Install wrapper to:

```text
~/.local/bin/sx-ctl
```

- [ ] Create `~/.local/bin` if it does not exist
- [ ] Make wrapper executable
- [ ] Wrapper should download latest `sx-ctl.sh` on every run
- [ ] Wrapper should forward all arguments
- [ ] Support both `curl` and `wget`
- [ ] Detect whether `~/.local/bin` is in `PATH`
- [ ] Print PATH instructions if needed
- [ ] Document installation command in `README.md`
- [ ] Document uninstall command:

```sh
rm -f ~/.local/bin/sx-ctl
```

---

## Phase 7: Optional Private Overlay Support

Goal: Prepare the public core to discover and use a local private overlay.

- [ ] Define default private overlay path:

```text
~/.config/sx-ctl/overlays/private
```

- [ ] Support private manifest at:

```text
~/.config/sx-ctl/overlays/private/manifest.txt
```

- [ ] If private manifest exists, include private tools in `sx-ctl list`
- [ ] If private manifest does not exist, ignore private overlay silently
- [ ] Support private scripts under:

```text
~/.config/sx-ctl/overlays/private/scripts/
```

- [ ] Support private env file convention:

```text
~/.config/sx-ctl/overlays/private/env
```

- [ ] Do not load private env automatically in the core
- [ ] Let private scripts load private env when needed
- [ ] Support private manifest entries with `source=private`
- [ ] Refuse private script paths containing `..`
- [ ] Refuse private script paths that are absolute paths
- [ ] Add README section: private overlay setup
- [ ] Add README example:

```sh
git clone git@github.com:Peppeppa/sx-ctl-private.git ~/.config/sx-ctl/overlays/private
```

- [ ] Add README example private manifest entry
- [ ] Add README example private env usage

---

## Phase 8: Enhanced `fzf` Frontend

Goal: Add a nicer terminal UI while keeping basic mode as the compatibility baseline.

- [ ] Create `sx-ctl-fzf.sh`
- [ ] Load `lib/core.sh`
- [ ] Check whether `fzf` is installed
- [ ] If `fzf` is missing and `--fzf` was forced, print a clear error
- [ ] Show tools in searchable list
- [ ] Include these fields in the selection:
  - [ ] ID
  - [ ] source
  - [ ] category
  - [ ] label
  - [ ] risk
- [ ] Run selected tool
- [ ] Support direct execution by ID
- [ ] Support `list`
- [ ] Support `help`
- [ ] Support argument forwarding
- [ ] Optionally add preview text later:
  - [ ] description
  - [ ] dependencies
  - [ ] script path
- [ ] Update `sx-ctl.sh` to prefer fzf mode when available
- [ ] Ensure fallback to basic mode still works

---

## Phase 9: Script Template

Goal: Provide an optional template for better structured scripts, without requiring a shared runtime library.

- [ ] Create `templates/script-template.sh`
- [ ] Include metadata header:
  - [ ] ID
  - [ ] Name
  - [ ] Description
  - [ ] Dependencies
  - [ ] Risk
- [ ] Include `set -eu` for POSIX shell template
- [ ] Include optional `need_cmd` helper
- [ ] Include optional `confirm` helper
- [ ] Include `main` function
- [ ] Include `main "$@"`
- [ ] Document that the template is optional
- [ ] Document that normal `sh` and `bash` scripts are supported
- [ ] Add README section: adding a new script
- [ ] Add README example for a quick script
- [ ] Add README example for a managed script using the template

---

## Phase 10: Private Admin Tooling

Goal: Plan and later implement private tools that help manage the private overlay.

These tools are expected to live in the private overlay, not in the public repo.

Private overlay path:

```text
~/.config/sx-ctl/overlays/private
```

Planned private admin tools:

- [ ] `admin.add-script`
- [ ] `admin.validate-manifest`
- [ ] `admin.update-private`
- [ ] `admin.status`

### `admin.add-script`

- [ ] Ask for tool ID
- [ ] Ask for category
- [ ] Ask for label
- [ ] Ask for script path
- [ ] Ask for description
- [ ] Ask for shell
- [ ] Ask for dependencies
- [ ] Ask for risk level
- [ ] Create target script from private template
- [ ] Add entry to private `manifest.txt`
- [ ] Refuse duplicate tool IDs
- [ ] Refuse unsafe paths
- [ ] Show `git status`
- [ ] Print next steps for `git add`, `git commit`, `git push`

### `admin.validate-manifest`

- [ ] Check that manifest exists
- [ ] Check field count
- [ ] Check duplicate IDs
- [ ] Check source field
- [ ] Check shell field
- [ ] Check that referenced scripts exist
- [ ] Check that paths are safe

### `admin.update-private`

- [ ] Run `git pull --ff-only` inside private overlay
- [ ] Print current branch
- [ ] Print update result
- [ ] Fail clearly if private overlay is not a Git repository

### `admin.status`

- [ ] Show private overlay path
- [ ] Show whether private manifest exists
- [ ] Show number of private tools
- [ ] Show Git status if available
- [ ] Show whether private env exists

---

## Phase 11: README Documentation

Goal: Make the project usable from the repository page.

- [ ] Add project description
- [ ] Add quick start section
- [ ] Add direct curl usage
- [ ] Add installation usage
- [ ] Add command examples
- [ ] Explain basic mode
- [ ] Explain fzf mode
- [ ] Explain manifest format
- [ ] Explain how to add public scripts
- [ ] Explain script template
- [ ] Explain private overlay concept
- [ ] Explain private env convention
- [ ] Explain security considerations
- [ ] Explain uninstall
- [ ] Link to:
  - [ ] `docs/requirements.md`
  - [ ] `docs/architecture.md`
  - [ ] `docs/roadmap.md`

---

## Phase 12: Testing and Quality Checks

Goal: Verify that the core behavior works reliably.

### Manual Tests

- [ ] Run direct curl command
- [ ] Run installed wrapper
- [ ] Run `sx-ctl list`
- [ ] Run `sx-ctl system.info`
- [ ] Run `sx-ctl run system.info`
- [ ] Run unknown tool ID
- [ ] Run with missing private overlay
- [ ] Run with private overlay available
- [ ] Run public `sh` script
- [ ] Run public `bash` script
- [ ] Run private `sh` script
- [ ] Run private `bash` script
- [ ] Run without `fzf`
- [ ] Run with `--basic`
- [ ] Run with `--fzf`

### Automated Checks Later

- [ ] Add `tests/smoke.sh`
- [ ] Test manifest parsing
- [ ] Test duplicate ID detection
- [ ] Test unsupported shell error
- [ ] Test missing script error
- [ ] Test unsafe private paths
- [ ] Add ShellCheck workflow
- [ ] Add GitHub Actions workflow
- [ ] Add `shfmt` formatting check

---

## Phase 13: Future Improvements

These ideas are not required for version 1.

- [ ] Support multiple overlays:
  - [ ] `private`
  - [ ] `homelab`
  - [ ] `work`
- [ ] Add `sx-ctl overlay list`
- [ ] Add `sx-ctl overlay status`
- [ ] Add `sx-ctl overlay update`
- [ ] Add local cache mode
- [ ] Add offline mode
- [ ] Add checksum verification
- [ ] Add manifest validation command to public core
- [ ] Add `sx-ctl doctor`
- [ ] Add category filtering
- [ ] Add fzf preview window
- [ ] Add aliases for tool IDs
- [ ] Add support for default arguments
- [ ] Add versioned releases
- [ ] Add changelog
