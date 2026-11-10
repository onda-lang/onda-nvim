# Changelog

## 0.1.0

- Initial versioned release, requiring Onda 0.9.0 and Neovim 0.10 or newer.
- Filetype, syntax, and indentation support for Onda source files, with JSON
  filetype support for `.ondaproject` manifests.
- Start Onda's built-in language server for diagnostics and semantic highlighting.
- Run sources and projects in the standalone GPU UI, with optional fast math and
  automatic, dark, or light theme selection.
- Create empty projects and package sources through `OndaCreateProject` and
  `OndaSaveAsProject`.
- Configure one `exec_path` for language services, playback, and project commands.
