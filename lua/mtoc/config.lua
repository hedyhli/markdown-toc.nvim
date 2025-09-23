local M = {}

---@type mtoc.Config
M.defaults = {
  -- Global debug flag: when true, plugin will log verbose diagnostics
  debug = false,
  -- Config relating to fetching of headings to be included in ToC
  headings = {
    -- Include headings before the ToC (or current line for `:Mtoc insert`)
    before_toc = false,
    -- Either list of lua patterns,
    -- or a function that returns boolean (true means to EXCLUDE heading)
    exclude = {},
    pattern = "^(#+)%s+(.+)$",
    -- Which parser to use for heading detection: 'auto' | 'treesitter' | 'regex'
    -- 'auto' prefers Tree-sitter when available, otherwise falls back to regex.
    parser = 'auto',
    -- Optional: limit which heading levels are included (1 = H1, 2 = H2, ...)
    -- Set to nil to disable the bound. Example: min_depth = 2, max_depth = 4
    min_depth = nil,
    max_depth = nil,
    -- When true, generate a partial ToC scoped to the current section (the heading
    -- enclosing the cursor) instead of the whole document.
    partial_under_cursor = false,
  },

  -- Config relating to the style and format of the ToC
  toc_list = {
    -- string or list of strings (for cycling)
    -- If cycle_markers = false and markers is a list, only the first is used.
    -- You can set to '1.' to use a automatically numbered list for ToC (if
    -- your markdown render supports it).
    markers = { '*' },
    cycle_markers = false,
    -- If true, use an auto-numbered markdown list (equivalent to markers = '1.',
    -- but checks for a suitable indent_size)
    numbered = false,
    -- Example config for cycling markers:
    ----- markers = {'*', '+', '-'},
    ----- cycle_markers = true,

    -- Integer or function that returns an integer.
    -- If function, it is called every time the ToC is regenerated. This allows the use
    -- of retrieving buffer-local settings like shiftwidth.
    indent_size = 2,

    -- Remove the ${indent} below, or set indent_size=0 to have the whole ToC
    -- be a flattened list.
    item_format_string = "${indent}${marker} [${name}](#${link})",

    ---Formatter for a single ToC list item.
    -- `item_info` has fields `name`, `link`, `marker`, `indent`, To change the
    -- format of each heading item but keep the same field substitution syntax,
    -- simply change `item_format_string`.
    ---@param item_info table Information for current heading item.
    ---@param fmtstr string from `item_format_string` config
    ---@return string formatted_item
    item_formatter = function(item_info, fmtstr)
      local s = fmtstr:gsub([[${(%w-)}]], function(key)
        return item_info[key] or ('${'..key..'}')
      end)
      return s
    end,

    -- Called after an array of lines for the ToC is computed. This does not
    -- include the fences even if it's enabled.
    post_processor = function(lines) return lines end
  },

  -- Table or boolean. Set to true to use these defaults, set to false to disable completely.
  -- Fences are needed for the update/remove commands.
  fences = {
    enabled = true,
    -- These fence texts are wrapped within "<!-- % -->", where the '%' is
    -- substituted with the text.
    start_text = "mtoc-start",
    end_text = "mtoc-end"
    -- An empty line is inserted on top and below the ToC list before the being
    -- wrapped with the fence texts, same as vim-markdown-toc.
  },

  -- Set auto_update=true to use the following defaults.
  -- Set to false to disable completely.
  -- Fields events and pattern are used unprocessed for creating autocmds.
  auto_update = {
    enabled = true,
    -- This allows the ToC to be refreshed silently on save for any markdown file.
    -- The refresh operation uses `Mtoc update` and does NOT create the ToC if
    -- it does not exist.
    events = { "BufWritePre" },
    -- Neovim autocmd patterns do NOT support brace expansion; use a list.
    pattern = { "*.md", "*.mdown", "*.mkd", "*.mkdn", "*.markdown", "*.mdwn" },
    suppress_pollution = true,
  },

  -- links = {
  --   formatters = {
  --     gfm = "builtins.gfm",
  --   },
  --   chooser = function() return "gfm" end
  -- },
}

---@type mtoc.Config
M.opts = M.defaults

---Should be called after merge_opts (ensure config.opts is non-empty)
function M.resolve_shortcut_opts()
  ---@type any
  local value = M.opts.fences
  if type(value) == 'boolean' then
    M.opts.fences = M.defaults.fences
    if not value then
      M.opts.fences.enabled = false
    end
  end

  value = M.opts.auto_update
  if type(value) == 'boolean' then
    M.opts.auto_update = M.defaults.auto_update
    if not value then
      M.opts.auto_update.enabled = false
    end
  end

  if type(M.opts.auto_update.events) == 'string' then
    ---@diagnostic disable-next-line
    M.opts.auto_update.events = { M.opts.auto_update.events }
  end
  -- Normalize pattern: convert brace expansion to list if present
  local pat = M.opts.auto_update.pattern
  if type(pat) == 'string' then
    local m = pat:match('%*%.%{(.+)%}')
    if m then
      local list = {}
      for ext in m:gmatch('[^,]+') do
        table.insert(list, '*.'..ext)
      end
      M.opts.auto_update.pattern = list
    else
      ---@diagnostic disable-next-line
      M.opts.auto_update.pattern = { pat }
    end
  end
  if type(M.opts.toc_list.markers) == 'string' then
    ---@diagnostic disable-next-line
    M.opts.toc_list.markers = { M.opts.toc_list.markers }
  end
  if type(M.opts.headings.exclude) == 'string' then
    ---@diagnostic disable-next-line
    M.opts.headings.exclude = { M.opts.headings.exclude }
  end
end

---@param opts mtoc.UserConfig
function M.merge_opts(opts)
  M.opts = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
  M.resolve_shortcut_opts()
end

---@param opts mtoc.UserConfig
function M.update_opts(opts)
  M.opts = vim.tbl_deep_extend('force', {}, M.opts, opts or {})
  M.resolve_shortcut_opts()
end

return M
