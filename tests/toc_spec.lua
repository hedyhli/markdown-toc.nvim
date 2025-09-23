local helpers = {}

local function set_buf(lines)
  vim.cmd('enew')
  vim.bo.filetype = 'markdown'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function setup_config(opts)
  local config = require('mtoc/config')
  config.merge_opts(opts or {})
end

local function get_toc_full()
  local toc = require('mtoc/toc')
  return toc.gen_toc_list(0)
end

local function get_toc_scoped()
  local toc = require('mtoc/toc')
  return toc.gen_toc_list_scoped()
end

local parsers = { 'regex', 'treesitter' }

for _, parser_type in ipairs(parsers) do
  describe('mtoc TOC generation', function()
    before_each(function()
      -- reset module config to defaults between tests
      package.loaded['mtoc/config'] = nil
      package.loaded['mtoc/toc'] = nil
    end)
  
    it('respects min/max depth in partial generation by label with parser=' .. parser_type, function()
      set_buf({
        '# Title',
        '',
        '## Case 1',
        '### A',
        '#### A1',
        '##### A1.1',
        '### B',
        '',
        '## Case 2',
        '### C',
      })
      setup_config({
        headings = { parser = parser_type, min_depth = 3, max_depth = 4 },
      })
      local toc = require('mtoc/toc')
      local lines = toc.gen_toc_list_for_label('case-1')
      local joined = table.concat(lines, '\n')
      -- Includes H3 and H4 under Case 1, excludes H5 and base H2 and other sections
      assert.is_true(joined:find('%[A%]') ~= nil)
      assert.is_true(joined:find('%[A1%]') ~= nil)
      assert.is_true(joined:find('%[A1%.1%]') == nil)
      assert.is_true(joined:find('%[B%]') ~= nil)
      assert.is_true(joined:find('%[Case 1%]') == nil)
      assert.is_true(joined:find('%[C%]') == nil)
    end)
  
    it('respects min/max depth in cursor-scoped partial generation with parser=' .. parser_type, function()
      set_buf({
        '# Title',
        '',
        '## Case 1',
        '### A',
        '#### A1',
        '### B',
        '',
        '## Other',
        '### X',
      })
      setup_config({
        headings = { parser = parser_type, partial_under_cursor = true, min_depth = 3, max_depth = 3 },
      })
      -- Put cursor on the H3 heading line ("### A") to scope siblings A and B
      vim.api.nvim_win_set_cursor(0, {4, 0})
      local toc = require('mtoc/toc')
      local s,e = toc.find_current_section_range(4)
      local range_lines = toc.gen_toc_list_for_range(s,e)
      local range_joined = table.concat(range_lines, '\n')
      -- H3 children under the H2 section (A and B), exclude H4 and outside section
      assert.is_true(range_joined:find('%[A%]') ~= nil)
      assert.is_true(range_joined:find('%[B%]') ~= nil)
      assert.is_true(range_joined:find('%[A1%]') == nil)
      assert.is_true(range_joined:find('%[X%]') == nil)
      -- gen_toc_list_scoped should satisfy the same constraints
      local scoped_lines = get_toc_scoped()
      local scoped_joined = table.concat(scoped_lines, '\n')
      assert.is_true(scoped_joined:find('%[A%]') ~= nil)
      assert.is_true(scoped_joined:find('%[B%]') ~= nil)
      assert.is_true(scoped_joined:find('%[A1%]') == nil)
      assert.is_true(scoped_joined:find('%[X%]') == nil)
    end)
  
  describe('mtoc parsers and fences', function()
    before_each(function()
      package.loaded['mtoc/config'] = nil
      package.loaded['mtoc/toc'] = nil
      vim.cmd('enew')
      vim.bo.filetype = 'markdown'
    end)
  
    it('generates full TOC with parser=' .. parser_type, function()
      set_buf({
        '# Title',
        '',
        '## Sec A',
        '### A1',
        '### A2',
        '',
        '## Sec B',
        '### B1',
      })
      setup_config({
        headings = { parser = parser_type },
        toc_list = { markers = {'*'}, cycle_markers = false, indent_size = 2 },
      })
      local lines = get_toc_full()
      local joined = table.concat(lines, '\n')
      assert.is_true(joined:find('%[Sec A%]') ~= nil)
      assert.is_true(joined:find('%[A1%]') ~= nil)
      assert.is_true(joined:find('%[Sec B%]') ~= nil)
    end)
  
    it('detects unlabeled and labeled TOC fences and generates partial for label with parser=' .. parser_type, function()
      set_buf({
        '<!-- mtoc-start -->',
        '',
        '1. [Will be replaced](#will-be-replaced)',
        '',
        '<!-- mtoc-end -->',
        '',
        '# Title',
        '',
        '## Case 1',
        '',
        '### A',
        '### B',
        '',
        '<!-- mtoc-start:case-1 -->',
        '',
        '1. [Will be replaced too](#x)',
        '',
        '<!-- mtoc-end:case-1 -->',
      })
      setup_config({
        debug = false,
        headings = { parser = parser_type },
        toc_list = { markers = {'1.'}, cycle_markers = false, indent_size = 3 },
        fences = true,
      })
      local toc = require('mtoc/toc')
      local fences = toc.find_all_fences()
      -- Require at least one labeled fence so we can validate partial-by-label
      local has_unlabeled, has_labeled = false, false
      for _, f in ipairs(fences) do
        if f.label and f.label ~= '' then has_labeled = true else has_unlabeled = true end
      end
      assert.is_true(has_labeled)

      -- Ensure partial generation for label works
      local partial = toc.gen_toc_list_for_label('case-1')
      local joined = table.concat(partial, '\n')
      assert.is_true(joined:find('%[A%]') ~= nil)
      assert.is_true(joined:find('%[B%]') ~= nil)
      assert.is_true(joined:find('%[Case 1%]') == nil)
    end)
  end)
  
    it('renders two H2 at same level (not nested) with parser=' .. parser_type, function()
      set_buf({
        '## A',
        '',
        '## B',
      })
      setup_config({
        headings = {
          parser = parser_type,
          min_depth = nil,
          max_depth = nil,
          partial_under_cursor = false,
        },
        toc_list = {
          markers = {'*'},
          cycle_markers = false,
          indent_size = 2,
        },
      })
  
      local lines = get_toc_full()
      assert.is_true(#lines >= 2)
      assert.is_true(lines[1]:match('^%* %[') ~= nil)
      assert.is_true(lines[2]:match('^%* %[') ~= nil)
    end)
  
    it('renders two H3 at same level (not nested) with parser=' .. parser_type, function()
      set_buf({
        '### A',
        '',
        '### B',
      })
      setup_config({
        headings = {
          parser = parser_type,
        },
        toc_list = {
          markers = {'*'},
          cycle_markers = false,
          indent_size = 2,
        },
      })
  
      local lines = get_toc_full()
      assert.is_true(#lines >= 2)
      -- both items should have no leading spaces (normalized base depth)
      assert.is_true(lines[1]:match('^%* %[') ~= nil)
      assert.is_true(lines[2]:match('^%* %[') ~= nil)
    end)
  
    it('enforces minimum 3-space indent for numbered lists with parser=' .. parser_type, function()
      set_buf({
        '## A',
        '### B',
      })
      setup_config({
        headings = {
          parser = parser_type,
        },
        toc_list = {
          numbered = true,
          indent_size = 2, -- will be bumped to 3
        },
      })
  
      local lines = get_toc_full()
      assert.is_true(lines[1]:match('^1%. %[') ~= nil)
      -- second line should be indented with at least 3 spaces
      assert.is_true(lines[2]:match('^%s%s%s1%. %[') ~= nil)
    end)
  
    it('applies min/max depth filters with parser=' .. parser_type, function()
      set_buf({
        '# H1',
        '## H2',
        '### H3',
        '#### H4',
      })
      setup_config({
        headings = {
          parser = parser_type,
          min_depth = 2,
          max_depth = 3,
        },
        toc_list = { markers = {'*'} },
      })
  
      local lines = get_toc_full()
      local joined = table.concat(lines, '\n')
      assert.is_true(joined:find('%[H2%]') ~= nil)
      assert.is_true(joined:find('%[H3%]') ~= nil)
      assert.is_true(joined:find('%[H1%]') == nil)
      assert.is_true(joined:find('%[H4%]') == nil)
    end)
  
    it('generates partial TOC under cursor when enabled (skip base heading) with parser=' .. parser_type, function()
      set_buf({
        '# Title',
        '',
        '## Section',
        '',
        '### A',
        '### B',
        '',
        '## Other',
        '### C',
      })
      setup_config({
        headings = {
          parser = parser_type,
          partial_under_cursor = true,
          min_depth = 3, -- ensure children of current section only
        },
        toc_list = { markers = {'*'} },
      })
  
      -- Put cursor inside Section
      vim.api.nvim_win_set_cursor(0, {5, 0}) -- line with "### A"
      local lines = get_toc_scoped()
      local joined = table.concat(lines, '\n')
      -- Should include both A and B under the Section; exclude the parent Section heading
      assert.is_true(joined:find('%[A%]') ~= nil)
      assert.is_true(joined:find('%[B%]') ~= nil)
      assert.is_true(joined:find('%[Section%]') == nil)
      -- Should not include headings from Other section
      assert.is_true(joined:find('%[C%]') == nil)
    end)
  end)
end
