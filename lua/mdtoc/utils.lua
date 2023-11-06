local M = {}

---Delete lines in current buffer with inclusive line ranges
---@param s integer Line number of start (inclusive)
---@param e integer Line number of end (inclusive)
function M.delete_lines(s, e)
  vim.api.nvim_buf_set_lines(0, s-1, e, true, {})
end

return M
