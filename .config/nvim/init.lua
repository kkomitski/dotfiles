vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },
  { import = "custom.plugins" },
}, lazy_config)

-- Generate the NvChad highlight cache on first run or after it is cleared.
local base46_defaults = vim.g.base46_cache .. "defaults"
local base46_statusline = vim.g.base46_cache .. "statusline"
if not (vim.uv.fs_stat(base46_defaults) and vim.uv.fs_stat(base46_statusline)) then
  require("lazy").load { plugins = { "base46" }, wait = true }
  require("base46").load_all_highlights()
end

-- load theme
dofile(base46_defaults)
dofile(base46_statusline)

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
