<h1>
  <img src="assets/svg/onda-logo-dark-circle.svg" alt="onda logo" width="40" align="absmiddle" /> Onda Neovim plugin
</h1>

Neovim plugin for the [Onda](https://onda-lang.org) audio programming language.

## Requirements

- Neovim 0.10 or newer
- Onda 0.9.0 or newer
- an `onda` executable available on `PATH`, or an explicit configured path

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
  exec_path = "/path/to/onda",
})
```

## Configuration

```lua
require("onda").setup({
  exec_path = "onda",
  server_args = {},
  run_args = {},
  run_theme = "auto",
})
```

- `exec_path` selects the Onda executable for LSP, run, and project commands
- `run_args` are appended to `onda run <file>`
- `run_theme = "auto"` lets the CLI detect the system theme at startup
- `run_theme = "dark"` forces the dark run theme
- `run_theme = "light"` forces the light run theme

## Commands

- `:OndaRun` saves and runs the current `.onda`, `.on`, or `.ondaproject` buffer
- `:OndaRunWithFastMath` saves and runs the current buffer with `--fast-math` for that session
- `:OndaCreateProject [destination]` creates an empty project or packages the current Onda source
- `:OndaSaveAsProject [destination]` packages the current Onda source as a portable project
