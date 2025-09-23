local config = require('mtoc/config')
-- Define module table early so functions can reference it
local M = {}
-- Forward declarations for TS helpers so earlier functions can reference them
local ts_available, ts_heading_info, ts_collect_headings
local function dbg(msg)
  if config and config.opts and config.opts.debug then
    vim.notify('[mtoc] '..msg, vim.log.levels.INFO)
  end
end
local ts_ok, ts = pcall(require, 'vim.treesitter')
local tsq
local tsq_html
if ts_ok then
  local okq, q = pcall(function()
    return vim.treesitter.query.parse('markdown', [[
      (atx_heading) @h
      (setext_heading) @h
    ]])
  end)
  if okq then tsq = q end
  local okq2, q2 = pcall(function()
    return vim.treesitter.query.parse('markdown', [[
      (html_block) @c
    ]])
  end)
  if okq2 then tsq_html = q2 end
end
---Generate a partial ToC for the section identified by its slug label.
---@param label string
---@return string[]
function M.gen_toc_list_for_label(label)
  if not label or label == '' then return {} end
  local toc_config = config.opts.toc_list
  local markers = toc_config.markers
  if toc_config.numbered then markers = { '1.' } end
  local marker_index = 1
  if not toc_config.cycle_markers then markers = { markers[1] } end
  local indent_size = toc_config.indent_size
  if type(indent_size) == 'function' then indent_size = indent_size() end
  if toc_config.numbered and (not indent_size or indent_size < 3) then indent_size = 3 end
  local item_formatter = toc_config.item_formatter

  local headings = {}
  local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
  local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_ok and tsq ~= nil)
  if use_ts then
    headings = ts_collect_headings(0, -1)
  else
    -- Regex fallback
    local is_inside_code_block = false
    for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if line:find('^```') then is_inside_code_block = not is_inside_code_block end
      if not is_inside_code_block then
        local pfx, nm = line:match(config.opts.headings.pattern)
        if pfx and nm and #pfx <= 6 then table.insert(headings, { depth = #pfx, name = nm, row = row-1 }) end
      end
    end
  end

  -- Find heading whose slug matches label, using the same slugification as ToC
  local existing = {}
  local target_idx = nil
  for i, h in ipairs(headings) do
    local slug = M.link_formatters.gfm(existing, h.name)
    if slug == label then target_idx = i; break end
  end
  if not target_idx then return {} end

  local base_depth = headings[target_idx].depth
  -- Determine end row (exclusive) as next heading with depth <= base
  local end_row = vim.api.nvim_buf_line_count(0)
  for j = target_idx+1, #headings do
    if headings[j].depth <= base_depth then
      end_row = headings[j].row
      break
    end
  end

  -- Build ToC from headings strictly after the base heading within the section
  local min_depth_cfg = config.opts.headings.min_depth
  local max_depth_cfg = config.opts.headings.max_depth
  local prev_clamped_depth = base_depth
  local lines = {}
  local all_heading_links = {}
  for k = target_idx+1, #headings do
    local h = headings[k]
    if h.row >= end_row then break end
    local raw_depth = h.depth
    if not ((min_depth_cfg and raw_depth < min_depth_cfg) or (max_depth_cfg and raw_depth > max_depth_cfg)) then
      local clamped = raw_depth
      if prev_clamped_depth + 1 < raw_depth then clamped = prev_clamped_depth + 1 end
      prev_clamped_depth = clamped
      marker_index = (marker_index - 1) % #markers + 1
      local marker = markers[marker_index]
      local name = h.name:gsub('%[(.-)%]%(.-%)', '%1')
      local depth = clamped - base_depth
      local link = M.link_formatters.gfm(all_heading_links, name)
      local fmt_info = { name = name, link = link, depth = depth, marker = marker, raw_line = '' }
      fmt_info.indent = (" "):rep(depth * indent_size)
      local item = item_formatter(fmt_info, toc_config.item_format_string)
      table.insert(lines, item)
    end
  end
  return lines
end

---Find all fenced ToCs in current buffer, returning a list of locations
---with optional labels: { { start = s, end_ = e, label = 'slug'|nil }, ... }
---@return table[]
function M.find_all_fences()
  local fences = config.opts.fences
  if type(fences) == 'boolean' and fences then
    fences = config.defaults.fences
  end
  local start_text = fences.start_text
  local end_text = fences.end_text
  local start_tags = { start_text }
  local end_tags = { end_text }
  -- Also recognize built-in default markers regardless of config
  if start_text ~= 'mtoc-start' then table.insert(start_tags, 'mtoc-start') end
  if end_text ~= 'mtoc-end' then table.insert(end_tags, 'mtoc-end') end
  dbg(string.format('find_all_fences: using fence texts start="%s" end="%s"; also recognizing built-in mtoc-start/end', tostring(start_text), tostring(end_text)))

  local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
  local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_ok and tsq_html ~= nil)

  -- Prefer Tree-sitter: scan html_block nodes and pair mtoc-start/mtoc-end
  if use_ts then
    local res = {}
    local parser = ts.get_parser(0, 'markdown')
    local tree = (parser:parse() or {})[1]
    if not tree then dbg('TS: no tree'); return res end
    local root = tree:root()
    local blocks = {}
    local line_count = vim.api.nvim_buf_line_count(0)
    if not tsq_html then dbg('TS: tsq_html is nil'); return res end
    local block_count = 0
    for _, node in tsq_html:iter_captures(root, 0, 0, line_count) do
      local srow, _, erow, _ = node:range()
      local text = table.concat(vim.api.nvim_buf_get_lines(0, srow, erow, false), '\n')
      table.insert(blocks, { srow = srow, erow = erow, text = text })
      block_count = block_count + 1
    end
    dbg('TS: html_block nodes scanned: '..tostring(block_count))
    if block_count > 0 then
      local preview = {}
      for idx = 1, math.min(3, #blocks) do
        local t = blocks[idx].text:gsub('\n', '\\n')
        t = #t > 120 and (t:sub(1, 120)..'…') or t
        table.insert(preview, string.format('#%d [%d,%d): %s', idx, blocks[idx].srow, blocks[idx].erow, t))
      end
      dbg('TS: html_block previews: '..table.concat(preview, ' | '))
    end
    table.sort(blocks, function(a,b) return a.srow < b.srow end)
    local i = 1
    local function ts_match_start(txt)
      for _, tag in ipairs(start_tags) do
        -- Fast plain check first
        if txt:find('<!-- '..tag, 1, true) then
          -- Try to extract label; if none, it's unlabeled
          local lbl = txt:match('<!%-%-%s*'..tag..'%s*:%s*(.-)%s*%-%->')
          if lbl then
            lbl = lbl:gsub('%s+$', ''):gsub('^%s+', '')
          end
          return lbl, tag
        end
      end
      return nil, nil
    end
    local function ts_match_end(txt, label, tag)
      local endtag = (tag == 'mtoc-start') and 'mtoc-end' or tag
      if label then
        return txt:match('<!%-%-%s*'..endtag..'%s*:%s*'..label..'%s*%-%->') ~= nil
      end
      return txt:find('<!-- '..endtag, 1, true) ~= nil
    end
    while i <= #blocks do
      local b = blocks[i]
      local start_label, start_tag = ts_match_start(b.text)
      if start_tag ~= nil then
        local label = start_label
        dbg(string.format('TS: start matched at row %d (label=%s, tag=%s)', b.srow, tostring(label), tostring(start_tag)))
        -- find matching end block
        local j = i + 1
        while j <= #blocks do
          local be = blocks[j]
          local matched = ts_match_end(be.text, label, (start_tag == 'mtoc-start' and 'mtoc-end') or end_text)
          dbg(string.format('TS: checking end at row %d label=%s tag=%s matched=%s', be.srow, tostring(label), tostring((start_tag == 'mtoc-start' and 'mtoc-end') or end_text), tostring(matched)))
          if matched then
            -- Return 0-based start and 0-based exclusive end rows
            table.insert(res, { start0 = b.srow, end0 = be.erow, label = label })
            i = j
            break
          end
          j = j + 1
        end
      end
      i = i + 1
    end
    dbg('TS fences found: '..tostring(#res))
    if #res > 0 then
      return res
    end
  end

  -- Fallback: regex scanner over lines
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local res = {}
  local in_code = false
  local i = 1
  local function rx_match_start(str)
    for _, tag in ipairs(start_tags) do
      local start_label = str:match('^%s*<!%-%-%s*'..tag..'%s*:%s*(.-)%s*%-%->%s*$')
      local is_start_plain = str:match('^%s*<!%-%-%s*'..tag..'%s*%-%->%s*$') ~= nil
      if start_label then return start_label, tag end
      if is_start_plain then return nil, tag end
    end
    return nil, nil
  end
  local function rx_end_pat(label, tag)
    local t = (tag == 'mtoc-start') and 'mtoc-end' or end_text
    return '^%s*<!%-%-%s*'..t..(label and (':%s*'..label) or '')..'%s*%-%->%s*$'
  end
  while i <= #lines do
    local line = lines[i]
    if line:find('^```') then
      in_code = not in_code
    elseif not in_code then
      local s_label, s_tag = rx_match_start(line)
      if s_tag ~= nil then
        local label = s_label
        dbg(string.format('Regex: start matched at line %d (label=%s tag=%s)', i, tostring(label), tostring(s_tag)))
        -- find matching end
        local j = i + 1
        local end_pat = rx_end_pat(label, s_tag)
        while j <= #lines do
          local l2 = lines[j]
          if l2:find('^```') then
            in_code = not in_code
          elseif not in_code then
            local em = l2:match(end_pat)
            if em then
              dbg(string.format('Regex: end matched at line %d (label=%s tag=%s)', j, tostring(label), tostring(s_tag)))
              -- Convert 1-based inclusive to 0-based [start0, end0_excl]
              table.insert(res, { start0 = i-1, end0 = j, label = label })
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
  dbg('Regex fences found: '..tostring(#res))
  if #res > 0 then return res end

  -- Ultimate fallback: scan entire buffer text with very permissive patterns
  -- to ensure we detect fences regardless of whitespace peculiarities.
  local buf_text = table.concat(lines, '\n')
  local starts = {}
  local ends = {}
  local function gf_collect(text, tag, into, labeled)
    if labeled then
      for s, e, lab in text:gmatch('()<!%-%-%s*'..tag..':%s*(.-)%s*%-%->') do
        table.insert(into, { pos = s, label = lab, tag = tag })
      end
    else
      for s, e in text:gmatch('()<!%-%-%s*'..tag..'%s*%-%->') do
        table.insert(into, { pos = s, label = nil, tag = tag })
      end
    end
  end
  for _, tag in ipairs(start_tags) do
    gf_collect(buf_text, tag, starts, true)
    gf_collect(buf_text, tag, starts, false)
  end
  for _, tag in ipairs(end_tags) do
    gf_collect(buf_text, tag, ends, true)
    gf_collect(buf_text, tag, ends, false)
  end
  table.sort(starts, function(a,b) return a.pos < b.pos end)
  table.sort(ends, function(a,b) return a.pos < b.pos end)
  local function pos_to_row(pos)
    -- Count newlines before byte position to get 0-based row
    local sub = buf_text:sub(1, math.max(pos-1, 0))
    local _, cnt = sub:gsub('\n', '')
    return cnt
  end
  local j = 1
  for i = 1, #starts do
    local st = starts[i]
    while j <= #ends and ends[j].pos < st.pos do j = j + 1 end
    local k = j
    while k <= #ends do
      local en = ends[k]
      local expected_end_tag = (st.tag == 'mtoc-start') and 'mtoc-end' or end_text
      if st.label == en.label and en.tag == expected_end_tag then
        local s0 = pos_to_row(st.pos)
        local e0 = pos_to_row(en.pos)
        table.insert(res, { start0 = s0, end0 = e0, label = st.label })
        j = k + 1
        break
      end
      k = k + 1
    end
  end
  dbg('Ultimate fallback fences found: '..tostring(#res))
  return res
end
 

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

---Find fences with optional label suffix. If label is provided, looks for
---"<!-- <text>:<label> -->"; otherwise looks for "<!-- <text> -->".
---@param fstart_base string
---@param fend_base string
---@param label string|nil
---@return table locations `{ start = start_lineno, end_ = end_lineno }`
function M.find_fences_labeled(fstart_base, fend_base, label)
  local start_pat = label and ('<!-- '..fstart_base..':'..label..' -->') or ('<!-- '..fstart_base..' -->')
  local end_pat   = label and ('<!-- '..fend_base..':'..label..' -->')   or ('<!-- '..fend_base..' -->')
  return M.find_fences(start_pat, end_pat)
end

-- Tree-sitter integration -----------------------------------------------------

-- Return whether Tree-sitter headings query is available
function ts_available()
  return ts_ok and tsq ~= nil
end

-- Compute heading info (depth and title) from a TS heading node
--@param node TSNode
--@return integer depth, string title, integer srow, integer erow
function ts_heading_info(node)
  local srow, _, erow, _ = node:range() -- rows are 0-based; erow may be next row for setext
  if node:type() == 'atx_heading' then
    local line = vim.api.nvim_buf_get_lines(0, srow, srow+1, false)[1] or ''
    local hashes, name = line:match('^(#+)%s*(.-)%s*#*%s*$')
    local depth = hashes and #hashes or 1
    name = name or line
    return depth, name, srow, srow+1
  elseif node:type() == 'setext_heading' then
    local title_line = vim.api.nvim_buf_get_lines(0, srow, srow+1, false)[1] or ''
    local underline = vim.api.nvim_buf_get_lines(0, erow-1, erow, false)[1] or ''
    local depth = underline:find('^=+') and 1 or 2
    local name = title_line:gsub('%s+$', '')
    return depth, name, srow, erow
  end
  return 1, '', srow, erow
end

-- Collect headings via Tree-sitter within [start_idx, end_idx) 0-based rows
--@param start_idx integer
--@param end_idx integer -- -1 means end of buffer
--@return table[] headings { depth, name, row }
function ts_collect_headings(start_idx, end_idx)
  if not ts_available() then return {} end
  local parser = ts.get_parser(0, 'markdown')
  local tree = (parser:parse() or {})[1]
  if not tree then return {} end
  local root = tree:root()
  local res = {}
  local smin = start_idx
  local emax = end_idx == -1 and vim.api.nvim_buf_line_count(0) or end_idx
  for id, node in tsq:iter_captures(root, 0, smin, emax) do
    if tsq.captures[id] == 'h' then
      local depth, title, srow = ts_heading_info(node)
      table.insert(res, { depth = depth, name = title, row = srow })
    end
  end
  table.sort(res, function(a, b) return a.row < b.row end)
  return res
end

-- (Removed duplicate TS helper block)

---Returns a list of strings representing the lines of the ToC list.
---Calls both link formatter and item formatter based on config.
---@param start_from integer|nil The line number before which, headings will be ignored
---@return string[] lines List of lines to be inserted as ToC
function M.gen_toc_list(start_from)
  start_from = start_from or 0
  local toc_config = config.opts.toc_list

  ---@type string|string[]
  local markers = toc_config.markers
  if toc_config.numbered then
    markers = { '1.' }
  end
  local marker_index = 1
  if not toc_config.cycle_markers then
    markers = { markers[1] }
  end

  local indent_size = toc_config.indent_size
  if type(indent_size) == 'function' then
    indent_size = indent_size()
  end
  if toc_config.numbered and (not indent_size or indent_size < 3) then
    indent_size = 3
  end

  local item_formatter = toc_config.item_formatter

  -- Normalize depths and apply min/max filters
  local base_depth = nil
  local prev_clamped_depth = nil
  local lines = {}
  local all_heading_links = {}
  local headings = {}
  local min_depth_cfg = config.opts.headings.min_depth
  local max_depth_cfg = config.opts.headings.max_depth

  -- Prefer Tree-sitter for collecting headings; fallback to regex scanning,
  -- or force based on headings.parser option
  local collected
  local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
  local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_available())
  if use_ts then
    collected = ts_collect_headings(start_from, -1)
  else
    local is_inside_code_block = false
    collected = {}
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, start_from, -1, false)) do
      if string.find(line, '^```') then
        is_inside_code_block = not is_inside_code_block
      end
      if not is_inside_code_block then
        local prefix, name = string.match(line, config.opts.headings.pattern)
        if prefix and name and #prefix <= 6 then
          table.insert(collected, { depth = #prefix, name = name })
        end
      end
    end
  end

  for _, item in ipairs(collected) do
    local raw_depth = item.depth
    local name = item.name
    -- Apply optional min/max depth filters on raw heading level (H1=1..H6=6)
    if not ((min_depth_cfg and raw_depth < min_depth_cfg) or (max_depth_cfg and raw_depth > max_depth_cfg)) then
      -- Establish base depth from the first included heading
      if not base_depth then
        base_depth = raw_depth
        prev_clamped_depth = raw_depth
      end

      -- Clamp jumps to at most +1 from previous clamped depth
      local clamped_depth = raw_depth
      if prev_clamped_depth and prev_clamped_depth + 1 < raw_depth then
        clamped_depth = prev_clamped_depth + 1
      end
      prev_clamped_depth = clamped_depth

      marker_index = (marker_index - 1) % #markers + 1
      local marker = markers[marker_index]
      -- Strip embedded links in TOC: both in name and link.
      name = name:gsub('%[(.-)%]%(.-%)', '%1')
      -- Normalize depth relative to base_depth so the first heading is at indent 0
      local depth = clamped_depth - base_depth

      local link = M.link_formatters.gfm(all_heading_links, name)
      local fmt_info = {
        name = name,
        link = link,
        depth = depth,
        marker = marker,
        raw_line = '',
      }

      table.insert(headings, fmt_info)
    end
  end

  for _, fmt_info in ipairs(headings) do
    -- Depth is already normalized so lowest depth is 0
    local depth = fmt_info.depth
    fmt_info.indent = (" "):rep(depth * indent_size)
    local item = item_formatter(fmt_info, toc_config.item_format_string)
    table.insert(lines, item)
  end

  return lines
end

---Compute the [start, end) range (0-based, end-exclusive) for the section under cursor.
---@param cursor_lnum integer 1-based cursor line
---@return integer, integer start_idx_0, end_idx_0_excl
function M.find_current_section_range(cursor_lnum)
  local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
  local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_ok and tsq ~= nil)
  if use_ts then
    -- Tree-sitter path: find previous heading and next heading with depth <= current
    local hs = ts_collect_headings(0, -1)
    if #hs == 0 then return 0, vim.api.nvim_buf_line_count(0) end
    local cur0 = cursor_lnum - 1
    local idx = nil
    for i = #hs, 1, -1 do
      if hs[i].row <= cur0 then idx = i; break end
    end
    if not idx then return 0, vim.api.nvim_buf_line_count(0) end
    local cur_depth = hs[idx].depth
    local start_idx = hs[idx].row
    local end_row = vim.api.nvim_buf_line_count(0)
    for j = idx+1, #hs do
      if hs[j].depth <= cur_depth then
        end_row = hs[j].row
        break
      end
    end
    return start_idx, end_row
  end

  -- Regex fallback
  local buflines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local pattern = config.opts.headings.pattern
  local cur = math.max(cursor_lnum, 1)
  local start_idx = 0
  local cur_depth = nil

  for i = cur, 1, -1 do
    local line = buflines[i]
    if not line then goto continue end
    local prefix = line:match(pattern)
    if prefix then
      start_idx = i - 1
      cur_depth = #prefix
      break
    end
    ::continue::
  end
  if not cur_depth then
    return 0, #buflines
  end
  local end_idx = #buflines
  for i = start_idx + 2, #buflines do
    local line = buflines[i]
    if not line then goto continue2 end
    local prefix = line:match(pattern)
    if prefix then
      local depth = #prefix
      if depth <= cur_depth then
        end_idx = i - 1
        break
      end
    end
    ::continue2::
  end
  return start_idx, end_idx
end

---Compute a slug for the current section heading (used to label partial ToC fences)
---@return string|nil slug
function M.current_section_slug()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local s, _ = M.find_current_section_range(cur)
  -- Try Tree-sitter to get the exact node title
  local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
  local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_ok and tsq ~= nil)
  local title
  if use_ts then
    local hs = ts_collect_headings(s, s+1)
    if #hs > 0 then
      title = hs[1].name
    end
  end
  if not title then
    -- Regex fallback: read the line at s
    local line = vim.api.nvim_buf_get_lines(0, s, s+1, false)[1]
    if not line then return nil end
    local _, name = string.match(line, config.opts.headings.pattern)
    title = name
  end
  if not title or title == '' then return nil end
  local map = {}
  return M.link_formatters.gfm(map, title)
end

---Generate a ToC list scoped to the current section if configured, else full buffer.
---@return string[]
function M.gen_toc_list_scoped()
  local hcfg = config.opts.headings
  if hcfg.min_depth ~= nil or hcfg.partial_under_cursor then
    local cur = vim.api.nvim_win_get_cursor(0)[1]
    local s, e = M.find_current_section_range(cur)

    local toc_config = config.opts.toc_list
    local markers = toc_config.markers
    if toc_config.numbered then
      markers = { '1.' }
    end
    local marker_index = 1
    if not toc_config.cycle_markers then
      markers = { markers[1] }
    end
    local indent_size = toc_config.indent_size
    if type(indent_size) == 'function' then indent_size = indent_size() end
    if toc_config.numbered and (not indent_size or indent_size < 3) then indent_size = 3 end
    local item_formatter = toc_config.item_formatter

    local lines = {}
    local base_depth
    local prev_clamped_depth
    local all_heading_links = {}
    local min_depth_cfg = hcfg.min_depth
    local max_depth_cfg = hcfg.max_depth
    local headings = {}

    local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
    local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_available())
    local collected = use_ts and ts_collect_headings(s, e) or {}
    if not use_ts then
      local is_inside_code_block = false
      for _, line in ipairs(vim.api.nvim_buf_get_lines(0, s, e, false)) do
        if line:find('^```') then is_inside_code_block = not is_inside_code_block end
        if not is_inside_code_block then
          local pfx, nm = line:match(config.opts.headings.pattern)
          if pfx and nm and #pfx <= 6 then table.insert(collected, { depth = #pfx, name = nm }) end
        end
      end
    end

    -- Decide whether to skip the base heading itself: only skip when the
    -- section range starts exactly at a heading line. If ToC is placed before
    -- the first heading, include the first heading (skip_base = false).
    local parser_choice2 = (config.opts.headings and config.opts.headings.parser) or 'auto'
    local use_ts2 = (parser_choice2 == 'treesitter') or (parser_choice2 == 'auto' and ts_ok and tsq ~= nil)
    local skip_base = false
    if use_ts2 then
      local base_check = ts_collect_headings(s, s+1)
      skip_base = #base_check > 0
    else
      local line_s = vim.api.nvim_buf_get_lines(0, s, s+1, false)[1] or ''
      local pfx = line_s:match(config.opts.headings.pattern)
      skip_base = pfx ~= nil
    end
    for _, item in ipairs(collected) do
      local raw_depth = item.depth
      local name = item.name
      if not ((min_depth_cfg and raw_depth < min_depth_cfg) or (max_depth_cfg and raw_depth > max_depth_cfg)) then
        if not base_depth then
          base_depth = raw_depth
          prev_clamped_depth = raw_depth
          if skip_base then goto continue end
        end
        local clamped = raw_depth
        if prev_clamped_depth and prev_clamped_depth + 1 < raw_depth then
          clamped = prev_clamped_depth + 1
        end
        prev_clamped_depth = clamped
        marker_index = (marker_index - 1) % #markers + 1
        local marker = markers[marker_index]
        name = name:gsub('%[(.-)%]%(.-%)', '%1')
        local depth = clamped - base_depth
        local link = M.link_formatters.gfm(all_heading_links, name)
        local fmt_info = { name = name, link = link, depth = depth, marker = marker, raw_line = '' }
        table.insert(headings, fmt_info)
      end
      ::continue::
    end

    for _, fmt_info in ipairs(headings) do
      local depth = fmt_info.depth
      fmt_info.indent = (' '):rep(depth * indent_size)
      local item = item_formatter(fmt_info, toc_config.item_format_string)
      table.insert(lines, item)
    end
    return lines
  end
  return M.gen_toc_list(0)
end

---Generate a ToC list for an explicit section range [s,e) (0-based rows, end-exclusive).
---Skips the base heading itself when the range starts exactly at a heading line.
---@param s integer
---@param e integer
---@return string[]
function M.gen_toc_list_for_range(s, e)
  local toc_config = config.opts.toc_list
  local markers = toc_config.markers
  if toc_config.numbered then markers = { '1.' } end
  local marker_index = 1
  if not toc_config.cycle_markers then markers = { markers[1] } end
  local indent_size = toc_config.indent_size
  if type(indent_size) == 'function' then indent_size = indent_size() end
  if toc_config.numbered and (not indent_size or indent_size < 3) then indent_size = 3 end
  local item_formatter = toc_config.item_formatter

  local lines = {}
  local base_depth
  local prev_clamped_depth
  local all_heading_links = {}
  local hcfg = config.opts.headings
  local min_depth_cfg = hcfg.min_depth
  local max_depth_cfg = hcfg.max_depth
  local headings = {}

  local parser_choice = (config.opts.headings and config.opts.headings.parser) or 'auto'
  local use_ts = (parser_choice == 'treesitter') or (parser_choice == 'auto' and ts_available())
  local collected = use_ts and ts_collect_headings(s, e) or {}
  if not use_ts then
    local is_inside_code_block = false
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, s, e, false)) do
      if line:find('^```') then is_inside_code_block = not is_inside_code_block end
      if not is_inside_code_block then
        local pfx, nm = line:match(config.opts.headings.pattern)
        if pfx and nm and #pfx <= 6 then table.insert(collected, { depth = #pfx, name = nm }) end
      end
    end
  end

  -- Determine whether to skip base heading itself
  local skip_base
  do
    local parser_choice2 = (config.opts.headings and config.opts.headings.parser) or 'auto'
    local use_ts2 = (parser_choice2 == 'treesitter') or (parser_choice2 == 'auto' and ts_ok and tsq ~= nil)
    if use_ts2 then
      local base_check = ts_collect_headings(s, s+1)
      skip_base = #base_check > 0
    else
      local line_s = vim.api.nvim_buf_get_lines(0, s, s+1, false)[1] or ''
      local pfx = line_s:match(config.opts.headings.pattern)
      skip_base = pfx ~= nil
    end
  end

  for _, item in ipairs(collected) do
    local raw_depth = item.depth
    local name = item.name
    if not ((min_depth_cfg and raw_depth < min_depth_cfg) or (max_depth_cfg and raw_depth > max_depth_cfg)) then
      if not base_depth then
        base_depth = raw_depth
        prev_clamped_depth = raw_depth
        if skip_base then goto continue end
      end
      local clamped = raw_depth
      if prev_clamped_depth and prev_clamped_depth + 1 < raw_depth then clamped = prev_clamped_depth + 1 end
      prev_clamped_depth = clamped
      marker_index = (marker_index - 1) % #markers + 1
      local marker = markers[marker_index]
      name = name:gsub('%[(.-)%]%(.-%)', '%1')
      local depth = clamped - base_depth
      local link = M.link_formatters.gfm(all_heading_links, name)
      local fmt_info = { name = name, link = link, depth = depth, marker = marker, raw_line = '' }
      fmt_info.indent = (" "):rep(depth * indent_size)
      table.insert(headings, fmt_info)
    end
    ::continue::
  end

  for _, fmt_info in ipairs(headings) do
    local depth = fmt_info.depth
    fmt_info.indent = (' '):rep(depth * indent_size)
    local item = item_formatter(fmt_info, toc_config.item_format_string)
    table.insert(lines, item)
  end
  return lines
end

return M
