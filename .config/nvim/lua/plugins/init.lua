return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },

  {
    "numToStr/Comment.nvim",
    opts = {},
  },

  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = "ToggleTerm",
    opts = {
      direction = "horizontal",
      size = 15,
      shade_terminals = false,
    },
  },

  {
    "ahmedkhalf/project.nvim",
    opts = {
      detection_methods = { "pattern" },
      patterns = { ".git", "package.json", "go.mod", "pom.xml", "build.gradle", "gradlew", "Makefile" },
      show_hidden = true,
      silent_chdir = true,
    },
    config = function(_, opts)
      require("project_nvim").setup(opts)
      pcall(function()
        require("telescope").load_extension "projects"
      end)
    end,
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      use_diagnostic_signs = true,
    },
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
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
        "tailwindcss",
        "terraformls",
        "ts_ls",
        "yamlls",
        "zls",
      },
      automatic_installation = true,
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "css",
        "dockerfile",
        "go",
        "gomod",
        "gosum",
        "html",
        "java",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "rust",
        "scss",
        "svelte",
        "terraform",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
        "zig",
      },
    },
  },

  -- VSCode extension equivalents for formatting, diagnostics, navigation, and tests.
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "clang-format",
        "eslint_d",
        "google-java-format",
        "prettier",
        "shellcheck",
        "stylua",
      },
    },
  },

  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  {
    "norcalli/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("colorizer").setup()
    end,
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "quarto" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },

  {
    "tpope/vim-fugitive",
    cmd = "Git",
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "mfussenegger/nvim-dap",
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"
      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,

  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      ensure_installed = {
        "codelldb",
        "debugpy",
        "delve",
      },
      automatic_installation = true,
    },
  },

  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-neotest/nvim-nio",
      "haydenmeade/neotest-jest",
    },
    config = function()
      require("neotest").setup {
        adapters = {
          require "neotest-jest",
        },
      }
    end,
  },

  {
    "gpanders/editorconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require "lint"
      lint.linters_by_ft = {
        bash = { "shellcheck" },
        sh = { "shellcheck" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  -- {
  --   "zbirenbaum/copilot.lua",
  --   cmd = "Copilot",
  --   event = "InsertEnter",
  --   opts = {
  --     suggestion = { enabled = true, auto_trigger = true },
  --     panel = { enabled = true },
  --   },
  -- },

  -- {
  --   "zbirenbaum/copilot-cmp",
  --   dependencies = { "zbirenbaum/copilot.lua" },
  --   config = function()
  --     require("copilot_cmp").setup()
  --   end,
  -- },

  -- {
  --   "CopilotC-Nvim/CopilotChat.nvim",
  --   branch = "main",
  --   dependencies = { "zbirenbaum/copilot.lua", "nvim-lua/plenary.nvim" },
  --   cmd = "CopilotChat",
  --   opts = {
  --     show_help = false,
  --   },
  -- },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
