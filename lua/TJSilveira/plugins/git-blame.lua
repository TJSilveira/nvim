return {
	"f-person/git-blame.nvim",
	event = "BufReadPre",
	keys = {
		{ "<leader>gb", "<cmd>GitBlameToggle<cr>", desc = "Toggle Git Blame" },
		{ "<leader>go", "<cmd>GitBlameOpenCommitURL<cr>", desc = "Open Commit URL" },
		{ "<leader>gs", "<cmd>GitBlameCopySHA<cr>", desc = "Copy Commit SHA" },
		{ "<leader>gu", "<cmd>GitBlameCopyCommitURL<cr>", desc = "Copy Commit URL" },
	},
	opts = {
		enabled = true,
		message_template = " <summary> • <date> • <author> • <<sha>>",
		date_format = "%Y-%m-%d",
		highlight_group = "Comment",
	},
}
