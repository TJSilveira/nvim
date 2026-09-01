return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		signs = {
			add = { text = "▎" },
			change = { text = "▎" },
			delete = { text = "" },
			topdelete = { text = "" },
			changedelete = { text = "▎" },
			untracked = { text = "▎" },
		},
		signcolumn = true,
		current_line_blame = false,
	},
	keys = {
		{ "]c", "<cmd>Gitsigns next_hunk<cr>", desc = "Next Git Hunk" },
		{ "[c", "<cmd>Gitsigns prev_hunk<cr>", desc = "Previous Git Hunk" },
		{ "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>", desc = "Preview Hunk" },
		{ "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>", desc = "Reset Hunk" },
		{ "<leader>gS", "<cmd>Gitsigns stage_hunk<cr>", desc = "Stage Hunk" },
	},
}
