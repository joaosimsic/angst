# Refactoring Blueprint: Front/Back Data-Driven Architecture

This blueprint structures your Neovim configuration into a **Frontend vs. Backend** architecture using a data-driven model for languages.

## 1. Directory Structure

```text
config/
  lua/
    config/                  -- INFRASTRUCTURE (The System Kernel)
      autocmds.lua
      keymaps.lua            -- Plugin-free, vanilla Neovim keymaps only
      lazy.lua               -- Orchestrates loading Frontend & Backend layers
      options.lua            -- Native vim.opt adjustments
      
    frontend/                -- FRONTEND LAYER (UI, UX & Feature Panels)
      ai.lua                 -- ClaudeCode / Copilot / Chat Panels
      git.lua                -- LazyGit / Neogit / Git Gutter UI
      navigation.lua         -- Telescope / Harpoon / Trouble
      visual.lua             -- Themes / Statusline / Transparency

    backend/                 -- BACKEND LAYER (Core Engines & Adapters)
      -- Core Execution Ports (The Invisible Plumbing)
      completion.lua         -- Autocomplete data engine (nvim-cmp)
      formatting.lua         -- Formatting port orchestrator (conform.nvim)
      linting.lua            -- Linter port orchestrator (nvim-lint)
      lsp.lua                -- LSP client initialization (lspconfig)
      treesitter.lua         -- Syntax parsing engine (nvim-treesitter)
      
      -- Language Adapters (Pure Data / No Plugin Leakage)
      csharp.lua             -- C# metadata configuration
      go.lua                 -- Go metadata configuration
      python.lua             -- Python metadata configuration
      rust.lua               -- Rust metadata configuration
      web.lua                -- Web (TS/JS/CSS/HTML) metadata configuration
  init.lua

```

---

## 2. Infrastructure Layer

### `config/lua/config/lazy.lua`

```lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("lazy").setup({
  spec = {
    -- 1. Boot up core background engines and language adapters
    { import = "backend" },
    -- 2. Boot up visual configurations and feature panels
    { import = "frontend" },
  },
  defaults = { lazy = false },
})

```

---

## 3. Backend Layer (The Core Engines / Ports)

These core engine files act as **ports**. They automatically scan your language adapter modules, map the pure data parameters, and dynamically initialize the correct plugin configs.

### `config/lua/backend/lsp.lua`

```lua
return {
  "neovim/nvim-lspconfig",
  dependencies = { "hrsh7th/cmp-nvim-lsp", "folke/lazydev.nvim" },
  config = function()
    local lspconfig = require("lspconfig")
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Global actions executed upon ANY attached language server
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local opts = { buffer = args.buf, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      end,
    })

    -- Dynamically load and parse language adapters for standard LSPs
    local backend_path = vim.fn.stdpath("config") .. "/lua/backend/"
    local files = vim.fn.split(vim.fn.glob(backend_path .. "*.lua"), "\n")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      -- Skip core framework scripts
      if not vim.tbl_contains({ "lsp", "formatting", "linting", "treesitter", "completion" }, name) then
        local success, adapter = pcall(require, "backend." .. name)
        
        -- If the adapter returns data asking for a standard lsp_server, set it up
        if success and adapter.lsp_server then
          lspconfig[adapter.lsp_server].setup({
            capabilities = capabilities,
            settings = adapter.lsp_settings or {},
          })
        end
      end
    end
  end,
}

```

### `config/lua/backend/formatting.lua`

```lua
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  keys = {
    {
      "<leader>f",
      function() require("conform").format({ async = false, lsp_fallback = true }) end,
      desc = "Engine: Format File",
    },
  },
  opts = function()
    local opts = {
      formatters_by_ft = {},
      format_on_save = { timeout_ms = 1000, lsp_fallback = true },
    }

    -- Pull formatting rules dynamically out of the adapters
    local backend_path = vim.fn.stdpath("config") .. "/lua/backend/"
    local files = vim.fn.split(vim.fn.glob(backend_path .. "*.lua"), "\n")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      if not vim.tbl_contains({ "lsp", "formatting", "linting", "treesitter", "completion" }, name) then
        local success, adapter = pcall(require, "backend." .. name)
        
        if success and adapter.filetypes and adapter.formatter then
          for _, ft in ipairs(adapter.filetypes) do
            -- Wrap string formatters in an array for conform compatibility
            opts.formatters_by_ft[ft] = type(adapter.formatter) == "table" 
              and adapter.formatter 
              or { adapter.formatter }
          end
        end
      end
    end

    return opts
  end,
}

```

### `config/lua/backend/linting.lua`

```lua
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufNewFile", "BufWritePost" },
  opts = function()
    local opts = { linters_by_ft = {} }

    -- Pull linting targets dynamically out of the adapters
    local backend_path = vim.fn.stdpath("config") .. "/lua/backend/"
    local files = vim.fn.split(vim.fn.glob(backend_path .. "*.lua"), "\n")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      if not vim.tbl_contains({ "lsp", "formatting", "linting", "treesitter", "completion" }, name) then
        local success, adapter = pcall(require, "backend." .. name)
        
        if success and adapter.filetypes and adapter.linter then
          for _, ft in ipairs(adapter.filetypes) do
            opts.linters_by_ft[ft] = type(adapter.linter) == "table" 
              and adapter.linter 
              or { adapter.linter }
          end
        end
      end
    end

    return opts
  end,
  config = function(_, opts)
    local lint = require("lint")
    lint.linters_by_ft = opts.linters_by_ft

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter" }, {
      callback = function() lint.try_lint() end,
    })
  end,
}

```

### `config/lua/backend/treesitter.lua`

```lua
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  opts = function()
    local opts = {
      ensure_installed = { "lua", "markdown", "vim", "vimdoc" },
      highlight = { enabled = true },
    }

    -- Feed parser requirements into Treesitter dynamically
    local backend_path = vim.fn.stdpath("config") .. "/lua/backend/"
    local files = vim.fn.split(vim.fn.glob(backend_path .. "*.lua"), "\n")

    for _, file in ipairs(files) do
      local name = vim.fn.fnamemodify(file, ":t:r")
      if not vim.tbl_contains({ "lsp", "formatting", "linting", "treesitter", "completion" }, name) then
        local success, adapter = pcall(require, "backend." .. name)
        
        if success and adapter.treesitter then
          if type(adapter.treesitter) == "table" then
            vim.list_extend(opts.ensure_installed, adapter.treesitter)
          else
            table.insert(opts.ensure_installed, adapter.treesitter)
          end
        end
      end
    end

    return opts
  end,
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}

```

### `config/lua/backend/completion.lua`

*(Standard standalone setup for text completion pipelines).*

```lua
return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer", "hrsh7th/cmp-path",
    "saadparwaiz1/cmp_luasnip", "L3MON4D3/LuaSnip", "rafamadriz/friendly-snippets"
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")
    require("luasnip.loaders.from_vscode").lazy_load()

    cmp.setup({
      snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
      window = { completion = cmp.config.window.bordered(), documentation = cmp.config.window.bordered() },
      mapping = cmp.mapping.preset.insert({
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
          else fallback() end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then luasnip.jump(-1)
          else fallback() end
        end, { "i", "s" }),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),
        ["<C-Space>"] = cmp.mapping.complete(),
      }),
      sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "luasnip" } }, { { name = "buffer" }, { name = "path" } }),
    })
  end,
}

```

---

## 4. Backend Layer (The Pure Language Adapters)

These files contain no plugin execution logic, and **zero plugin names**. They are strict, declarative data configurations.

### `config/lua/backend/go.lua`

```lua
return {
  filetypes = { "go" },
  lsp_server = "gopls",
  formatter = "goimports",
  linter = "golangci-lint",
  treesitter = "go",
  lsp_settings = {
    gopls = { staticcheck = true },
  },
}

```

### `config/lua/backend/python.lua`

```lua
return {
  filetypes = { "python" },
  lsp_server = "pyright",
  formatter = "ruff_format",
  linter = "ruff",
  treesitter = "python",
}

```

### `config/lua/backend/web.lua`

```lua
return {
  filetypes = { "javascript", "typescript", "html", "css" },
  lsp_server = "ts_ls",
  formatter = "prettierd",
  linter = "eslint_d",
  treesitter = { "typescript", "javascript", "html", "css" },
}

```

### Handling Edge-Case Languages (Rust & C#)

What happens if a language requires custom ecosystem plugins (like `rustaceanvim` or `roslyn.nvim`) instead of the default `lspconfig` setups?

Because `lazy.nvim` automatically executes tables arrays, you can append custom standalone lazy schemas to the bottom of the data table. The data part feeds formatting/treesitter, and the lazy array parts feed the custom ecosystem plugins.

#### `config/lua/backend/rust.lua`

```lua
return {
  -- 1. Pure data contract for formatting & parsing
  filetypes = { "rust" },
  formatter = "rustfmt",
  treesitter = "rust",

  -- 2. Embedded lazy plugin layout to execute standalone ecosystem tooling
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    config = function()
      vim.g.rustaceanvim = {
        server = {
          default_settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
        },
      }
    end,
  },
}

```

#### `config/lua/backend/csharp.lua`

```lua
return {
  filetypes = { "cs" },
  formatter = "csharpier",
  treesitter = "c_sharp",

  {
    "GustavEikaas/easy-dotnet.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
    ft = { "cs" },
    config = true,
    keys = {
      { "<leader>dr", "<cmd>Dotnet run<cr>", desc = "Execute .NET Project" },
    },
  },
  {
    "seblyng/roslyn.nvim",
    ft = { "cs" },
    config = function()
      require("roslyn").setup({
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })
    end,
  },
}

```

---

## 5. Frontend Layer (User-Facing Tools)

These features handle user interactions and are decoupled from backend syntax compiling logic.

### `config/lua/frontend/navigation.lua`

```lua
return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-ui-select.nvim" },
    keys = {
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Search Files" },
      { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live Grep" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = { file_ignore_patterns = { "node_modules/", "%.git/", "target/" } },
        extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown({}) } }
      })
      telescope.load_extension("ui-select")
    end,
  },
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>a", function() require("harpoon"):list():add() end, desc = "Harpoon Save" },
      { "<C-e>", function() local h = require("harpoon") h.ui:toggle_quick_menu(h:list()) end, desc = "Harpoon UI" },
    },
    config = true,
  },
}

```

### `config/lua/frontend/ai.lua`

```lua
return {
  {
    "coder/claudecode.nvim",
    cmd = { "ClaudeCode" },
    keys = { { "<leader>gg", "<cmd>ClaudeCode<cr>", mode = { "n", "t" }, desc = "Toggle Claude Panel" } },
    opts = { terminal = { split_side = "right", split_width_percentage = 0.35, auto_close = true } },
  },
}

```

### `config/lua/frontend/git.lua`

```lua
return {
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit" },
    keys = { { "<leader>lg", "<cmd>LazyGit<CR>", desc = "Open LazyGit Interface" } },
  },
}

```

### `config/lua/frontend/visual.lua`

```lua
return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { options = { theme = "auto" } },
  },
  {
    "xiyaowong/transparent.nvim",
    config = function()
      require("transparent").setup({ exclude_groups = { "CursorLine" } })
      vim.cmd("TransparentEnable")
    end,
  },
}

```

---

You're right to question that. My previous structure mostly separated **plugin names**, not **frontend concepts**. For a larger config, `frontend/` should probably have internal domains instead of just `statusline.lua`, `theme.lua`, etc.

A more logical frontend split:

```text
lua/
├── frontend/
│   │
│   ├── appearance/
│   │   ├── colorscheme.lua
│   │   ├── highlights.lua
│   │   ├── fonts.lua
│   │   └── transparency.lua
│   │
│   ├── navigation/
│   │   ├── telescope.lua
│   │   ├── neo-tree.lua
│   │   └── harpoon.lua
│   │
│   ├── status/
│   │   ├── statusline.lua
│   │   ├── tabline.lua
│   │   └── winbar.lua
│   │
│   ├── editing/
│   │   ├── autopairs.lua
│   │   ├── surround.lua
│   │   ├── comments.lua
│   │   └── snippets.lua
│   │
│   ├── feedback/
│   │   ├── notifications.lua
│   │   ├── diagnostics.lua
│   │   └── messages.lua
│   │
│   ├── layout/
│   │   ├── splits.lua
│   │   ├── terminal.lua
│   │   └── windows.lua
│   │
│   └── dashboard/
│       └── init.lua
```

The idea:

### `appearance/`

"What does Neovim look like?"

* colorscheme
* highlights
* icons
* UI colors
* transparency

---

### `navigation/`

"How do I move around?"

* file explorer
* fuzzy finder
* buffers
* marks
* jump tools

Examples:

* Telescope
* Neo-tree
* Harpoon

---

### `status/`

"What information is displayed?"

* statusline
* tabline
* winbar
* breadcrumbs

Examples:

* lualine
* heirline
* navic

---

### `editing/`

"How does typing feel?"

* autopairs
* surround
* comment toggles
* snippets
* text objects

Examples:

* nvim-autopairs
* mini.surround
* Comment.nvim

---

### `feedback/`

"How does Neovim communicate?"

* notifications
* diagnostics UI
* command messages

Examples:

* noice.nvim
* nvim-notify
* trouble.nvim

---

### `layout/`

"How are windows arranged?"

* floating terminals
* splits
* side panels
* scratch buffers

---

Then your whole config becomes:

```text
lua/
├── core/
│   ├── options.lua
│   ├── keymaps.lua
│   └── autocmds.lua
│
├── backend/
│   ├── lsp/
│   ├── treesitter/
│   ├── lint/
│   └── format/
│
├── frontend/
│   ├── appearance/
│   ├── navigation/
│   ├── status/
│   ├── editing/
│   ├── feedback/
│   └── layout/
│
└── plugins/
```

This is closer to how you would organize an IDE: **appearance, navigation, editing, feedback, layout** are user-facing concerns, while LSP/Treesitter are engine concerns.

