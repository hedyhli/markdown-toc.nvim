-- Load test setup
require('tests.init')

local toc = require('mtoc.toc')
local config = require('mtoc.config')

-- Mock vim functions
_G.vim = {
  api = {
    nvim_buf_get_lines = function(_, _, _, _)
      return _G._test_buffer_lines or {}
    end
  },
  fn = {
    tolower = string.lower,
    substitute = function(str, pattern, repl, _)
      return str:gsub(pattern, repl)
    end
  }
}

describe("TOC generation", function()
  before_each(function()
    -- Reset config to defaults before each test
    config.opts = {
      toc_list = {
        markers = {"*"},
        cycle_markers = false,
        indent_size = 2,
        item_format_string = "${indent}${marker} [${name}](#${link})",
        item_formatter = function(info, fmt)
          return info.indent .. info.marker .. string.format(" [%s](#%s)", info.name, info.link)
        end
      },
      headings = {
        pattern = "^(#+)%s+(.+)$"
      }
    }
  end)

  it("should keep h3 headers at same level when no h2 exists", function()
    _G._test_buffer_lines = {
      "### First H3",
      "### Second H3"
    }
    
    local toc_lines = toc.gen_toc_list(0)
    assert.are.same({
      "* [First H3](#first-h3)",
      "* [Second H3](#second-h3)"
    }, toc_lines)
  end)

  it("should properly nest h3 under h2", function()
    _G._test_buffer_lines = {
      "## Section",
      "### Subsection 1",
      "### Subsection 2"
    }
    
    local toc_lines = toc.gen_toc_list(0)
    assert.are.same({
      "* [Section](#section)",
      "  * [Subsection 1](#subsection-1)",
      "  * [Subsection 2](#subsection-2)"
    }, toc_lines)
  end)

  it("should handle multiple h2s at same level", function()
    _G._test_buffer_lines = {
      "## First Section",
      "## Second Section"
    }
    
    local toc_lines = toc.gen_toc_list(0)
    assert.are.same({
      "* [First Section](#first-section)",
      "* [Second Section](#second-section)"
    }, toc_lines)
  end)

  it("should handle mixed header levels", function()
    _G._test_buffer_lines = {
      "# Title",
      "## Section 1",
      "### Subsection 1.1",
      "### Subsection 1.2",
      "## Section 2",
      "### Subsection 2.1"
    }
    
    local toc_lines = toc.gen_toc_list(0)
    assert.are.same({
      "* [Title](#title)",
      "  * [Section 1](#section-1)",
      "    * [Subsection 1.1](#subsection-1.1)",
      "    * [Subsection 1.2](#subsection-1.2)",
      "  * [Section 2](#section-2)",
      "    * [Subsection 2.1](#subsection-2.1)"
    }, toc_lines)
  end)

  it("should prevent skipping header levels", function()
    _G._test_buffer_lines = {
      "# Title",
      "#### Deep Section" -- This should be treated as h2
    }
    
    local toc_lines = toc.gen_toc_list(0)
    assert.are.same({
      "* [Title](#title)",
      "  * [Deep Section](#deep-section)"
    }, toc_lines)
  end)
end) 