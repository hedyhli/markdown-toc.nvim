<!-- panvimdoc-ignore-start -->

# markdown-toc.nvim
<!-- panvimdoc-ignore-end -->


Generate and update table of contents list (with links) for markdown.

Almost fully replaces vim-markdown-toc, written in 100% lua.

- Supports setext style headings (`======` and `------`).
- Supports GitHub Flavoured Markdown links by default. If you want to use
  another link format a better configuration structure for this is
  [planned](#todo), but for now you can set your own [formatter
  function](#advanced-examples).
- You can disable fences but keep the updating feature by manually selecting
  your table of contents in visual mode, then running `:Mtoc`

<!-- panvimdoc-ignore-start -->

**Table of contents**

Dog-fooding ;)

<!-- mtoc-start -->

* [Install](#install)
* [Setup](#setup)
  * [Common configuration options](#common-configuration-options)
  * [Fences](#fences)
  * [Examples](#examples)
* [Commands](#commands)
* [Full Configuration](#full-configuration)
  * [Advanced Examples](#advanced-examples)
  * [Project-local configuration](#project-local-configuration)
* [TODO](#todo)

<!-- mtoc-end -->
<!-- panvimdoc-ignore-end -->

## Install

Example for Lazy.nvim:

- Using GitHub repo: `hedyhli/markdown-toc.nvim`
- Using sourcehut repo: `url = "https://git.sr.ht/~hedy/markdown-toc.nvim"`

```lua
{
  "hedyhli/markdown-toc.nvim",
  ft = "markdown",  -- Lazy load on markdown filetype
  cmd = { "Mtoc" }, -- Or, lazy load on "Mtoc" command
  opts = {
    -- Your configuration here (optional)
  },
},
```

Making use of lazy-loading with `ft` means that `Mtoc` commands won't be
available until a markdown file is opened.

Note that the repo is called `markdown-toc.nvim`, but the lua module and
commands are prefixed with `mtoc` rather than `markdown-toc`.

To be explicit or if you run into problems, you can set `main = "mtoc"` in the
plugin spec for Lazy.nvim.

## Setup

```lua
require('mtoc').setup({})
```

A call to the setup function is not required for the plugin to work. Default
configuration will be used.

However, the setup call is **required** if you want to enable the auto-update
feature (because autocmds have to be set up).


### Common configuration options

Pass this table with your config options to the setup function, or put this
table in the `opts` key if you're using Lazy.nvim.

```lua
{
  headings = {
    -- Include headings before the ToC (or current line for `:Mtoc insert`).
    -- Setting to true will include headings that are defined before the ToC
    -- position to be included in the ToC.
    before_toc = false,
  },

  -- Table or boolean. Set to true to use these defaults, set to false to disable completely.
  -- Fences are needed for the update/remove commands, otherwise you can
  -- manually select ToC and run update.
  fences = {
    enabled = true,
    -- These fence texts are wrapped within "<!-- % -->", where the '%' is
    -- substituted with the text.
    start_text = "mtoc-start",
    end_text = "mtoc-end"
    -- An empty line is inserted on top and below the ToC list before the being
    -- wrapped with the fence texts, same as vim-markdown-toc.
  },

  -- Enable auto-update of the ToC (if fences found) on buffer save
  auto_update = true,

  toc_list = {
    -- string or list of strings (for cycling)
    -- If cycle_markers = false and markers is a list, only the first is used.
    -- You can set to '1.' to use a automatically numbered list for ToC (if
    -- your markdown render supports it).
    markers = '*',
    cycle_markers = false,
    -- Example config for cycling markers:
    ----- markers = {'*', '+', '-'},
    ----- cycle_markers = true,
  },
}
```

These are the common config options. For a full list including advanced
customizations including indent size and list item format, please see [Full
Configuration](#full-configuration).

### Fences

Note that whenever you change your fence text, you must either edit all existing
fences by hand if you wish to retain auto-update feature, or you can remove +
insert, or visual select the whole range including fence, and use `:'<,'>Mtoc u!`.

See [commands](#commands).

### Examples

Disable fences (update/remove ToC will not work, unless you run update with
manually selected ToC range):
```lua
fences = false,
```

Cycle markers:
```lua
toc_list = {
  markers = {'*', '+', '-'},
  cycle_markers = true,
}
```

Use numbered list for TOC
```lua
toc_list = {
  markers = '1.',
},
```

Cycling of markers produces a ToC list like this:
```md
* [First heading](#first-heading)
  + [Sub heading](#sub-heading)
  + [Sub heading 2](#sub-heading-2)
    - [Sub-sub heading](#sub-sub-heading)
    - [Sub-sub heading 2](#sub-sub-heading-2)
      * [Sub-sub-sub heading](#sub-sub-sub-heading)
* [Second heading](#second-heading)
  + [Second sub heading](#second-sub-heading)
```

To customize the indent size please see [full
configurations](#full-configuration).

[Advanced configuration patterns](#advanced-examples)


## Commands

Subcommands do not have to be typed in full so long as they are not ambiguous.
These shortcuts are shown in `[square brackets]` below.

- `:[range]Mtoc[!]`

  If range not provided, update ToC if fences are found. If not, insert ToC at
  cursor position.

  If range provided, replace the range with newly generated ToC. If fences are
  enabled and bang provided, also inserts fences.

- `:Mtoc i[nsert]`

  Insert ToC at cursor position.

  If there are no headings found:
  - If fences are enabled, fences are inserted without any content inside
  - Otherwise, an error is printed

- `:[range]Mtoc u[pdate][!]`

  If range not provided, update ToC if fences are found.

  If range provided, replace the range with newly generated ToC. If fences are
  enabled and bang provided, also inserts fences.

  It may print errors when no fences are found, start-end fences are not
  matched, or end found before start.

- `:Mtoc r[emove]`

  Remove ToC if fences are found.

  It may print errors when no fences are found, start-end fences are not
  matched, or end found before start.


## Full Configuration

```lua
{
  -- Config relating to fetching of headings to be included in ToC
  headings = {
    -- Include headings before the ToC (or current line for `:Mtoc insert`)
    before_toc = false,
    -- Either list of lua patterns (regex),
    -- or a function that takes a heading title and returns boolean (true means
    -- to EXCLUDE heading).
    exclude = {},
    -- The first capture is for heading level ('###') and second is for the heading
    -- title.
    pattern = "^(#+)%s+(.+)$",
  },

  -- Config relating to the style and format of the ToC
  toc_list = {
    -- string or list of strings (for cycling)
    -- If cycle_markers = false and markers is a list, only the first is used.
    -- You can set to '1.' to use a automatically numbered list for ToC (if
    -- your markdown render supports it).
    markers = '*',
    cycle_markers = false,
    -- Example config for cycling markers:
    ----- markers = {'*', '+', '-'},
    ----- cycle_markers = true,

    -- Integer or a function that returns an integer.
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
    post_processor = function(lines) return lines end,

    -- Add padding (blank lines) before and after the TOC
    padding_lines = 1,
  },

  -- Table or boolean. Set to true to use these defaults, set to false to disable completely.
  -- Fences are needed for the update/remove commands.
  fences = {
    enabled = true,
    -- These fence texts are wrapped within "<!-- % -->", where the '%' is
    -- substituted with the text.
    start_text = "mtoc start",
    end_text = "mtoc end"
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
    pattern = "*.{md,mdown,mkd,mkdn,markdown,mdwn}",
  },
}
```

### Advanced Examples

Custom link formatter:
```lua
toc_list = {
  item_formatter = function(item, fmtstr)
    local default_formatter = require('mtoc.config').defaults.toc_list.item_formatter
    item.link = item.name:gsub(" ", "_")
    return default_formatter(item, fmtstr)
  end,
},
```
In the above example a link for a heading is generated simply by converting all
spaces to underscores.

You can also wrap the existing formatter like so:
```lua
toc_list = {
  item_formatter = function(item, fmtstr)
    local default_formatter = require('mtoc.config').defaults.toc_list.item_formatter
    item.link = item.link..'-custom-link-ending'
    return default_formatter(item, fmtstr)
  end,
},
```

Exclude headings named "CHANGELOG" or "License":
```lua
headings = {
  exclude = {"CHANGELOG", "License"},
},
```

Exclude headings that begin with "TODO":
```lua
headings = {
  exclude = "^TODO",
},
```

Exclude all capitalized headings:
```lua
headings = {
  exclude = function(title)
    -- Return true means, to exclude it from the ToC
    return title:upper() == title
  end,
},
```

Set indent size for ToC list based on shiftwidth opt:
```lua
toc_list = {
  indent_size = function()
    return vim.bo.shiftwidth
  end,
},
```

Flattened ToC list without links:
```lua
toc_list = {
  item_format_string = "${marker} ${name}",
},
```
This produces something like this:
```md
* Heading 1
* Sub heading
* Sub sub heading
* Heading 2
```

Ensure all heading names are in Title Case when listed in ToC:
```lua
toc_list = {
  item_formatter = function(item, fmtstr)
    local default_formatter = require('mtoc.config').defaults.toc_list.item_formatter
    -- NOTE: Consider using `vim.fn.tolower/toupper` to support letters other than ASCII.
    item.name = item.name:gsub("(%a)([%w_']*)", function(a,b) return a:upper()..b:lower() end)
    return default_formatter(item, fmtstr)
  end,
},
```
Remove `:lower()` to avoid decapitalizing already capitalized rest of words
(like the case for acronyms).

Include only 2nd-level headings
```lua
headings = {
  pattern = "^(##)%s+(.+)$",
}
```

### Project-local configuration

From nvim-0.9, secure loading of per-directory nvim configs are now supported.

You can include this in your neovim config:

```lua
if vim.fn.has("nvim-0.9") == 1 then
  vim.o.exrc = true
end
```

Then in your project root, create a file named `.nvim.lua`, with the following contents:
```lua
local ok, mtoc = pcall(require, 'mtoc')
if ok then
  mtoc.update_config({
    -- new opts to override
  })
end
```

Here's an example `.nvim.lua` in the wild that makes use of
`mtoc.update_config`: <https://github.com/hedyhli/outline.nvim/blob/main/.nvim.lua>


<!-- panvimdoc-ignore-start -->
## TODO

- Types
- Tests
- Lua API
- Link style chooser

<!-- panvimdoc-ignore-end -->
