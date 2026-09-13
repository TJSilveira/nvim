-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<F1>", "Stdheader<CR>", {silent = true})

-- Tabs: gt/gT are builtin for cycling, these cover create/delete.
vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tx", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<cr>", { desc = "Close other tabs" })

-- Window size: <leader>w rather than <C-arrow>, which the file tree already uses.
-- Step of 5 keeps the repetition down since these need a prefix each time.
vim.keymap.set("n", "<leader>wh", "<cmd>vertical resize -5<cr>", { desc = "Narrow window" })
vim.keymap.set("n", "<leader>wl", "<cmd>vertical resize +5<cr>", { desc = "Widen window" })
vim.keymap.set("n", "<leader>wk", "<cmd>resize +5<cr>", { desc = "Taller window" })
vim.keymap.set("n", "<leader>wj", "<cmd>resize -5<cr>", { desc = "Shorter window" })
vim.keymap.set("n", "<leader>w=", "<C-w>=", { desc = "Equalize windows" })
vim.keymap.set("n", "<leader>wm", "<cmd>vertical resize 120<cr>", { desc = "Max width" })
