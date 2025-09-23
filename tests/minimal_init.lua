-- Minimal init for running tests
vim.cmd('set rtp+=' .. vim.fn.fnamemodify('.', ':p'))

-- Prefer vendored plugins under <repo_root>/deps/
local function add_rtp_if_exists(p)
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.rtp:append(p)
  end
end

-- Resolve repo root from this file location: tests/minimal_init.lua -> <root>
local script = debug.getinfo(1, 'S').source
if type(script) == 'string' and script:sub(1, 1) == '@' then
  local here = script:sub(2)
  local root = vim.fn.fnamemodify(here, ':p:h:h')
  add_rtp_if_exists(root .. '/deps/plenary.nvim')
  add_rtp_if_exists(root .. '/deps/nvim-treesitter')
end

-- Fallbacks: also try common install paths (useful on CI/dev machines)
local data = vim.fn.stdpath('data')
local candidates = {
  data .. '/lazy/plenary.nvim',                     -- lazy.nvim default
  data .. '/site/pack/packer/start/plenary.nvim',   -- packer default
  data .. '/site/pack/deps/start/plenary.nvim',     -- other pack managers
}
for _, p in ipairs(candidates) do
  add_rtp_if_exists(p)
end
