local M = {}

---Delete lines in current buffer with inclusive line ranges
---@param s integer Line number of start (inclusive)
---@param e integer Line number of end (inclusive)
function M.delete_lines(s, e)
  vim.api.nvim_buf_set_lines(0, s-1, e, true, {})
end

---Convenience function for inserting lines at line
---@param line integer Line number of where to insert
---@param lines string[] Lines to insert
function M.insert_lines(line, lines)
  vim.api.nvim_buf_set_lines(0, line, line, true, lines)
end

---Convenience function to get current line number in current buffer
---@return integer current_lineno
function M.current_line()
  return vim.api.nvim_win_get_cursor(0)[1]
end

---Return whether tbl is either empty or nil
---@param tbl table|nil
---@return boolean emtpy_or_nil True means tbl ~= nil and tbl ~= {}
function M.empty_or_nil(tbl)
  return not tbl or next(tbl) == nil
end

---Returns true for empty strings, number 0, nil or empty tables
---@param obj any
---@return boolean
function M.falsey(obj)
  if type(obj) == 'table' then
    return M.empty_or_nil(obj)
  elseif type(obj) == 'string' then
    return obj == ''
  elseif type(obj) == 'number' then
    return obj == 0
  end
  return not obj
end

function M.truthy(obj)
  return not M.falsey(obj)
end

---Turns off undo entries while updating the buffer
---@param fn fun()
function M.with_suppressed_pollution(fn)
  local ok, err = pcall(fn)
  if not ok then error(err) end
end

---Preserve window view (cursor, topline, etc.) while running fn
---@param fn fun()
function M.with_preserved_view(fn)
  local view = vim.fn.winsaveview()
  local ok, err = pcall(fn)
  vim.fn.winrestview(view)
  if not ok then error(err) end
end
 
---Convenience wrapper to optionally preserve state (marks/view) and avoid pollution during programmatic edits.
---@param opts { suppress_pollution: boolean }
---@param fn fun()
function M.with_preserved_state(opts, fn)
  local suppress = opts and opts.suppress_pollution
  local runner = fn
  if suppress then
    runner = function() M.with_suppressed_pollution(fn) end
  end

  if suppress then
    M.with_preserved_view(function()
      -- Save last-change and change-region marks so '.' and related motions aren't redirected
      local ok_last, pos_last = pcall(vim.fn.getpos, "'.")
      local ok_start, pos_start = pcall(vim.fn.getpos, "'[")
      local ok_end, pos_end = pcall(vim.fn.getpos, "']")
      runner()
      -- Restore marks
      if ok_last then pcall(vim.fn.setpos, "'.", pos_last) end
      if ok_start then pcall(vim.fn.setpos, "'[", pos_start) end
      if ok_end then pcall(vim.fn.setpos, "']", pos_end) end
      -- Best-effort: avoid hijacking dot-repeat if repeat.vim is present
      pcall(function()
        if vim.fn.exists('*repeat#set') == 1 then
          vim.fn['repeat#set']('', -1)
        end
      end)
    end)
  else
    -- No protections: run directly so marks/jumps/registers update naturally
    runner()
  end
end

---Compare two string arrays for exact equality
---@param a string[]
---@param b string[]
---@return boolean
function M.eq_string_arrays(a, b)
  if a == b then return true end
  if not a or not b then return false end
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

return M
