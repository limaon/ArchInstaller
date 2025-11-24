-- ~/.config/nvim/init.lua - Neovim configuration for all environments
-- Based on ArchWiki: https://wiki.archlinux.org/title/Neovim
-- Lua configuration format (Neovim 0.5+)

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

-- Neovim is always nocompatible (no need to set)
-- Enable file type detection, plugins, and indentation
vim.cmd('filetype plugin indent on')

-- Enable syntax highlighting
vim.cmd('syntax on')

-- Enable true color support (if terminal supports it)
vim.opt.termguicolors = true

-- ============================================================================
-- DISPLAY OPTIONS
-- ============================================================================

-- Show line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Show cursor line
vim.opt.cursorline = true

-- Show matching brackets
vim.opt.showmatch = true

-- Show command in bottom bar
vim.opt.showcmd = true

-- Show mode in status line
vim.opt.showmode = true

-- Always show status line
vim.opt.laststatus = 2

-- Display whitespace characters
vim.opt.list = true
vim.opt.listchars = "tab:▸ ,trail:·,extends:»,precedes:«,nbsp:%"

-- ============================================================================
-- EDITING OPTIONS
-- ============================================================================

-- Enable auto-indentation
vim.opt.autoindent = true
vim.opt.smartindent = true

-- Tab settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smarttab = true

-- Wrap lines
vim.opt.wrap = true
vim.opt.linebreak = true

-- Text width
vim.opt.textwidth = 80
vim.opt.colorcolumn = "81"

-- Allow backspace over everything
vim.opt.backspace = "indent,eol,start"

-- ============================================================================
-- SEARCH OPTIONS
-- ============================================================================

-- Incremental search
vim.opt.incsearch = true

-- Highlight search results
vim.opt.hlsearch = true

-- Case-insensitive search (unless pattern contains uppercase)
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- ============================================================================
-- PERFORMANCE
-- ============================================================================

-- Faster scrolling
vim.opt.ttyfast = true

-- Lazy redraw
vim.opt.lazyredraw = true

-- ============================================================================
-- BACKUP AND UNDO
-- ============================================================================

-- Disable swap files
vim.opt.swapfile = false

-- Disable backup files
vim.opt.backup = false
vim.opt.writebackup = false

-- Persistent undo (if desired, uncomment)
-- vim.opt.undofile = true
-- vim.opt.undodir = vim.fn.expand("~/.config/nvim/undo")

-- ============================================================================
-- SECURITY
-- ============================================================================

-- Disable modelines (security)
vim.opt.modeline = false

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Clear search highlighting
vim.keymap.set("n", "<leader>h", ":nohlsearch<CR>", { noremap = true, silent = true })

-- ============================================================================
-- PLUGINS (if using plugin manager)
-- ============================================================================

-- Example: lazy.nvim
-- local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- if not vim.loop.fs_stat(lazypath) then
--     vim.fn.system({
--         "git",
--         "clone",
--         "--filter=blob:none",
--         "https://github.com/folke/lazy.nvim.git",
--         "--branch=stable",
--         lazypath,
--     })
-- end
-- vim.opt.rtp:prepend(lazypath)
-- require("lazy").setup({})

-- Example: vim-plug
-- vim.cmd('call plug#begin("~/.config/nvim/plugged")')
-- vim.cmd("Plug 'plugin-name'")
-- vim.cmd('call plug#end()')

-- ============================================================================
-- END OF CONFIGURATION
-- ============================================================================

