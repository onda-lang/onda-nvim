# Onda Neovim Support

This repo contains the Neovim plugin for Onda.

It provides:

- `.onda` and `.on` filetype detection
- regex syntax highlighting
- builtin LSP startup through `onda lsp`
- `:OndaRunPatch`, which launches the standalone preview window with `onda preview <file>`

## Requirements

- Neovim 0.10 or newer
- an `onda` executable available on `PATH`, or an explicit configured path

If you need to build the CLI locally:

```bash
cargo build -p onda_cli --release
```

That produces the binary at:
- Windows: `target/release/onda.exe`
- macOS/Linux: `target/release/onda`

## Install

Install this repo with your normal Neovim plugin manager.

### `lazy.nvim`

```lua
return {
  "onda-lang/onda-nvim",
  config = function()
    require("onda").setup()
  end,
}
```

If `onda` is not already on `PATH`, configure it explicitly:

```lua
require("onda").setup({
  server_path = "C:/path/to/onda.exe",
})
```

macOS/Linux example:

```lua
require("onda").setup({
  server_path = "/path/to/onda",
})
```

### Manual install without a plugin manager

Copy or symlink this repo into a standard `pack` location.

You can also copy the contents of this repo directly into your Neovim config/runtime path.
That works because this folder already has the normal Neovim runtime layout:
- `ftdetect/`
- `ftplugin/`
- `lua/`
- `plugin/`
- `syntax/`

Typical targets:
- Windows: `%LOCALAPPDATA%\\nvim\\`
- macOS/Linux: `~/.config/nvim/`

For example, copying the contents of this repo into `~/.config/nvim/` will install the plugin without a plugin manager.

macOS/Linux example:

```bash
mkdir -p ~/.local/share/nvim/site/pack/onda/start
ln -s /path/to/onda-nvim ~/.local/share/nvim/site/pack/onda/start/onda.nvim
```

Windows PowerShell example:

```powershell
New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\nvim-data\site\pack\onda\start" | Out-Null
New-Item -ItemType SymbolicLink `
  -Path "$env:LOCALAPPDATA\nvim-data\site\pack\onda\start\onda.nvim" `
  -Target "C:\path\to\onda-nvim"
```

Then add your configuration in `init.lua`:

```lua
require("onda").setup({
  server_path = "onda",
})
```

## Configuration

```lua
require("onda").setup({
  server_path = "onda",
  server_args = {},
  preview_path = nil,
  preview_args = {},
  preview_host = nil,
  preview_theme = "auto",
  root_markers = { "Cargo.toml", ".git" },
})
```

Notes:

- `server_path` is used for `onda lsp`
- `preview_path` defaults to `server_path`; this is mainly a development override if you want `:OndaRunPatch` to use a different binary for `onda preview`
- `preview_args` are appended to `onda preview <file>`
- `preview_host = "egui"` uses the native egui preview host
- `preview_host = "webview"` adds `--webview` to `:OndaRunPatch`
- `preview_host = nil` leaves host selection to the CLI default, which is egui
- `preview_theme = "auto"` follows the system theme when available
- `preview_theme = "dark"` forces the dark preview theme
- `preview_theme = "light"` forces the light preview theme
- `root_markers` controls project root detection for the builtin LSP startup

Example:

```lua
require("onda").setup({
  preview_host = "webview",
  preview_theme = "dark",
})
```

If the plugin is on your runtimepath, it auto-calls `require("onda").setup()` with defaults.
Providing your own `setup(...)` call overrides those defaults.

## Commands

- `:OndaRunPatch` saves the current `.onda` or `.on` buffer and opens the standalone preview window

## What happens automatically

Once installed, the plugin:

- detects `.onda` and `.on` files
- starts `onda lsp` when you open an Onda buffer
- applies Onda syntax highlighting

## Troubleshooting

If the LSP does not start:
- check that `onda` runs in a terminal
- set `server_path` explicitly to the built binary

If `:OndaRunPatch` does not launch:
- check that `preview_path` or `server_path` points to a working `onda` binary
- make sure the current buffer is saved to disk
