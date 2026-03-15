-- bootstrap lazy.nvim, LazyVim and your plugins
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.g.mapleader = " " -- Space as leader
require("TJSilveira.lazy")
require("TJSilveira.config")
