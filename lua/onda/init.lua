local M = {}

local defaults = {
  server_path = "onda",
  server_args = {},
  run_path = nil,
  run_args = {},
  run_host = nil,
  run_theme = "auto",
  root_markers = { "Cargo.toml", ".git" },
}

local state = {
  opts = vim.deepcopy(defaults),
  initialized = false,
}

local function is_windows()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

local function path_exists(path)
  local stat = (vim.uv or vim.loop).fs_stat(path)
  return stat ~= nil
end

local function join_path(...)
  local sep = is_windows() and "\\" or "/"
  return table.concat({ ... }, sep)
end

local function parent_dir(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  if parent == path then
    return nil
  end
  return parent
end

local function find_root(path)
  local dir
  if path == "" then
    dir = vim.fn.getcwd()
  elseif path_exists(path) then
    dir = vim.fn.fnamemodify(path, ":p:h")
  else
    dir = vim.fn.fnamemodify(path, ":p")
  end

  while dir and dir ~= "" do
    for _, marker in ipairs(state.opts.root_markers) do
      if path_exists(join_path(dir, marker)) then
        return dir
      end
    end
    dir = parent_dir(dir)
  end

  return vim.fn.getcwd()
end

local function onda_lsp_cmd()
  local cmd = { state.opts.server_path }
  vim.list_extend(cmd, state.opts.server_args)
  table.insert(cmd, "lsp")
  return cmd
end

local function onda_run_cmd(path)
  local cmd = { state.opts.run_path or state.opts.server_path, "run", path }
  if state.opts.run_host == "webview" then
    table.insert(cmd, "--webview")
  end
  if state.opts.run_theme ~= nil then
    table.insert(cmd, "--theme")
    table.insert(cmd, state.opts.run_theme)
  end
  vim.list_extend(cmd, state.opts.run_args)
  return cmd
end

local function onda_project_cmd(destination, source)
  local cmd = { state.opts.run_path or state.opts.server_path, "project", destination }
  if source then
    vim.list_extend(cmd, { "--from", source })
  end
  return cmd
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Onda" })
end

local function file_extension(path)
  return vim.fn.fnamemodify(path, ":e"):lower()
end

local function is_onda_source(path)
  local extension = file_extension(path)
  return extension == "onda" or extension == "on"
end

local function is_onda_project(path)
  return file_extension(path) == "ondaproject"
end

local function is_onda_run_input(path)
  return is_onda_source(path) or is_onda_project(path)
end

local function save_buffer(bufnr, failure_message)
  if not vim.bo[bufnr].modified then
    return true
  end
  local wrote = pcall(function()
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd.write()
    end)
  end)
  if wrote then
    return true
  end
  notify(failure_message, vim.log.levels.ERROR)
  return false
end

local function absolute_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function request_project_destination(value, default, callback)
  if value and vim.trim(value) ~= "" then
    callback(absolute_path(vim.trim(value)))
    return
  end
  vim.ui.input({
    prompt = "Onda project destination: ",
    default = default,
    completion = "dir",
  }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    callback(absolute_path(vim.trim(input)))
  end)
end

local function run_project_command(destination, source, verb)
  local cmd = onda_project_cmd(destination, source)
  local ok, error_message = pcall(vim.system, cmd, {
    cwd = vim.fn.getcwd(),
    text = true,
  }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        notify(("%s Onda project: %s"):format(verb, destination))
        return
      end
      local detail = vim.trim(result.stderr or "")
      if detail == "" then
        detail = vim.trim(result.stdout or "")
      end
      if detail == "" then
        detail = "exit code " .. tostring(result.code)
      end
      notify("Onda project command failed: " .. detail, vim.log.levels.ERROR)
    end)
  end)
  if not ok then
    notify("Failed to start Onda project command: " .. tostring(error_message), vim.log.levels.ERROR)
  end
end

local function apply_highlights()
  local set_hl = vim.api.nvim_set_hl
  set_hl(0, "@lsp.type.port.onda", { default = true, link = "@lsp.type.parameter" })
  set_hl(0, "@lsp.type.state.onda", { default = true, link = "@variable.parameter" })
  set_hl(0, "@lsp.type.enumMember.onda", { default = true, link = "Constant" })
  set_hl(0, "@lsp.type.function.onda", { default = true, link = "Function" })
  set_hl(0, "@lsp.type.type.onda", { default = true, link = "Type" })
  set_hl(0, "@lsp.type.namespace.onda", { default = true, link = "Include" })
end

local function powershell_quote(value)
  return "'" .. value:gsub("'", "''") .. "'"
end

local function spawn_detached_windows(cmd, cwd)
  local powershell = vim.fn.exepath("powershell.exe")
  if powershell ~= "" then
    local script_path = vim.fn.tempname() .. ".ps1"
    local script_lines = {
      "$filePath = " .. powershell_quote(cmd[1]),
      "$workingDirectory = " .. powershell_quote(cwd),
    }
    local arg_expr = {}
    for _, arg in ipairs(vim.list_slice(cmd, 2)) do
      table.insert(arg_expr, powershell_quote(arg))
    end
    table.insert(script_lines, "$arguments = @(" .. table.concat(arg_expr, ", ") .. ")")
    table.insert(
      script_lines,
      "Start-Process -FilePath $filePath -WorkingDirectory $workingDirectory -WindowStyle Hidden -ArgumentList $arguments | Out-Null"
    )
    vim.fn.writefile(script_lines, script_path)

    local shell_cmd = table.concat({
      vim.fn.shellescape(powershell),
      "-NoProfile",
      "-NonInteractive",
      "-WindowStyle Hidden",
      "-ExecutionPolicy Bypass",
      "-File",
      vim.fn.shellescape(script_path),
    }, " ")
    local output = vim.fn.system(shell_cmd)
    local code = vim.v.shell_error
    vim.fn.delete(script_path)
    if code == 0 then
      return true
    end
    if output ~= "" then
      notify(
        "PowerShell run launch failed, falling back to direct launch: " .. output,
        vim.log.levels.WARN
      )
    end
  end

  local job_id = vim.fn.jobstart(cmd, { cwd = cwd, detach = true })
  return job_id > 0
end

local function spawn_detached(cmd, cwd)
  local uv = vim.uv or vim.loop
  if is_windows() then
    return spawn_detached_windows(cmd, cwd)
  end

  local handle
  handle = uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    detached = true,
    hide = true,
    cwd = cwd,
    stdio = { nil, nil, nil },
  }, function(code)
    if handle and not handle:is_closing() then
      handle:close()
    end
    if code == 0 then
      return
    end
    vim.schedule(function()
      notify(
        ("Onda run exited with code %d."):format(code),
        vim.log.levels.ERROR
      )
    end)
  end)

  if not handle then
    return false
  end
  uv.unref(handle)
  return true
end

function M.start_lsp(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "onda" then
    return
  end
  if #vim.lsp.get_clients({ bufnr = bufnr, name = "onda" }) > 0 then
    return
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  vim.lsp.start({
    name = "onda",
    cmd = onda_lsp_cmd(),
    root_dir = find_root(name),
    single_file_support = true,
  }, { bufnr = bufnr })
end

function M.run(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    notify("Onda run requires a file on disk.", vim.log.levels.ERROR)
    return
  end
  if not is_onda_run_input(path) then
    notify("Current buffer is not an Onda source or project.", vim.log.levels.ERROR)
    return
  end
  if not save_buffer(bufnr, "Failed to save Onda input before starting run.") then
    return
  end

  local cmd = onda_run_cmd(path)
  local cwd = vim.fn.fnamemodify(path, ":p:h")
  if spawn_detached(cmd, cwd) then
    return
  end

  local job_id = vim.fn.jobstart(cmd, { cwd = cwd, detach = true })
  if job_id <= 0 then
    notify("Failed to start Onda run.", vim.log.levels.ERROR)
  end
end

function M.create_project(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local current_path = vim.api.nvim_buf_get_name(bufnr)
  local source = is_onda_source(current_path) and current_path or nil

  local function create(selected_source)
    if selected_source
      and not save_buffer(bufnr, "Failed to save Onda source before creating project.")
    then
      return
    end
    local default_name = selected_source
        and vim.fn.fnamemodify(selected_source, ":t:r")
      or "onda-project"
    local default_dir = selected_source
        and vim.fn.fnamemodify(selected_source, ":p:h")
      or vim.fn.getcwd()
    local default = join_path(default_dir, default_name)
    request_project_destination(opts.args, default, function(destination)
      run_project_command(destination, selected_source, "Created")
    end)
  end

  if not source then
    create(nil)
    return
  end
  vim.ui.select({
    { label = "From current source", source = source },
    { label = "Empty project" },
  }, {
    prompt = "Create Onda project",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if choice then
      create(choice.source)
    end
  end)
end

function M.save_as_project(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local source = vim.api.nvim_buf_get_name(bufnr)
  if not is_onda_source(source) then
    notify("Current buffer is not an Onda source file.", vim.log.levels.ERROR)
    return
  end
  if not save_buffer(bufnr, "Failed to save Onda source before exporting project.") then
    return
  end

  local source_dir = vim.fn.fnamemodify(source, ":p:h")
  local source_name = vim.fn.fnamemodify(source, ":t:r")
  local default = join_path(source_dir, source_name .. "-project")
  request_project_destination(opts.args, default, function(destination)
    run_project_command(destination, source, "Saved")
  end)
end

function M.setup(opts)
  state.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), state.opts, opts or {})
  if state.opts.run_host ~= nil
    and state.opts.run_host ~= "egui"
    and state.opts.run_host ~= "webview"
  then
    notify("Invalid Onda run_host; expected 'egui', 'webview', or nil.", vim.log.levels.ERROR)
    state.opts.run_host = nil
  end
  if state.opts.run_theme ~= nil
    and state.opts.run_theme ~= "auto"
    and state.opts.run_theme ~= "dark"
    and state.opts.run_theme ~= "light"
  then
    notify("Invalid Onda run_theme; expected 'auto', 'dark', 'light', or nil.", vim.log.levels.ERROR)
    state.opts.run_theme = "auto"
  end
  if state.initialized then
    return
  end
  state.initialized = true

  local group = vim.api.nvim_create_augroup("OndaNvim", { clear = true })

  apply_highlights()

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "onda",
    callback = function(args)
      M.start_lsp(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      apply_highlights()
    end,
  })

  vim.api.nvim_create_user_command("OndaRun", function(command)
    M.run(command)
  end, {
    desc = "Run the current Onda source or project in the standalone run window",
  })

  vim.api.nvim_create_user_command("OndaCreateProject", function(command)
    M.create_project(command)
  end, {
    nargs = "?",
    complete = "dir",
    desc = "Create an empty Onda project or package the current source",
  })

  vim.api.nvim_create_user_command("OndaSaveAsProject", function(command)
    M.save_as_project(command)
  end, {
    nargs = "?",
    complete = "dir",
    desc = "Package the current Onda source as a project",
  })
end

return M
