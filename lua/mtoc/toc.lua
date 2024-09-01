local config = require('mtoc/config')

local M = {}
M.link_formatters = {}


---Link formatter based on GitHub Flavoured Markdown
---@param existing_headings { [string]: number }
---@param heading string
function M.link_formatters.gfm(existing_headings, heading)
  heading = vim.fn.tolower(heading)

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

---Find fences function for start and end fences being the same string
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

---Return a table containing line numbers of start and end fences
---@param fstart string   String of fence start
---@param fend string     String of fence end
---@return table locations `{ start = start_lineno, end_ = end_lineno }`
function M.find_fences(fstart, fend)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if fstart ~= fend then
    return _find_fences(fstart, fend, lines)
  end
  return _find_fences_same(fstart, lines)
end

---Returns a list of strings representing the lines of the ToC list.
---Calls both link formatter and item formatter based on config.
---@param start_from integer|nil The line number before which, headings will be ignored
---@return string[] lines List of lines to be inserted as ToC
function M.gen_toc_list(start_from)
  start_from = start_from or 0
  local toc_config = config.opts.toc_list

  ---@type string|string[]
  local markers = toc_config.markers
  local marker_index = 1
  if not toc_config.cycle_markers then
    markers = { markers[1] }
  end

  local indent_size = toc_config.indent_size
  if type(indent_size) == 'function' then
    indent_size = indent_size()
  end

  local item_formatter = toc_config.item_formatter

  local is_inside_code_block = false
  local prev_depth = 1
  local lines = {}
  local all_heading_links = {}

  local min_depth = math.huge
  local headings = {}

  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, start_from, -1, false)) do
    if string.find(line, '^```') then
      is_inside_code_block = not is_inside_code_block
    end
    if is_inside_code_block then
      goto nextline
    end

    local prefix, name = string.match(line, config.opts.headings.pattern)
    if not prefix or not name or #prefix > 6 then
      goto nextline
    end

    local depth = #prefix

    if prev_depth + 1 < depth then
      depth = prev_depth + 1
    end
    prev_depth = depth

    marker_index = (marker_index - 1) % #markers + 1
    local marker = markers[marker_index]

    -- Strip embedded links in TOC: both in name and link.
    name = name:gsub("%[(.-)%]%(.-%)", "%1")

    depth = depth - 1

    local link = M.link_formatters.gfm(all_heading_links, name)
    local fmt_info = {
      name = name,
      link = link,
      depth = depth,
      marker = marker,
      raw_line = line,
    }

    if depth < min_depth then
      min_depth = depth
    end
    table.insert(headings, fmt_info)
    ::nextline::
  end

  -- Write TOC
  for _, fmt_info in ipairs(headings) do
    -- Ensure lowest depth is 0
    local depth = fmt_info.depth - min_depth
    fmt_info.indent = (" "):rep(depth * indent_size)
    local item = item_formatter(fmt_info, toc_config.item_format_string)
    table.insert(lines, item)
  end

  return lines
end

return M
