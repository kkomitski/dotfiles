require "nvchad.options"
local user_bin = vim.fn.expand "~/.local/bin"
if not vim.env.PATH:find(user_bin, 1, true) then
  vim.env.PATH = user_bin .. ":" .. vim.env.PATH
end

-- Match the active VSCode profile's core editor behavior.
vim.opt.clipboard = "unnamedplus"
if vim.fn.has "wsl" == 1 then
  if vim.fn.executable "pbcopy" == 1 and vim.fn.executable "pbpaste" == 1 then
    vim.g.clipboard = {
      name = "WSL Windows clipboard",
      copy = { ["+"] = "pbcopy", ["*"] = "pbcopy" },
      paste = { ["+"] = "pbpaste", ["*"] = "pbpaste" },
      cache_enabled = 0,
    }
  end
  vim.opt.keymodel = "startsel,stopsel"
end
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true
