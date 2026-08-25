return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")
		local util = require("conform.util")

		-- oxfmt discovers .oxfmtrc.json from its process cwd, NOT from
		-- --stdin-filepath. Without an explicit cwd it silently formats with library
		-- defaults (printWidth 80) instead of the repo's settings.
		conform.formatters.oxfmt = {
			command = util.from_node_modules("oxfmt"),
			args = { "--stdin-filepath", "$FILENAME" },
			stdin = true,
			cwd = util.root_file({ ".oxfmtrc.json", ".oxfmtrc.jsonc" }),
		}

		-- from_node_modules only resolves oxfmt where the project depends on it, so
		-- prettier keeps working in repos that have not moved to oxc.
		local web = { "oxfmt", "prettier", stop_after_first = true }

		conform.setup({
			formatters_by_ft = {
				javascript = web,
				typescript = web,
				javascriptreact = web,
				typescriptreact = web,
				css = web,
				scss = web,
				html = web,
				json = web,
				jsonc = web,
				yaml = web,
				markdown = web,
				graphql = web,
				lua = { "stylua" },
				go = { "gofmt" },
				rust = { "rustfmt" },
				python = { "black" },
				sh = { "shfmt" },
			},
			format_on_save = {
				timeout_ms = 500,
				lsp_format = "fallback",
			},
		})

		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			conform.format({
				timeout_ms = 500,
				lsp_format = "fallback",
			})
		end, { desc = "Format file or range (in visual mode)" })
	end,
}
