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

		local prettier_bin = util.find_executable({ "node_modules/.bin/prettier" }, "")
		local prettier_configs = {
			".prettierrc",
			".prettierrc.json",
			".prettierrc.json5",
			".prettierrc.yaml",
			".prettierrc.yml",
			".prettierrc.toml",
			".prettierrc.js",
			".prettierrc.cjs",
			".prettierrc.mjs",
			".prettierrc.ts",
			"prettier.config.js",
			"prettier.config.cjs",
			"prettier.config.mjs",
			"prettier.config.ts",
		}

		-- Mason keeps a prettier on PATH and from_node_modules falls back to it, so
		-- without this gate prettier reformats repos that never adopted it and their
		-- own linter rejects the result.
		conform.formatters.prettier = {
			condition = function(self, ctx)
				return prettier_bin(self, ctx) ~= ""
					or vim.fs.find(prettier_configs, { upward = true, path = ctx.dirname })[1] ~= nil
			end,
		}

		local eslint_bin = util.find_executable({ "node_modules/.bin/eslint" }, "")
		local eslint_configs = {
			"eslint.config.js",
			"eslint.config.mjs",
			"eslint.config.cjs",
			"eslint.config.ts",
			"eslint.config.mts",
			"eslint.config.cts",
			".eslintrc",
			".eslintrc.js",
			".eslintrc.cjs",
			".eslintrc.json",
			".eslintrc.yaml",
			".eslintrc.yml",
		}

		-- Repos that lint-as-format (@antfu/eslint-config) ship no prettier; without
		-- an eslint step the chain falls through to ts_ls, whose double quotes and
		-- semicolons are exactly what eslint flags on the next run.
		-- eslint exits 1 whenever an unfixable error remains, which says nothing
		-- about whether the fixes it did apply are good.
		conform.formatters.eslint = {
			command = eslint_bin,
			args = { "--fix", "$FILENAME" },
			stdin = false,
			exit_codes = { 0, 1 },
			condition = function(self, ctx)
				return eslint_bin(self, ctx) ~= ""
					and vim.fs.find(eslint_configs, { upward = true, path = ctx.dirname })[1] ~= nil
			end,
		}

		-- from_node_modules only resolves these where the project depends on them, so
		-- prettier and prismals keep working in repos that have not adopted them.
		local web = { "oxfmt", "prettier", "eslint", stop_after_first = true }

		-- The Prisma CLI is a Node process formatting an 18k-line schema, and eslint
		-- is a full Node startup plus config resolution; both need several times the
		-- budget that suffices for the native formatters.
		local slow_formatters = { prisma = true, eslint = true }

		local function format_opts(bufnr)
			local timeout_ms = 500
			for _, formatter in ipairs(conform.list_formatters_to_run(bufnr)) do
				if slow_formatters[formatter.name] then
					timeout_ms = 3000
				end
			end
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
