# Requirements

## Project Goal

`sx-ctl` is a lightweight command-line launcher for running shell scripts hosted in this GitHub repository.

The tool should allow users to run available scripts without cloning or pulling the repository manually.

## Functional Requirements

- FR-01: `sx-ctl` can list available tools.
- FR-02: `sx-ctl` can execute a tool by its ID.
- FR-03: `sx-ctl` can be started directly via `curl`.
- FR-04: `sx-ctl` can be installed as a local command.
- FR-05: `sx-ctl` supports a basic mode without optional UI dependencies.
- FR-06: `sx-ctl` optionally supports an enhanced `fzf`-based UI.
- FR-07: `sx-ctl` can execute plain `sh` and `bash` scripts.
- FR-08: New tools can be added by placing scripts in the repository and adding them to the manifest.
- FR-09: Scripts can be organized by category.
- FR-10: Arguments can be forwarded to selected scripts.

## Non-Functional Requirements

- NFR-01: The basic mode should run on minimal Linux systems.
- NFR-02: The tool should not require `git`, `jq`, Python, Node.js or other large dependencies.
- NFR-03: The implementation should be modular.
- NFR-04: The system should avoid duplicated launcher logic where possible.
- NFR-05: The tool should only download the files required for the selected action.
- NFR-06: Error messages should be understandable.
- NFR-07: Remote code execution risks should be documented in the README.
- NFR-08: The project should be easy to extend with new scripts.

## Out of Scope for Version 1

- Automatic dependency installation for tool scripts.
- A shared runtime library for scripts.
- Graphical user interfaces.
- Running scripts from external repositories.
- Complex plugin management.
- Local caching.
