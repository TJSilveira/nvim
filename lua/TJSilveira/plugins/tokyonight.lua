return
{
	"folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	opts = {
		style = "night",
		styles = {
		functions = {},
		variables = {},
		sidebars = "dark",
		floats = "dark",
	},

	sidebars = { "qf", "help", "terminal" },
	},

	config = function(_, opts)
		require("tokyonight").setup(opts)
		vim.cmd("colorscheme tokyonight")
	end,
}