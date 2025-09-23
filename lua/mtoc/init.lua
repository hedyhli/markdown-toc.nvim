local toc = require('mtoc/toc')
local config = require('mtoc/config')
local utils = require('mtoc/utils')

local empty_or_nil = utils.empty_or_nil
local falsey = utils.falsey

local M = {}
M.commands = {'insert', 'update', 'remove', 'update_all'}

local function fmt_fence_start(fence, label)
  if label and label ~= '' then
    return '<!-- '..fence..':'..label..' -->'
  end
  return '<!-- '..fence..' -->'
end
local function fmt_fence_end(fence, label)
  if label and label ~= '' then
    return '<!-- '..fence..':'..label..' -->'
  end
  return '<!-- '..fence..' -->'
end

local function get_fences()
  local fences = config.opts.fences
  if type(fences) == 'boolean' and fences then
    fences = config.defaults.fences
  end
  return fences
end

local function insert_toc(opts)
  if not opts then
    opts = {}
  end

  -- Determine insertion point (cursor by default) independent of generation scope.
  local insert_at = opts.line or utils.current_line()

  local lines = {}
  local fences = get_fences()
  local use_fence = fences.enabled and not opts.disable_fence

  -- Generate either a full or a partial (scoped) ToC based on config
  local hcfg = config.opts.headings
  local label = opts.label
  if (hcfg.min_depth ~= nil or hcfg.partial_under_cursor) then
    -- Determine current section range and build partial TOC strictly from it
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local s_range, e_range = toc.find_current_section_range(cur)
    lines = toc.gen_toc_list_for_range(s_range, e_range)
    -- Create and freeze a stable short-hash label from the parent heading text
    if not label or label == '' then
      local heading_line = vim.api.nvim_buf_get_lines(0, s_range, s_range+1, false)[1] or ''
      local _, heading_name = string.match(heading_line, config.opts.headings.pattern)
      heading_name = heading_name or heading_line
      local new_hash
      local ok, dig = pcall(vim.fn.sha256, heading_name)
      if ok and type(dig) == 'string' then
        new_hash = string.sub(dig, 1, 7)
      else
        local sum = 0
        for i = 1, #heading_name do sum = (sum * 33 + string.byte(heading_name, i)) % 0xFFFFFFFF end
        new_hash = string.format('%07x', sum)
      end
      label = new_hash
    end
  else
    -- Full ToC: optionally include headings before the insertion point in generation
    local gen_start = insert_at
    if hcfg.before_toc then
      gen_start = 0
    end
    lines = toc.gen_toc_list(gen_start)
  end
  if empty_or_nil(lines) then
    if use_fence then
      lines = {
        fmt_fence_start(fences.start_text, label),
        '',
        fmt_fence_end(fences.end_text, label),
      }
    else
      vim.notify("No markdown headings", vim.log.levels.ERROR)
      return
    end
  else
    lines = config.opts.toc_list.post_processor(lines)

    if use_fence then
      table.insert(lines, 1, '')
      table.insert(lines, 1, fmt_fence_start(fences.start_text, label))
      table.insert(lines, '')
      table.insert(lines, fmt_fence_end(fences.end_text, label))
    end
  end

  utils.insert_lines(insert_at, lines)
end

local function remove_toc(not_found_ok)
  local fences = get_fences()
  local hcfg = config.opts.headings
  local locations
  if hcfg.min_depth ~= nil or hcfg.partial_under_cursor then
    -- Try labeled fences for current section first
    local label = toc.current_section_slug()
    if label and label ~= '' then
      locations = toc.find_fences_labeled(fences.start_text, fences.end_text, label)
    end
  end
  if not locations then
    local fstart, fend = fmt_fence_start(fences.start_text), fmt_fence_end(fences.end_text)
    locations = toc.find_fences(fstart, fend)
  end
  -- Try to detect and return label from the start fence line if present
  if locations and locations.start then
    local line = vim.api.nvim_buf_get_lines(0, locations.start-1, locations.start, false)[1] or ''
    local pat = '^<!%-%- %s*'..fences.start_text..':([%w%-%._]+) %-%->%s*$'
    local found = string.match(line, pat)
    if found then
      locations.label = found
    end
  end
  if empty_or_nil(locations) or (falsey(locations.start) and falsey(locations.end_)) then
    if not not_found_ok then
      vim.notify("No fences found!", vim.log.levels.ERROR)
    end
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

local function update_toc(opts, fail_ok)
  if opts.range_start and opts.range_end then
    utils.delete_lines(opts.range_start, opts.range_end)
    pcall(vim.cmd, 'silent undojoin')
    local use_fence = opts.bang
    return insert_toc({ line = opts.range_start-1, disable_fence = not use_fence })
  end

  local locations = remove_toc(fail_ok)
  if empty_or_nil(locations) then
    return
  end
  pcall(vim.cmd, 'silent undojoin')
  opts.line = locations.start-1
  -- Reuse label if present (for partial ToCs)
  if locations.label then
    opts.label = locations.label
  end
  return insert_toc(opts)
end

local function update_or_remove_toc(opts)
  if opts.range_start and opts.range_end then
    return update_toc(opts)
  end

  local locations = remove_toc(true)
  opts = opts or {}
  if empty_or_nil(locations) then
    opts.line = nil
    return insert_toc(opts)
  end
  opts.line = locations.start-1
  return insert_toc(opts)
end

local function _debug_show_headings()
  local line = utils.current_line()
  local hcfg = config.opts.headings
  local lines
  if hcfg.min_depth ~= nil or hcfg.partial_under_cursor then
    lines = toc.gen_toc_list_scoped()
  else
    lines = toc.gen_toc_list(line)
  end
  utils.insert_lines(line, lines)
end

local function dbg(msg)
  if config.opts and config.opts.debug then
    vim.notify('[mtoc] '..msg, vim.log.levels.INFO)
  end
end

-- Update all fenced ToCs in the current buffer. Preserves labels for partial ToCs.
local function update_all_tocs()
  local fences = get_fences()
  -- Even if fences are currently disabled in config, still attempt to update
  -- any existing fenced ToCs in the buffer.
  local all = {}
  local ok, tocmod = pcall(require, 'mtoc/toc')
  if ok and tocmod.find_all_fences then
    all = tocmod.find_all_fences()
  else
    -- Fallback scanner: find all fenced blocks with optional labels
    local start_text = fences.start_text
    local end_text = fences.end_text
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local in_code = false
    local i = 1
    while i <= #lines do
      local line = lines[i]
      if line:find('^```') then
        in_code = not in_code
      elseif not in_code then
        local label = nil
        local start_pat = '^<!%-%- %s*'..start_text..'(?::([%w%-%._]+))? %-%->%s*$'
        local s_label = line:match(start_pat)
        if s_label ~= nil or line:match('^<!%-%- %s*'..start_text..' %-%->%s*$') then
          label = s_label
          -- find matching end
          local j = i + 1
          local end_pat = '^<!%-%- %s*'..end_text..(label and (':'..label) or '')..' %-%->%s*$'
          while j <= #lines do
            local l2 = lines[j]
            if l2:find('^```') then
              in_code = not in_code
            elseif not in_code then
              if l2:match(end_pat) then
                -- convert to 0-based [start0, end0_excl]
                table.insert(all, { start0 = i-1, end0 = j, label = label })
                i = j -- advance to end
                break
              end
            end
            j = j + 1
          end
        end
      end
      i = i + 1
    end
  end
  dbg('auto_update: found '..tostring(#all)..' fenced ToCs')
  if empty_or_nil(all) then return end
  -- Process from bottom to top to keep indices stable while replacing lines
  for i = #all, 1, -1 do
    local item = all[i]
    -- Re-read the start fence line to preserve the exact existing label
    do
      local s0 = item.start0 or (item.start and (item.start-1)) or 0
      local line = vim.api.nvim_buf_get_lines(0, s0, s0+1, false)[1] or ''
      local fences = get_fences()
      local candidates = { fences.start_text }
      if fences.start_text ~= 'mtoc-start' then table.insert(candidates, 'mtoc-start') end
      local found = nil
      local used_tag = nil
      for _, tag in ipairs(candidates) do
        local pat = '^%s*<!%-%-%s*'..tag..'%s*:%s*([^>]+)%-%-%>%s*$'
        local pat = '<!%-%-%s*' .. tag:gsub('%-', '%%-') .. ':([%w%-_]*)%s*%-%->'
        local f = line:match(pat)
        if f then
          f = f:gsub('%s+$', ''):gsub('^%s+', '')
          found = f
          used_tag = tag
          break
        end
      end
      dbg(string.format('update_all: start line [%d]: "%s"', s0, line))
      dbg(string.format('update_all: label re-extract found=%s (tag=%s)', tostring(found), tostring(used_tag)))
      if found and found ~= '' then
        item.label = found
        dbg('update_all: using label '..item.label..' for regeneration')
      else
        dbg('update_all: no label found on start line; will regenerate full ToC')
      end
    end
    local toc_lines
    local label_to_use = item.label
    local relabel = false
    if item.label and item.label ~= '' then
      dbg('auto_update: regenerating partial ToC for label='..item.label)
      toc_lines = toc.gen_toc_list_for_label(item.label)
      if utils.empty_or_nil(toc_lines) then
        -- Likely the parent heading was renamed. Recompute by section range
        local s0 = item.start0 or (item.start and (item.start-1)) or 0
        local cur_line = s0 + 1 -- 1-based for range finder
        local s_range, e_range = toc.find_current_section_range(cur_line)
        dbg(string.format('auto_update: label produced empty TOC; recomputing by range [%d,%d)', s_range, e_range))
        toc_lines = toc.gen_toc_list_for_range(s_range, e_range)
        -- Relabel fence with a stable short hash derived from current section heading
        local heading_line = vim.api.nvim_buf_get_lines(0, s_range, s_range+1, false)[1] or ''
        local _, heading_name = string.match(heading_line, config.opts.headings.pattern)
        heading_name = heading_name or heading_line
        local new_hash
        local ok, dig = pcall(vim.fn.sha256, heading_name)
        if ok and type(dig) == 'string' then
          new_hash = string.sub(dig, 1, 7)
        else
          -- fallback simple hash
          local sum = 0
          for i = 1, #heading_name do sum = (sum * 33 + string.byte(heading_name, i)) % 0xFFFFFFFF end
          new_hash = string.format('%07x', sum)
        end
        label_to_use = new_hash
        relabel = true
        dbg('auto_update: relabeling partial fence to frozen label '..label_to_use)
      end
    else
      dbg('auto_update: regenerating full ToC')
      toc_lines = toc.gen_toc_list(0)
    end
    toc_lines = config.opts.toc_list.post_processor(toc_lines)
    local new_block = {}
    table.insert(new_block, fmt_fence_start(fences.start_text, label_to_use))
    if not (toc_lines[1] == '' or #toc_lines == 0) then table.insert(new_block, '') end
    for _, l in ipairs(toc_lines) do table.insert(new_block, l) end
    if new_block[#new_block] ~= '' then table.insert(new_block, '') end
    table.insert(new_block, fmt_fence_end(fences.end_text, label_to_use))
    -- Replace the existing fenced block
    local s0 = item.start0 or (item.start and (item.start-1)) or 0
    local e0 = item.end0 or item.end_ or s0
    dbg(string.format('auto_update: replacing lines [%d,%d) with %d lines', s0, e0, #new_block))
    vim.api.nvim_buf_set_lines(0, s0, e0, true, new_block)
  end
end

-- Perform an auto-update with state preservation. Exposed for autocmd to call with command modifiers.
function M._auto_update()
  local aup = config.opts.auto_update or {}
  utils.with_preserved_state({
    suppress_pollution = aup.suppress_pollution,
  }, function()
    dbg('auto_update: fired')
    update_all_tocs()
  end)
end

local function handle_command(opts)
  local fnopts = { bang = opts.bang }
  if opts.range == 2 then
    fnopts.range_start = opts.line1
    fnopts.range_end = opts.line2
  end

  if empty_or_nil(opts.fargs) then
    return update_or_remove_toc(fnopts)
  end

  local cmd = opts.fargs[1]
  if cmd == 'debug' then
    return _debug_show_headings()
  end
  if cmd:sub(#cmd, #cmd) == '!' then
    fnopts.bang = true
    cmd = cmd:sub(1, #cmd-1)
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
    return insert_toc(fnopts)
  elseif cmd == "update" then
    return update_toc(fnopts, false)
  elseif cmd == "remove" then
    return remove_toc()
  elseif cmd == "update_all" then
    return update_all_tocs()
  else
    vim.notify("INTERNAL ERROR: Unhandled command "..cmd, vim.log.levels.ERROR)
  end
end


local function setup_commands()
  vim.api.nvim_create_user_command("Mtoc", handle_command, {
    nargs = '?',
    range = true,
    bang = true,
    complete = function()
      return M.commands
    end,
  })
end

local function setup_autocmds()
  M.autocmds = {}
  local aup = config.opts.auto_update
  if not aup then
    return
  end
  if type(aup) == 'boolean' then
    aup = config.defaults.auto_update
  end
  if not aup.enabled then
    return
  end
  local id = vim.api.nvim_create_autocmd(aup.events, {
    pattern = aup.pattern,
    callback = function()
      -- Use command modifiers to avoid changing jumplist and last-change mark
      local mods = { silent = true }
      if aup.suppress_pollution then
        mods.keepjumps = true
        mods.lockmarks = true
      end
      vim.api.nvim_cmd({
        cmd = 'lua',
        args = { 'require("mtoc")._auto_update()' },
        mods = mods,
      }, {})
     end,
   })
  table.insert(M.autocmds, id)
end

---Remove autocmds that were set up by this plugin
function M.remove_autocmds()
  if empty_or_nil(M.autocmds) then
    return
  end
  for _, id in ipairs(M.autocmds) do
    vim.api.nvim_del_autocmd(id)
  end
end

---Merge user opts with default opts and set up autocmds and commands
---@param opts mtoc.UserConfig
function M.setup(opts)
  vim.g.mtoc_loaded = 1
  config.merge_opts(opts)
  setup_autocmds()
  setup_commands()
end

---Merge user opts with default opts and reset autocmds based on new options
---@param opts mtoc.UserConfig
function M.update_config(opts)
  config.update_opts(opts)
  M.remove_autocmds()
  setup_autocmds()
end

return M
