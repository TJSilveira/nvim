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

		-- prismals bundles its own Prisma version, which formats differently from the
		-- one the repo pins; running the project's CLI keeps saves and CI in sync.
		conform.formatters.prisma = {
			command = util.from_node_modules("prisma"),
			args = { "format", "--schema", "$FILENAME" },
			stdin = false,
		}

		-- from_node_modules only resolves these where the project depends on them, so
		-- prettier and prismals keep working in repos that have not adopted them.
		local web = { "oxfmt", "prettier", stop_after_first = true }

		-- The Prisma CLI is a Node process formatting an 18k-line schema; it needs
		-- several times the budget that suffices for the native formatters.
		local function format_opts(bufnr)
			local timeout_ms = vim.bo[bufnr or 0].filetype == "prisma" and 3000 or 500
			return { timeout_ms = timeout_ms, lsp_format = "fallback" }
		end

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
				prisma = { "prisma" },
				lua = { "stylua" },
				go = { "gofmt" },
				rust = { "rustfmt" },
				python = { "black" },
				sh = { "shfmt" },
			},
			format_on_save = function(bufnr)
				return format_opts(bufnr)
			end,
		})

		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			conform.format(format_opts())
		end, { desc = "Format file or range (in visual mode)" })
	end,
}
