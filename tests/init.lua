-- Set up busted globals for tests
_G.describe = require('busted').describe
_G.it = require('busted').it
_G.before_each = require('busted').before_each
_G.assert = require('luassert')

-- Add the plugin's lua directory to package path so requires work
local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)")
end

local test_dir = script_path()
local project_root = test_dir:sub(1, -7)  -- Remove "tests/" from the path
package.path = project_root .. "lua/?.lua;" .. package.path 