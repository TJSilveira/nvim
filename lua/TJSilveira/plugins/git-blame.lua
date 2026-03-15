return {
	"f-person/git-blame.nvim",
	event = "BufReadPre",
	keys = {
		{ "<leader>Gb", "<cmd>GitBlameToggle<cr>", desc = "Toggle Git Blame" },
		{ "<leader>Gbo", "<cmd>GitBlameOpenCommitURL<cr>", desc = "Open Commit URL" },
		{ "<leader>Gbc", "<cmd>GitBlameCopySHA<cr>", desc = "Copy Commit SHA" },
		{ "<leader>Gbs", "<cmd>GitBlameCopyCommitURL<cr>", desc = "Copy Commit URL" },
	},
	opts = {
		enabled = true,
		message_template = " <summary> • <date> • <author> • <<sha>>",
		date_format = "%Y-%m-%d",
		virtual_text_column = 80, -- align blame text at column 80
		highlight_group = "Comment",
	},
}
