return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- completions from current buffer text
		"hrsh7th/cmp-path", -- completions for file system paths
		"hrsh7th/cmp-nvim-lsp", -- LSP-powered completions
		"hrsh7th/cmp-nvim-lua", -- Neovim Lua API completions
		"hrsh7th/cmp-cmdline", -- completions in : and / command line
		"L3MON4D3/LuaSnip", -- snippet engine
		"saadparwaiz1/cmp_luasnip", -- LuaSnip completion source for cmp
		"rafamadriz/friendly-snippets", -- pre-built snippet collection for many languages
	},
	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")

		-- load friendly-snippets into LuaSnip
		require("luasnip.loaders.from_vscode").lazy_load()

		-- make LuaSnip aware of jumps between snippet nodes
		luasnip.config.setup({
			history = true,
			updateevents = "TextChanged,TextChangedI",
		})

		-- ─── Kind icons ───────────────────────────────────────────────────────────
		local kind_icons = {
			Text = "󰉿",
			Method = "󰆧",
			Function = "󰊕",
			Constructor = "",
			Field = "󰜢",
			Variable = "󰀫",
			Class = "󰠱",
			Interface = "",
			Module = "",
			Property = "󰜢",
			Unit = "󰑭",
			Value = "󰎠",
			Enum = "",
			Keyword = "󰌋",
			Snippet = "",
			Color = "󰏘",
			File = "󰈙",
			Reference = "󰈇",
			Folder = "󰉋",
			EnumMember = "",
			Constant = "󰏿",
			Struct = "󰙅",
			Event = "",
			Operator = "󰆕",
			TypeParameter = "",
		}

		-- ─── Main cmp setup ───────────────────────────────────────────────────────
		cmp.setup({
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},

			completion = {
				completeopt = "menu,menuone,preview,noselect",
			},

			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},

			-- ─── Keymaps ────────────────────────────────────────────────────────────
			mapping = cmp.mapping.preset.insert({
				["<C-k>"] = cmp.mapping.select_prev_item(), -- prev suggestion
				["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
				["<C-b>"] = cmp.mapping.scroll_docs(-4), -- scroll docs up
				["<C-f>"] = cmp.mapping.scroll_docs(4), -- scroll docs down
				["<C-Space>"] = cmp.mapping.complete(), -- trigger completion
				["<C-e>"] = cmp.mapping.abort(), -- close completion
				["<CR>"] = cmp.mapping.confirm({ select = false }), -- confirm (only if explicitly selected)

				-- Tab: confirm snippet / jump forward / select next
				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif luasnip.expand_or_jumpable() then
						luasnip.expand_or_jump()
					else
						fallback()
					end
				end, { "i", "s" }),

				-- Shift-Tab: jump backward through snippet nodes
				["<S-Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					elseif luasnip.jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end, { "i", "s" }),
			}),

			-- ─── Sources (ordered by priority) ──────────────────────────────────────
			sources = cmp.config.sources({
				{ name = "nvim_lsp", priority = 1000 },
				{ name = "luasnip", priority = 750 },
				{ name = "nvim_lua", priority = 500 },
				{ name = "buffer", priority = 250 },
				{ name = "path", priority = 200 },
			}),

			-- ─── Formatting ──────────────────────────────────────────────────────────
			formatting = {
				expandable_indicator = true,
				fields = { "kind", "abbr", "menu" },
				format = function(entry, vim_item)
					-- kind icon
					vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)
					-- source label
					vim_item.menu = ({
						nvim_lsp = "[LSP]",
						luasnip = "[Snippet]",
						nvim_lua = "[Lua]",
						buffer = "[Buffer]",
						path = "[Path]",
					})[entry.source.name] or ""
					return vim_item
				end,
			},

			-- disable completion in comments
			enabled = function()
				local ctx = require("cmp.config.context")
				if vim.api.nvim_get_mode().mode == "c" then
					return true
				end
				return not ctx.in_treesitter_capture("comment") and not ctx.in_syntax_group("Comment")
			end,
		})

		-- ─── Cmdline completions ──────────────────────────────────────────────────
		-- "/" search completions from buffer
		cmp.setup.cmdline("/", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = { { name = "buffer" } },
		})

		-- ":" command completions
		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
		})
	end,
}
