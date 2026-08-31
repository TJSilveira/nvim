-- ════════════════════════════════════════════════════════════════════════════
-- Fold test suite / doctor
--
-- Diagnoses why folding (nvim-ufo) is not working in the current buffer. The
-- usual failures are: ufo never attached to the window, no treesitter parser
-- for the filetype, or the buffer was opened before the plugin loaded — all of
-- which surface as "E490: No fold found" on za/zc.
--
-- Commands:            Keymaps (normal mode):
--   :FoldTest            <leader>zt   full report for current buffer
--   :FoldRefresh         <leader>zf   force ufo to recompute this buffer's folds
-- ════════════════════════════════════════════════════════════════════════════

local M = {}

local function mark(ok)
	return ok and "✓" or "✗"
end

local function ufo()
	local ok, mod = pcall(require, "ufo")
	if ok then
		return mod
	end
end

-- Which provider ufo actually settled on for this buffer, straight from its
-- internal fold buffer (there is no public API for it).
local function ufo_providers(bufnr)
	local ok, manager = pcall(require, "ufo.fold.manager")
	if not ok then
		return nil
	end
	local fb = manager:get(bufnr)
	return fb and fb.providers or nil
end

local function count_folds(bufnr)
	local total, deepest = 0, 0
	for lnum = 1, vim.api.nvim_buf_line_count(bufnr) do
		local level = vim.fn.foldlevel(lnum)
		deepest = math.max(deepest, level)
		if level > vim.fn.foldlevel(lnum - 1) then
			total = total + 1
		end
	end
	return total, deepest
end

local function build_report(bufnr)
	local lines = { "Fold Test", string.rep("─", 46) }
	local function add(fmt, ...)
		table.insert(lines, select("#", ...) > 0 and string.format(fmt, ...) or fmt)
	end

	local ft = vim.bo[bufnr].filetype
	add("buffer   %s", vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:."))
	add("filetype %s", ft ~= "" and ft or "(none)")
	add("")

	local u = ufo()
	add("%s nvim-ufo loaded", mark(u ~= nil))
	if not u then
		add("  → plugin not loaded: :Lazy load nvim-ufo")
	end

	local providers = ufo_providers(bufnr)
	add("%s ufo attached to buffer", mark(providers ~= nil))
	if providers then
		add("  providers: %s", table.concat(providers, " → "))
		if providers[1] == "" then
			add("  → folding is disabled for this filetype by provider_selector")
		end
	elseif u then
		add("  → buffer opened before ufo loaded; try :FoldRefresh or :e")
	end

	local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	add("%s treesitter parser for %s", mark(parser_ok and parser ~= nil), ft ~= "" and ft or "?")
	if not (parser_ok and parser) then
		add("  → :TSInstall %s (ufo falls back to indent folding)", ft)
	end

	add("")
	add("options")
	add("  foldmethod    %s   (ufo uses 'manual' by design)", vim.wo.foldmethod)
	add("  foldexpr      %s", vim.wo.foldexpr ~= "" and vim.wo.foldexpr or "(unset)")
	add("  foldenable    %s", tostring(vim.wo.foldenable))
	add("  foldlevel     %d   (99 = everything open, expected)", vim.wo.foldlevel)
	add("  foldcolumn    %s", vim.wo.foldcolumn)

	local total, deepest = count_folds(bufnr)
	add("")
	add("%s folds computed: %d (max nesting %d)", mark(total > 0), total, deepest)

	local cursor = vim.api.nvim_win_get_cursor(0)[1]
	local level = vim.fn.foldlevel(cursor)
	add("%s fold at cursor (line %d): level %d%s", mark(level > 0), cursor, level, vim.fn.foldclosed(cursor) ~= -1 and ", closed" or "")
	if level == 0 then
		add("  → za here would raise E490; the line is outside any fold range")
	end

	if total == 0 then
		add("")
		add("nothing folds: run :FoldRefresh, then re-run :FoldTest")
	end

	return lines
end

local function show(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(width + 2, vim.o.columns - 4)
	local height = math.min(#lines + 1, vim.o.lines - 4)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " Fold Test ",
		title_pos = "center",
	})
	vim.wo[win].wrap = false
	for _, k in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", k, "<cmd>close<CR>", { buffer = buf, nowait = true, silent = true })
	end
end

function M.test(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	show(build_report(bufnr))
end

-- Detach and re-attach ufo so it recomputes folds for the current window. Fixes
-- buffers that were already open when the plugin loaded.
function M.refresh()
	local u = ufo()
	if not u then
		vim.notify("nvim-ufo is not loaded.", vim.log.levels.WARN)
		return
	end
	u.detach()
	u.attach()
	vim.notify("ufo re-attached to this buffer.", vim.log.levels.INFO, { title = "Fold" })
end

function M.setup()
	vim.api.nvim_create_user_command("FoldTest", function()
		M.test()
	end, { desc = "Fold: full test report for current buffer" })
	vim.api.nvim_create_user_command("FoldRefresh", function()
		M.refresh()
	end, { desc = "Fold: re-attach ufo and recompute folds" })

	vim.keymap.set("n", "<leader>zt", M.test, { desc = "Fold: Test report" })
	vim.keymap.set("n", "<leader>zf", M.refresh, { desc = "Fold: Re-attach ufo" })
end

return M
