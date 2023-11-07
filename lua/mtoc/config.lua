local M = {}

M.defaults = {
  -- Config relating to fetching of headings to be included in TOC
  headings = {
    -- TODO
    -- Headings to include
    -- top_level = false,
    -- Include headings before the TOC (or current line for `:Mtoc insert`)
    before_toc = false,
    -- Supports regex
    filter_blacklist = {},
  },

  -- Config relating to the style and format of the TOC
  toc_list = {
    -- string or list of strings (for cycling)
    -- If cycle_markers = false and markers is a list, only the first is used.
    markers = '*',
    cycle_markers = false,
    -- Example config for cycling markers:
    ----- markers = {'*', '+', '-'},
    ----- cycle_markers = true,

    -- Integer or function that returns an integer
    indent_size = 4,

    -- Remove the ${indent} below, or set indent_size=0 to have the whole TOC
    -- be a flattened list.
    item_format_string = "${indent}${marker} [${name}](#${link})",

    ---Formatter for a single TOC list item.
    --`item_info` has fields `name`, `link`, `marker`, `indent`, `line`, `['end']`,
    --`num_children`. To change the format of each heading item but keep the
    --same field substitution syntax, simply change `item_format_string`.
    ---@param item_info table Information for current heading item.
    ---@param fmtstr string from `item_format_string` config
    ---@return string formatted_item
    item_formatter = function(item_info, fmtstr)
      local s = fmtstr:gsub([[${(%w-)}]], function(key)
        return item_info[key] or ('${'..key..'}')
      end)
      return s
    end,
  },

  -- Table or boolean. Set to true to use these defaults, set to false to disable completely.
  -- Fences are needed for the update/remove commands.
  fences = {
    enabled = true,
    -- These fence texts are wrapped within "<!-- % -->", where the '%' is
    -- substituted with the text.
    start_text = "mtoc.nvim start",
    end_text = "mtoc.nvim end"
    -- An empty line is inserted on top and below the TOC list before the being
    -- wrapped with the fence texts, same as vim-markdown-toc.
  },

  -- Set auto_update=true to use the following defaults.
  -- Set to false to disable completely.
  -- Fields events and pattern are used unprocessed for creating autocmds.
  auto_update = {
    enabled = true,
    -- This allows the TOC to be refreshed silently on save for any markdown file.
    -- The refresh operation uses `Mtoc update` and does NOT create the TOC if
    -- it does not exist.
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
  M.opts = vim.tbl_deep_extend('force', {}, M.defaults, opts or {})
end

function M.update_opts(opts)
  M.opts = vim.tbl_deep_extend('force', {}, M.opts, opts or {})
end

return M
