
## 3. `docs/roadmap.md`

Inhalt: konkrete Todo-Liste.

```markdown
# Roadmap

## Phase 1: Project structure

- [ ] Create `docs/requirements.md`
- [ ] Create `docs/architecture.md`
- [ ] Create `docs/roadmap.md`
- [ ] Create basic repository structure
- [ ] Update `README.md` with project goal

## Phase 2: Manifest and example script

- [ ] Create `manifest.txt`
- [ ] Define manifest format
- [ ] Add first example tool `scripts/system/info.sh`
- [ ] Add optional script template

## Phase 3: Core logic

- [ ] Create `lib/core.sh`
- [ ] Implement remote file fetching with `curl` or `wget`
- [ ] Implement manifest loading
- [ ] Implement tool listing
- [ ] Implement tool lookup by ID
- [ ] Implement script download and execution
- [ ] Support `sh` and `bash` scripts

## Phase 4: Basic frontend

- [ ] Create `sx-ctl-basic.sh`
- [ ] Add `list` command
- [ ] Add direct tool execution by ID
- [ ] Add interactive prompt for tool selection
- [ ] Add clear error messages

## Phase 5: Enhanced frontend

- [ ] Create `sx-ctl-fzf.sh`
- [ ] Detect whether `fzf` is installed
- [ ] Add searchable tool selection
- [ ] Show category and description in the selection
- [ ] Add fallback behavior

## Phase 6: Entrypoint

- [ ] Create `sx-ctl.sh`
- [ ] Route to basic mode or fzf mode
- [ ] Add global flags `--basic` and `--fzf`
- [ ] Forward arguments to selected frontend

## Phase 7: Installer

- [ ] Create `install.sh`
- [ ] Install local wrapper as `~/.local/bin/sx-ctl`
- [ ] Add PATH warning if needed
- [ ] Document installation in `README.md`

## Phase 8: Documentation cleanup

- [ ] Document direct usage via `curl`
- [ ] Document installed usage
- [ ] Document how to add new scripts
- [ ] Document manifest fields
- [ ] Document security considerations

## Phase 9: Testing

- [ ] Test direct execution via `curl`
- [ ] Test installed command
- [ ] Test `sx-ctl list`
- [ ] Test existing tool execution
- [ ] Test unknown tool ID
- [ ] Test behavior without `fzf`
- [ ] Test behavior without `bash` for bash-based scripts
