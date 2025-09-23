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

1. [Install](#install)
1. [Setup](#setup)
   1. [Common configuration options](#common-configuration-options)
   1. [Fences](#fences)
   1. [Examples](#examples)
1. [Commands](#commands)
1. [Full Configuration](#full-configuration)
   1. [Advanced Examples](#advanced-examples)
   1. [Project-local configuration](#project-local-configuration)
1. [TODO](#todo)

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
    before_toc = false,
    -- Parser to use for heading detection: 'auto' | 'treesitter' | 'regex'
    parser = 'auto',
    -- Generate a partial ToC for the section under the cursor
    partial_under_cursor = false,
    -- Start including headings from this depth (1=H1). Allows partial ToCs.
    min_depth = nil,
    -- Stop including headings up to this depth (inclusive)
    max_depth = nil,
    -- Either list of lua patterns to exclude, or a function(title)->boolean
    exclude = {},
    -- Pattern to detect headings for the regex parser
    -- 1st capture = hashes (###), 2nd capture = title
    pattern = "^(#+)%s+(.+)$",
  },

  -- Table or boolean. Set to true to use these defaults, set to false to disable completely.
  -- Fences are needed for the update/remove commands; otherwise you can visually
  -- select a range and run :Mtoc update.
  fences = {
    enabled = true,
    -- These texts are wrapped within "<!-- % -->"
    start_text = "mtoc-start",
    end_text   = "mtoc-end",
  },

  -- Auto-update of the ToC on save (only if fences found).
  -- You can set auto_update=true (shortcut) or customize the table below.
  auto_update = {
    enabled = true,
    events = { "BufWritePre" },
    -- Use a list of patterns; brace expansion is not supported by nvim autocmds.
    pattern = { "*.md", "*.mdown", "*.mkd", "*.mkdn", "*.markdown", "*.mdwn" },
    -- When true, updates run with keepjumps/lockmarks to avoid polluting state
    suppress_pollution = true,
  },

  toc_list = {
    -- string or list of strings (for cycling)
    -- If cycle_markers=false and markers is a list, only the first is used.
    -- You can set to '1.' to use an automatically numbered list for ToC (if supported).
    markers = { '*' },
    cycle_markers = false,
    numbered = false,
    -- Integer or function returning integer (e.g. from shiftwidth)
    indent_size = 2,
    -- Format string for each item (fields: name, link, marker, indent, depth)
    item_format_string = "${indent}${marker} [${name}](#${link})",
    -- Formatter for a single item. Defaults to simple template replacement.
    item_formatter = function(item, fmtstr)
      local s = fmtstr:gsub([[${(%w-)}]], function(key)
        return item[key] or ('${'..key..'}')
      end)
      return s
    end,
    -- Post-process the array of lines before insertion
    post_processor = function(lines) return lines end,
  },
}
```

These are the most common options. For all fields including formatters and
auto-update internals, see [Full Configuration](#full-configuration).

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
  numbered = false,
}
```

Use numbered list for TOC
```lua
toc_list = {
  numbered = true,
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
  headings = {
    before_toc = false,
    parser = 'auto',
    partial_under_cursor = false,
    min_depth = nil,
    max_depth = nil,
    exclude = {},
    pattern = "^(#+)%s+(.+)$",
  },

  toc_list = {
    numbered = false,
    markers = { '*' },
    cycle_markers = false,
    indent_size = 2,
    item_format_string = "${indent}${marker} [${name}](#${link})",
    item_formatter = function(item, fmtstr)
      local s = fmtstr:gsub([[${(%w-)}]], function(key)
        return item[key] or ('${'..key..'}')
      end)
      return s
    end,
    post_processor = function(lines) return lines end,
  },

  fences = {
    enabled = true,
    start_text = "mtoc-start",
    end_text   = "mtoc-end",
  },

  auto_update = {
    enabled = true,
    events = { "BufWritePre" },
    pattern = { "*.md", "*.mdown", "*.mkd", "*.mkdn", "*.markdown", "*.mdwn" },
    suppress_pollution = true,
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
    headings = { parser = 'regex', partial_under_cursor = true, min_depth = 3 },
  })
end
```

Here's an example `.nvim.lua` in the wild that makes use of
`mtoc.update_config`: <https://github.com/hedyhli/outline.nvim/blob/main/.nvim.lua>


<!-- panvimdoc-ignore-start -->
## TODO

- Types
- More tests
- Lua API surface for programmatic usage
- Multiple link style chooser

<!-- panvimdoc-ignore-end -->
