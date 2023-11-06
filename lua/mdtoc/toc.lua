local config = require('mdtoc/config')

local M = {}
M.formatters = {}


---@param existing_headings table
---@param heading string
function M.formatters.gfm(existing_headings, heading)
  heading = heading:lower()

  -- Strip leading and trailing underscores
  heading = heading:gsub("^_+", ""):gsub("_+$", "")

  -- Strip non-alphanumric non-latin-extended, and non-CJK characters.
  -- Lua doesn't handle unicode very well.
  heading = vim.fn.substitute(heading, [[[^[:alnum:]\u00C0-\u00FF\u0400-\u04ff\u4e00-\u9fbf\u3040-\u309F\u30A0-\u30FF\uAC00-\uD7AF _-]].."]", "", "g")

  -- Convert all spaces to dashes
  heading = heading:gsub(" ", "-")

  local key = heading
  local heading_str = heading

  if heading_str == "" then
    key = "<NULL>"
  end

  if existing_headings[key] ~= nil then
    existing_headings[key] = existing_headings[key] + 1
    heading_str = heading_str .. '-' .. existing_headings[key]
  else
    existing_headings[key] = 0
  end

  return heading_str
end


---@param headings table
---@return table lines
function M.gen_toc_list(headings)
  local markers = config.opts.toc_list.markers
  if type(markers) == 'string' then
    markers = { markers }
  end
  if not config.opts.toc_list.cycle_markers then
    markers = { markers[1] }
  end
  local indent_size = config.opts.toc_list.indent_size
  if type(indent_size) == 'function' then
    indent_size = indent_size()
  end
  local lines = {}

  ---@param heading table
  ---@param indent integer
  ---@param marker_index integer
  local function _gen_toc_list(heading, indent, marker_index)
    if not heading then
      return
    end

    marker_index = (marker_index - 1) % #markers + 1
    local marker = markers[marker_index]

    local line = string.format("%s%s [%s](#%s)" , string.rep(' ', indent), marker, heading.name, heading.link)
    table.insert(lines, line)

    if heading.children then
      indent = indent + indent_size
      marker_index = marker_index + 1

      for _, child in ipairs(heading.children) do
        _gen_toc_list(child, indent, marker_index)
      end
    end
  end

  for _, heading in ipairs(headings) do
    _gen_toc_list(heading, 0, 1)
  end

  return lines
end

function M.find_fences(fstart, fend)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local is_inside_code_block = false
  -- { start = line, end_ = line }
  local found_info = {}

  for i, line in ipairs(lines) do
    if found_info.start and found_info.end_ then
      break
    end

    if string.find(line, '^```') then
      is_inside_code_block = not is_inside_code_block
    else

      if not is_inside_code_block then
        if string.find(line, fstart, 1, true) then
          found_info.start = i
        end
        if string.find(line, fend, 1, true) then
          found_info.end_ = i
        end
      end

    end
  end

  return found_info
end

return M
