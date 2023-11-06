local md = require('mdtoc/markdown')
local toc = require('mdtoc/toc')
local config = require('mdtoc/config')
local utils = require('mdtoc/utils')

local empty_or_nil = utils.empty_or_nil
local falsey = utils.falsey
-- local truthy = utils.truthy

local M = {}
M.commands = {'insert', 'update', 'remove'}

local function fmt_fence_start(fence) return '<!-- '..fence..' -->' end

local function fmt_fence_end(fence) return '<!-- '..fence..' -->' end

local function get_fences()
  local fences = config.opts.fences
  if type(fences) == 'boolean' and fences then
    fences = config.defaults.fences
  end
  return fences
end

local function insert_toc(line)
  line = line or vim.api.nvim_win_get_cursor(0)[1]
  -- For before_toc option = false,
  -- When insert line is given, don't include headings before the insert line.
  -- If insert line is not given, don't include headings before current
  -- (cursor) line.
  local start = line
  if config.opts.headings and config.opts.headings.before_toc then
    start = 0
  end

  local lines = {}
  local fences = get_fences()

  local H = md.get_headings(start)
  if empty_or_nil(H) then
    if fences.enabled then
      lines = {
        fmt_fence_start(fences.start_text),
        '',
        fmt_fence_end(fences.end_text),
      }
    else
      vim.notify("No markdown headings", vim.log.levels.ERROR)
      return
    end
  else
    -- There are headings
    lines = toc.gen_toc_list(H)

    if fences.enabled then
      table.insert(lines, 1, '')
      table.insert(lines, 1, fmt_fence_start(fences.start_text))
      table.insert(lines, '')
      table.insert(lines, fmt_fence_end(fences.end_text))
    end
  end

  vim.api.nvim_buf_set_lines(0, line, line, true, lines)
end

local function remove_toc()
  local fences = get_fences()
  local fstart, fend = fmt_fence_start(fences.start_text), fmt_fence_end(fences.end_text)

  local locations = toc.find_fences(fstart, fend)
  if empty_or_nil(locations) or (falsey(locations.start) and falsey(locations.end_)) then
    vim.notify("No fences found!", vim.log.levels.ERROR)
    return
  end
  if locations.start and falsey(locations.end_) then
    vim.notify("No end fence found!", vim.log.levels.ERROR)
    return
  end
  if falsey(locations.start) and locations.end_ then
    vim.notify("No start fence found!", vim.log.levels.ERROR)
    return
  end
  if locations.start > locations.end_ then
    vim.notify("End fence found before start fence!", vim.log.levels.ERROR)
    return
  end

  utils.delete_lines(locations.start, locations.end_)

  return locations
end

local function update_toc()
  local locations = remove_toc()
  if empty_or_nil(locations) then
    return
  end
  return insert_toc(locations.start-1)
end

local function _debug_show_headings()
  vim.print(md.get_headings(vim.api.nvim_win_get_cursor(0)[1]))
end

local function handle_command(opts)
  if empty_or_nil(opts) or empty_or_nil(opts.fargs) then
    print("Please supply a command")
    return
  end

  local cmd = opts.fargs[1]
  if cmd == 'debug' then
    return _debug_show_headings()
  end

  local found = false
  for _, v in ipairs(M.commands) do
    if string.match(v, "^"..cmd) then
      cmd = v
      found = true
      break
    end
  end

  if not found then
    vim.notify("Unknown command "..cmd, vim.log.levels.ERROR)
    return
  end

  if cmd == "insert" then
    return insert_toc()
  elseif cmd == "update" then
    return update_toc()
  elseif cmd == "remove" then
    return remove_toc()
  else
    vim.notify("INTERNAL ERROR: Unhandled command "..cmd, vim.log.levels.ERROR)
  end
end

local function setup_commands()
  vim.api.nvim_create_user_command("Mdtoc", handle_command, {
    nargs = 1,
    complete = function()
      return M.commands
    end,
  })
end

local function setup_autocmds()
  M.autocmds = {}
  if config.opts.auto_update then
    local aup = config.opts.auto_update
    if type(aup) == 'boolean' then
      aup = config.defaults.auto_update
    end
    local id = vim.api.nvim_create_autocmd(aup.events, {
      pattern = aup.pattern,
      command = "silent! Mdtoc update",
    })
    table.insert(M, id)
  end
end

local function remove_autocmds()
  if empty_or_nil(M.autocmds) then
    return
  end
  for _, id in ipairs(M.autocmds) do
    vim.api.nvim_del_autocmd(id)
  end
end

function M.setup(opts)
  vim.g.mdtoc_loaded = 1
  config.merge_opts(opts)
  setup_autocmds()
  setup_commands()
end

function M.update_config(opts)
  config.update_opts(opts)
  remove_autocmds()
  setup_autocmds()
end

return M
