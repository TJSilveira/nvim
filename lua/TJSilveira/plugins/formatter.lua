return
{
    "stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
    config = function ()
        local conform = require("conform")

        conform.setup({
            formatters_by_ft = {
            lua = { "stylua" },
            clang = { "prettier" },
            rust = { "rustfmt" },
            html = { "prettier" },
            },
            format_on_save = {
                timeout_ms = 500,
                lsp_format = "fallback",
            },
        })

        vim.keymap.set({"n", "v"}, "<leader>mp", function ()
                conform.format({
                    timeout_ms = 500,
                    lsp_format = "fallback",
                })
        end, {desc = "Format file or range (in visual mode)"})
    end,
}
