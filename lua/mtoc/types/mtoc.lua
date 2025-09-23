---@class mtoc.TocItemInfo
---@field name string
---@field link string
---@field marker string
---@field indent string

---@class mtoc.ConfigHeadings
---@field before_toc boolean
---@field exclude string[]|fun(heading:string):boolean
---@field pattern string
---@field parser 'auto'|'treesitter'|'regex'
---@field min_depth integer|nil
---@field max_depth integer|nil

---@class mtoc.UserConfigHeadings
---@field before_toc? boolean
---@field exclude? string|string[]|fun(heading:string):boolean
---@field pattern? string
---@field parser? 'auto'|'treesitter'|'regex'
---@field min_depth? integer|nil
---@field max_depth? integer|nil

---@class mtoc.ConfigTocList
---@field markers string[]
---@field cycle_markers boolean
---@field numbered boolean
---@field indent_size integer|fun():integer
---@field item_format_string string
---@field item_formatter fun(item_info:mtoc.TocItemInfo, fmtstr:string):string
---@field post_processor fun(lines:string[]):string[]

---@class mtoc.UserConfigTocList
---@field markers? string|string[]
---@field cycle_markers? boolean
---@field numbered? boolean
---@field indent_size? integer|fun():integer
---@field item_format_string? string
---@field item_formatter? fun(item_info:mtoc.TocItemInfo, fmtstr:string):string
---@field post_processor? fun(lines:string[]):string[]

---@class mtoc.ConfigFences
---@field enabled boolean
---@field start_text string
---@field end_text string

---@class mtoc.UserConfigFences
---@field enabled? boolean
---@field start_text? string
---@field end_text? string

---@class mtoc.ConfigAutoUpdate
---@field enabled boolean
---@field events string[]
---@field pattern string
---@field suppress_pollution boolean

---@class mtoc.UserConfigAutoUpdate
---@field enabled? boolean
---@field events? string[]
---@field pattern? string
---@field suppress_pollution? boolean

---@class mtoc.Config
---@field headings mtoc.ConfigHeadings
---@field toc_list mtoc.ConfigTocList
---@field fences mtoc.ConfigFences
---@field auto_update mtoc.ConfigAutoUpdate

---@class mtoc.UserConfig
---@field headings? mtoc.UserConfigHeadings
---@field toc_list? mtoc.UserConfigTocList
---@field fences? boolean|mtoc.UserConfigFences
---@field auto_update? boolean|mtoc.UserConfigAutoUpdate
