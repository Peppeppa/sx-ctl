# sx-ctl

`sx-ctl` is a lightweight command-line launcher for running shell scripts from this GitHub repository.

The goal is to run and update tools centrally without cloning or pulling the repository manually.

## Concept

`sx-ctl` downloads only the files required for the current command:

- the launcher
- the manifest
- the selected script

It does **not** clone the full repository.

## Usage

Run directly:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh
```

Run a specific tool directly:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/sx-ctl.sh | sh -s -- system.info
```

Install local command:

```sh
curl -fsSL https://raw.githubusercontent.com/Peppeppa/sx-ctl/main/install.sh | sh
```

After installation:

```sh
sx-ctl
sx-ctl list
sx-ctl system.info
sx-ctl --basic
sx-ctl --fzf
```

## Planned Structure

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
│   └── misc/
├── templates/
│   └── script-template.sh
└── docs/
    ├── requirements.md
    ├── architecture.md
    └── roadmap.md
```

## Manifest

Available tools are registered in `manifest.txt`.

Format:

```text
id|source|category|label|path|description|shell|deps|risk
```

Example:

```text
system.info|public|system|Systeminformationen|scripts/system/info.sh|Zeigt Systeminformationen|sh|uname,df|low
misc.hello|public|misc|Hello Demo|scripts/misc/hello.sh|Ein simples Testscript|bash|bash|low
```

## Private Overlay

`sx-ctl` can optionally use a local private overlay for personal scripts and configuration.

Default path:

```text
~/.config/sx-ctl/overlays/private
```

Example setup:

```sh
git clone git@github.com:Peppeppa/sx-ctl-private.git ~/.config/sx-ctl/overlays/private
```

If the private overlay contains a `manifest.txt`, its tools are shown together with public tools.

If it does not exist, `sx-ctl` works normally with public tools only.

## Security Notice

`sx-ctl` downloads and executes shell scripts.

Only use it if you trust the repository and the scripts you run. Scripts that perform destructive actions should ask for confirmation before making changes.

## Documentation

More planning documents:

- [`docs/requirements.md`](docs/requirements.md)
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/roadmap.md`](docs/roadmap.md)
