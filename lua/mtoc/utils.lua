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

return M
