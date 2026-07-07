
local opt = vim.opt

opt.relativenumber = true
opt.number = true
opt.cursorline = true

-- tabs & indentation
opt.tabstop = 4 -- 4 spaces for tabs
opt.shiftwidth = 4 -- 4 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one
opt.wrap = false
vim.opt.scrolloff = 8

-- completion
opt.pumheight = 10 -- max entries visible in the popup menu

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if search is mixed case, assume case-sensitivity

-- clipboard
opt.clipboard:append("unnamedplus") -- use system clipboard as default register