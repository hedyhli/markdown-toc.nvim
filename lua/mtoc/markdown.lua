local toc = require('mtoc/toc')
local config = require('mtoc/config')

local M = {}

---@return table
function M.get_headings(start_from)
  start_from = start_from or 0
  local lines = vim.api.nvim_buf_get_lines(0, start_from, -1, false)
  local level_symbols = { { children = {} } }
  local max_level = 1
  local is_inside_code_block = false
  local all_heading_links = {}
  ---@type function|table
  local exclude_conf = config.opts.headings.exclude or {}
  local exclude_fn = exclude_conf

  if type(exclude_conf) ~= 'function' then
    exclude_fn = function(title)
      for _, filter in ipairs(exclude_conf) do
        if title:match(filter) then
          return true
        end
      end
      return false
    end
  end

  for line, value in ipairs(lines) do
    if string.find(value, '^```') then
      is_inside_code_block = not is_inside_code_block
    end
    if is_inside_code_block then
      goto nextline
    end

    local next_value = lines[line+1]
    local is_emtpy_line = #value:gsub("^%s*(.-)%s*$", "%1") == 0

    -- There must a space after '#', and must be content after '# '
    local header, title = string.match(value, '^(#+)%s+(.+)$')
    if not header and next_value and not is_emtpy_line then
      -- Setext headings
      if string.match(next_value, '^=+%s*$') then
        header = '#'
        title = value
      elseif string.match(next_value, '^-+%s*$') then
        header = '##'
        title = value
      end
    end

    if not header or not title then
      goto nextline
    end

    title = title:gsub("^%s+", ""):gsub("%s+$", "")

    if exclude_fn(title) then
      goto nextline
    end

    local depth = #header + 1
    local parent
    for i = depth - 1, 1, -1 do
      if level_symbols[i] ~= nil then
        parent = level_symbols[i].children
        break
      end
    end

    for i = depth, max_level do
      if level_symbols[i] ~= nil then
        level_symbols[i].selectionRange['end'].line = line - 1
        level_symbols[i].range['end'].line = line - 1
        level_symbols[i] = nil
      end
    end
    max_level = depth

    local heading_link
    heading_link = toc.link_formatters.gfm(all_heading_links, title)

    local entry = {
      name = title,
      link = heading_link,
      selectionRange = {
        start = { line = line - 1 },
        ['end'] = { line = line - 1 },
      },
      range = {
        start = { line = line },
        ['end'] = { line = line - 1 },
      },
      children = {},
    }

    parent[#parent + 1] = entry
    level_symbols[depth] = entry
    ::nextline::
  end

  for i = 2, max_level do
    if level_symbols[i] ~= nil then
      level_symbols[i].selectionRange['end'].line = #lines
      level_symbols[i].range['end'].line = #lines
    end
  end

  return level_symbols[1].children
end

return M
