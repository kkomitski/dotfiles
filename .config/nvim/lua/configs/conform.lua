local options = {
  formatters_by_ft = {
    bash = { "shfmt" },
    c = { "clang_format" },
    cpp = { "clang_format" },
    css = { "prettier" },
    html = { "prettier" },
    java = { "google-java-format" },
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    json = { "prettier" },
    jsonc = { "prettier" },
    lua = { "stylua" },
    markdown = { "prettier" },
    python = { "isort", "black" },
    rust = { "rustfmt" },
    scss = { "prettier" },
    sh = { "shfmt" },
    svelte = { "prettier" },
    terraform = { "terraform_fmt" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    yaml = { "prettier" },
  },

  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

return options
