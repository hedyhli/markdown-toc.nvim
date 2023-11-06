local M = {}

M.defaults = {
  headings = {
    -- TODO
    -- Headings to include
    -- top_level = false,
    -- before_toc = false,
    -- Supports regex
    filter_blacklist = {},
  },
  toc_list = {
    -- string or list of strings (latter only applicable for cycle = true)
    markers = '*',
    cycle_markers = false,
    -- Example for cycling markers:
    -- markers = {'*', '+', '-'},
    -- cycle_markers = true,
    -- Integer or function
    indent_size = 4,
  },
  -- table or boolean
  fences = {
    -- Needed for updating and removing TOC
    enabled = true,
    start_text = "mdtoc.nvim start",
    end_text = "mdtoc.nvim end"
  },
  auto_update = {
    enabled = true,
    events = { "BufWritePre" },
    pattern = "*.{md,mdown,mkd,mkdn,markdown,mdwn}",
  },
  -- TODO
  -- style = {
  --   formatters = {"gfm"},
  --   chooser = function() return "gfm" end
  -- },
}

M.opts = {}

function M.merge_opts(opts)
  vim.g.mdtoc_loaded = 1
  M.opts = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
end

function M.update_opts(opts)
  M.opts = vim.tbl_deep_extend('force', {}, M.opts, opts or {})
end

return M
