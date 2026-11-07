-- ~/.config/nvim/init.lua — simple Tokyo Night config (after legenddots/init.lua)
-- Plugins are fetched by lazy.nvim on first launch: needs git + network once.

-- 1. bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 1b. a missing treesitter parser must not be an error. Neovim's own ftplugins (lua, vim, markdown...) call
-- vim.treesitter.start(), which asserts when the parser is not installed; this build ships none, and
-- nvim-treesitter below downloads them in the background (needs network and a C compiler once).
do
  local start = vim.treesitter.start
  vim.treesitter.start = function(...)
    return pcall(start, ...)
  end
end

-- 2. options
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.cursorline = true
vim.opt.laststatus = 3
vim.opt.timeoutlen = 300
vim.opt.clipboard = "unnamedplus"   -- system clipboard (needs xclip, installed by the rice)
vim.opt.undofile = true             -- persistent undo
vim.opt.mouse = "a"
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.title = true

-- 3. plugins (no icons: the grimoire's JetBrains Mono is not a Nerd Font)
local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  vim.notify("lazy.nvim is not installed (needs git + network on first run): starting without plugins", vim.log.levels.WARN)
else
lazy.setup({
  -- theme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("tokyonight").setup({ style = "night", terminal_colors = true })
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  -- keybind hints
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },

  -- fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { defaults = { disable_devicons = true } },
  },

  -- file tree (<leader>e)
  {
    "nvim-tree/nvim-tree.lua",
    keys = { { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "File tree" } },
    opts = { renderer = { icons = { show = { file = false, folder = false, folder_arrow = false, git = false } } } },
  },

  -- syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then return end      -- never break startup over a parser problem
      configs.setup({
        -- NVIM_NO_TS_INSTALL=1 (set by nvim-html) skips the parser downloads
        ensure_installed = vim.env.NVIM_NO_TS_INSTALL and {} or { "lua", "bash", "c", "vim", "vimdoc", "markdown", "json", "toml", "yaml" },
        highlight = { enable = true },
      })
    end,
  },

  -- status line
  {
    "nvim-lualine/lualine.nvim",
    opts = { options = { theme = "tokyonight", icons_enabled = false, section_separators = "", component_separators = "|" } },
  },

  -- git gutter + indent guides
  { "lewis6991/gitsigns.nvim", event = "VeryLazy", opts = {} },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", event = "VeryLazy", opts = { indent = { char = "│" } } },
}, { install = { colorscheme = { "tokyonight-night" } }, checker = { enabled = false } })
end

-- 4. keymaps
local map = vim.keymap.set
map("n", "<leader>sc", "<cmd>e $MYVIMRC<CR>",            { desc = "Edit config" })
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>",   { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",    { desc = "Grep (needs ripgrep)" })
map("n", "<leader>bb", "<cmd>Telescope buffers<cr>",      { desc = "List buffers" })
map("n", "<leader>t",  ":vsplit | term<CR>i",             { desc = "Open terminal" })
map("t", "<Esc>",      [[<C-\><C-n>]],                    { desc = "Leave terminal mode" })
map("n", "<leader>w",  "<cmd>w<CR>",                      { desc = "Save" })
map("n", "<leader>q",  "<cmd>q<CR>",                      { desc = "Quit" })
