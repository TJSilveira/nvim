return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		event = { "BufReadPre", "BufNewFile" },
		build = ":TSUpdate",

		config = function()
			local treesitter = require("nvim-treesitter.configs")
			treesitter.setup({
				-- A list of parser names, or "all" (the listed parsers MUST always be installed)
				ensure_installed = {
					"c",
					"json",
					"go",
					"rust",
					"sql",
					"bash",
					"csv",
					"lua",
					"vim",
					"vimdoc",
					"query",
					"markdown",
					"markdown_inline",
				},

				-- Automatically install missing parsers when entering buffer
				-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
				auto_install = true,

				highlight = {
					enable = true,
					disable = function(lang, buf)
						local max_filesize = 100 * 1024 -- 100 KB
						local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
						if ok and stats and stats.size > max_filesize then
							return true
						end
					end,
					additional_vim_regex_highlighting = true,
				},
			})
		end,
	},
}

