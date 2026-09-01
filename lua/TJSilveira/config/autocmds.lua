-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- lazygit's custom `e` command opens the file in a new tab of this same nvim,
-- which pulls focus out of the lazygit terminal and drops it back to normal
-- mode. Without this, returning to the lazygit tab sends every keypress to Vim
-- instead of to lazygit.
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
	pattern = "term://*",
	callback = function(args)
		if vim.api.nvim_buf_get_name(args.buf):find("lazygit", 1, true) then
			vim.cmd.startinsert()
		end
	end,
})
