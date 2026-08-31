return {
	"kevinhwang91/nvim-ufo",
	dependencies = "kevinhwang91/promise-async",
	event = { "BufReadPost", "BufNewFile" },

	init = function()
		vim.opt.foldcolumn = "1"
		vim.opt.foldlevel = 99 -- ufo needs a high foldlevel; it opens/closes folds itself
		vim.opt.foldlevelstart = 99
		vim.opt.foldenable = true
		vim.opt.fillchars:append({ fold = " ", foldopen = "▾", foldclose = "▸", foldsep = " " })
	end,

	keys = {
		{ "zR", function() require("ufo").openAllFolds() end, desc = "Open all folds" },
		{ "zM", function() require("ufo").closeAllFolds() end, desc = "Close all folds" },
		{ "zr", function() require("ufo").openFoldsExceptKinds() end, desc = "Open folds except kinds" },
		{ "zm", function() require("ufo").closeFoldsWith() end, desc = "Close folds with level" },
		{
			"zK",
			function()
				if not require("ufo").peekFoldedLinesUnderCursor() then
					vim.lsp.buf.hover()
				end
			end,
			desc = "Peek folded lines",
		},
	},

	opts = {
		open_fold_hl_timeout = 0,

		-- Treesitter gives the real syntactic ranges ({} blocks, functions,
		-- classes) without needing a language server; indent covers the rest.
		provider_selector = function()
			return { "treesitter", "indent" }
		end,

		fold_virt_text_handler = function(virt_text, lnum, end_lnum, width, truncate)
			local suffix = ("  󰇘 %d lines"):format(end_lnum - lnum)
			local target = width - vim.fn.strdisplaywidth(suffix)
			local result, cur_width = {}, 0

			for _, chunk in ipairs(virt_text) do
				local text, hl = chunk[1], chunk[2]
				local chunk_width = vim.fn.strdisplaywidth(text)
				if target > cur_width + chunk_width then
					table.insert(result, chunk)
				else
					text = truncate(text, target - cur_width)
					table.insert(result, { text, hl })
					break
				end
				cur_width = cur_width + chunk_width
			end

			table.insert(result, { suffix, "MoreMsg" })
			return result
		end,
	},
}
