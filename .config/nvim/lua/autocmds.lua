require "nvchad.autocmds"
local code_action_group = vim.api.nvim_create_augroup("vscode_code_actions_on_save", { clear = true })

local function apply_source_actions(bufnr)
  local clients = vim.lsp.get_clients { bufnr = bufnr }
  local kinds = {}

  for _, client in ipairs(clients) do
    if client.name == "eslint" then
      kinds["source.fixAll.eslint"] = "eslint"
    elseif client.name == "ts_ls" then
      kinds["source.organizeImports"] = "ts_ls"
    end
  end

  for kind, client_name in pairs(kinds) do
    local params = vim.lsp.util.make_range_params(0)
    params.context = {
      diagnostics = vim.diagnostic.get(bufnr),
      only = { kind },
    }

    local responses = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 500)
    for client_id, response in pairs(responses or {}) do
      local client = vim.lsp.get_client_by_id(client_id)
      if client and client.name == client_name and response.result then
        for _, action in ipairs(response.result) do
          if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
          elseif action.command then
            vim.lsp.buf.execute_command(action.command)
          end
        end
      end
    end
  end
end

vim.api.nvim_create_autocmd("BufWritePre", {
  group = code_action_group,
  callback = function(args)
    apply_source_actions(args.buf)
  end,
})
