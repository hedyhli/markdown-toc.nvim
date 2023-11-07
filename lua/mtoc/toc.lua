local config = require('mtoc/config')
local utils = require('mtoc/utils')

local empty_or_nil = utils.empty_or_nil
-- local falsey = utils.falsey
-- local truthy = utils.truthy

local M = {}
M.link_formatters = {}


---Link formatter based on GitHub Flavoured Markdown
---@param existing_headings table
---@param heading string
function M.link_formatters.gfm(existing_headings, heading)
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

---Return a list of lines of TOC list given a list of heading trees
---@param headings table
---@return table lines
function M.gen_toc_list(headings)
  local toc_config = config.opts.toc_list
  local markers = toc_config.markers
  if type(markers) == 'string' then
    markers = { markers }
  end
  if not toc_config.cycle_markers then
    markers = { markers[1] }
  end
  local indent_size = toc_config.indent_size
  if type(indent_size) == 'function' then
    indent_size = indent_size()
  end
  local item_formatter = toc_config.item_formatter
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
    local fmt_info = {
      name = heading.name,
      link = heading.link,
      indent = (" "):rep(indent),
      marker = marker,
      num_children = #heading.children,
      line = heading.range.start,
      ['end'] = heading.range['end'],
    }
    local line = item_formatter(fmt_info, toc_config.item_format_string)
    table.insert(lines, line)

    if not empty_or_nil(heading.children) then
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

---@see find_fences
local function _find_fences(fstart, fend, lines)
  local locations = {}
  local in_code = false
  for i, line in ipairs(lines) do
    if locations.start and locations.end_ then
      break
    end

    if string.find(line, '^```') then
      in_code = not in_code
    else
      if not in_code then
        if string.find(line, fstart, 1, true) then
          locations.start = i
        end
        if string.find(line, fend, 1, true) then
          locations.end_ = i
        end
      end
    end
  end
  return locations
end

---@see find_fences
local function _find_fences_same(fence, lines)
  local in_code = false
  local locations = {}
  for i, line in ipairs(lines) do
    if string.find(line, '^```') then
      in_code = not in_code
    else
      if not in_code then
        if string.find(line, fence, 1, true) then
          if locations.start then
            locations.end_ = i
            break
          else
            locations.start = i
          end
        end
      end
    end
  end
  return locations
end

---Return a table containing line number of start and end fences
---@param fstart string
---@param fend string
---@return table locations { start = line, end_ = line }
function M.find_fences(fstart, fend)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if fstart ~= fend then
    return _find_fences(fstart, fend, lines)
  end
  return _find_fences_same(fstart, lines)
end

return M
