require("nvchad.configs.lspconfig").defaults()

local servers = {
  "bashls",
  "clangd",
  "cssls",
  "eslint",
  "gopls",
  "html",
  "jdtls",
  "jsonls",
  "lua_ls",
  "marksman",
  "pyright",
  "rust_analyzer",
  "svelte",
  "terraformls",
  "ts_ls",
  "yamlls",
  "zls",
}

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
