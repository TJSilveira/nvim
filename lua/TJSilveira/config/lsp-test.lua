-- ════════════════════════════════════════════════════════════════════════════
-- LSP test suite / doctor
--
-- Diagnoses whether LSP is actually working in the current buffer. Especially
-- useful inside big monorepos (~/Monorepo) where the usual failure is a wrong
-- root_dir or a server that attaches but never resolves the project.
--
-- Two layers of checking:
--   1. Static  — what each attached server *advertises* (server_capabilities).
--   2. Live    — fire the real request at the cursor and report what comes back.
--
-- Commands:            Keymaps (normal mode):
--   :LspTest             <leader>lt   full report for current buffer
--   :LspTestProbe        <leader>lp   live probe at cursor only
--   :LspInfo? (info)     <leader>li   attached clients + root_dir
-- ════════════════════════════════════════════════════════════════════════════

local M = {}

-- Requests we care about, mapped to the server_capabilities key that advertises
-- them and the keymap you'd use. Order = display order.
local CHECKS = {
	{ req = "textDocument/definition", cap = "definitionProvider", key = "gd", label = "Go to Definition" },
	{ req = "textDocument/declaration", cap = "declarationProvider", key = "gD", label = "Go to Declaration" },
	{ req = "textDocument/references", cap = "referencesProvider", key = "gr", label = "References" },
	{ req = "textDocument/implementation", cap = "implementationProvider", key = "gI", label = "Implementation" },
	{ req = "textDocument/typeDefinition", cap = "typeDefinitionProvider", key = "gy", label = "Type Definition" },
	{ req = "textDocument/hover", cap = "hoverProvider", key = "K", label = "Hover" },
	{ req = "textDocument/rename", cap = "renameProvider", key = "<leader>rn", label = "Rename" },
	{ req = "textDocument/codeAction", cap = "codeActionProvider", key = "<leader>ca", label = "Code Action" },
	{ req = "textDocument/completion", cap = "completionProvider", key = "<C-Space>", label = "Completion" },
	{ req = "textDocument/signatureHelp", cap = "signatureHelpProvider", key = "-", label = "Signature Help" },
	{ req = "textDocument/documentSymbol", cap = "documentSymbolProvider", key = "-", label = "Document Symbols" },
	{ req = "textDocument/formatting", cap = "documentFormattingProvider", key = "-", label = "Formatting" },
	{ req = "textDocument/inlayHint", cap = "inlayHintProvider", key = "<leader>ih", label = "Inlay Hints" },
}

-- Neovim 0.10 renamed get_active_clients -> get_clients. Support both.
local function get_clients(bufnr)
	if vim.lsp.get_clients then
		return vim.lsp.get_clients({ bufnr = bufnr })
	end
	return vim.lsp.get_active_clients({ bufnr = bufnr })
end

-- make_position_params() without an explicit encoding is deprecated in 0.11 and
-- removed in 0.12, so take it from the client that will answer the request.
local function position_params(bufnr)
	local clients = get_clients(bufnr)
	local encoding = clients[1] and clients[1].offset_encoding or "utf-16"
	return vim.lsp.util.make_position_params(0, encoding)
end

-- Fire a real request at the cursor synchronously and describe the result.
-- Returns: ok(boolean), detail(string)
local function probe(bufnr, method)
	local params
	if method == "textDocument/references" then
		params = position_params(bufnr)
		params.context = { includeDeclaration = true }
	elseif method == "textDocument/documentSymbol" then
		params = { textDocument = vim.lsp.util.make_text_document_params() }
	else
		params = position_params(bufnr)
	end

	-- 5s: a cold tsserver in a large monorepo package needs time to finish
	-- building the project graph before it can answer cross-file requests.
	local results, err = vim.lsp.buf_request_sync(bufnr, method, params, 5000)
	if err then
		return false, "error: " .. tostring(err)
	end
	if not results then
		return false, "no response (timeout 5s — server still indexing?)"
	end

	local count = 0
	local got_something = false
	for _, res in pairs(results) do
		if res.error then
			return false, "server error: " .. tostring(res.error.message)
		end
		local r = res.result
		if r ~= nil then
			if type(r) == "table" then
				if r.contents ~= nil then -- hover
					got_something = true
				elseif r.range or r.uri or r.targetUri then -- single location
					got_something = true
					count = count + 1
				elseif #r > 0 then -- list of locations/symbols
					got_something = true
					count = count + #r
				elseif next(r) ~= nil then
					got_something = true
				end
			else
				got_something = true
			end
		end
	end

	if not got_something then
		return false, "empty (cursor not on a resolvable symbol?)"
	end
	if count > 0 then
		return true, count .. " result(s)"
	end
	return true, "responded"
end

-- Build the report lines for the current buffer.
local function build_report(bufnr)
	local lines = {}
	local function add(s)
		table.insert(lines, s or "")
	end

	local fname = vim.api.nvim_buf_get_name(bufnr)
	local ft = vim.bo[bufnr].filetype
	add("LSP Test Report")
	add(string.rep("─", 60))
	add("Buffer:   " .. (fname ~= "" and vim.fn.fnamemodify(fname, ":~") or "[No Name]"))
	add("Filetype: " .. (ft ~= "" and ft or "(none)"))
	add("")

	local clients = get_clients(bufnr)
	if #clients == 0 then
		add("✗ NO LSP CLIENT ATTACHED to this buffer.")
		add("")
		add("  Common causes in a monorepo:")
		add("    • Filetype not recognised (check :set ft?)")
		add("    • Server not installed  → :Mason")
		add("    • root_dir not resolved → open a file with a nearby")
		add("      package.json / tsconfig.json / .git")
		add("    • Server crashed on start → :LspLog")
		return lines
	end

	-- Per-client summary + root_dir (the usual monorepo culprit).
	add("Attached clients (" .. #clients .. "):")
	local warnings = {}
	for _, c in ipairs(clients) do
		local root = c.config.root_dir or (c.root_dir) or "(no root_dir)"
		add(string.format("  • %-16s root: %s", c.name, vim.fn.fnamemodify(root, ":~")))

		-- A TypeScript server rooted at a directory with no tsconfig runs an
		-- "inferred project": hover and same-file jumps still work, but cross-file
		-- navigation and path aliases silently return nothing. This is the single
		-- most common cause of "gd works here but not there" in a monorepo.
		if (c.name == "ts_ls" or c.name == "vtsls") and type(root) == "string" then
			local has_tsconfig = vim.uv.fs_stat(root .. "/tsconfig.json") or vim.uv.fs_stat(root .. "/jsconfig.json")
			if not has_tsconfig then
				table.insert(warnings, "  ! " .. c.name .. " is rooted at a directory with NO tsconfig.json:")
				table.insert(warnings, "      " .. vim.fn.fnamemodify(root, ":~"))
				table.insert(warnings, "    tsserver falls back to an inferred project — cross-file")
				table.insert(warnings, "    definitions and path aliases will not resolve. A nested")
				table.insert(warnings, "    package.json above this file is usually what hijacked the root.")
			end
		end
	end
	if #warnings > 0 then
		add("")
		vim.list_extend(lines, warnings)
	end
	add("")

	-- Static capability matrix.
	add("Advertised capabilities (per server):")
	add(string.rep("─", 60))
	for _, chk in ipairs(CHECKS) do
		local supporters = {}
		for _, c in ipairs(clients) do
			local caps = c.server_capabilities or {}
			if caps[chk.cap] then
				table.insert(supporters, c.name)
			end
		end
		local mark = #supporters > 0 and "✓" or "✗"
		add(string.format("  %s %-18s %-11s %s", mark, chk.label, chk.key, table.concat(supporters, ", ")))
	end

	return lines
end

-- Append live-probe results (requests actually fired at the cursor).
local function append_probe(bufnr, lines)
	local function add(s)
		table.insert(lines, s or "")
	end
	add("")
	add("Live probe at cursor (real requests):")
	add(string.rep("─", 60))

	local probes = {
		{ "textDocument/definition", "Go to Definition" },
		{ "textDocument/references", "References" },
		{ "textDocument/hover", "Hover" },
		{ "textDocument/implementation", "Implementation" },
		{ "textDocument/typeDefinition", "Type Definition" },
		{ "textDocument/documentSymbol", "Document Symbols" },
	}
	local res = {}
	for _, p in ipairs(probes) do
		local ok, detail = probe(bufnr, p[1])
		-- A cold tsserver answers hover from the open file long before the project
		-- graph is ready, so a single empty definition result proves nothing. Retry
		-- these two for ~15s before calling them broken.
		if not ok and (p[1] == "textDocument/definition" or p[1] == "textDocument/references") then
			for _ = 1, 5 do
				vim.wait(2000, function() return false end, 100)
				ok, detail = probe(bufnr, p[1])
				if ok then
					detail = detail .. " (after retry — server was still indexing)"
					break
				end
			end
		end
		res[p[1]] = ok
		add(string.format("  %s %-18s %s", ok and "✓" or "✗", p[2], detail))
	end

	-- Interpret the pattern instead of just showing raw ticks.
	add("")
	local server_alive = res["textDocument/hover"] or res["textDocument/documentSymbol"]
	local xfile_ok = res["textDocument/definition"] or res["textDocument/references"]
	if server_alive and not xfile_ok then
		add("→ Server is ALIVE (hover/symbols work) but cross-file navigation")
		add("  came back empty/timeout. Almost always means the project graph")
		add("  is still being built on a cold start. What to do:")
		add("    1. Wait ~10-30s for tsserver to finish indexing, then re-probe")
		add("       with <leader>lp (no restart needed).")
		add("    2. Probe with the cursor on an IMPORTED identifier (something")
		add("       defined in another file) — that exercises the project graph.")
		add("    3. If it still fails when warm, check :LspLog for tsserver")
		add("       errors and confirm the file is included by Api/tsconfig.json.")
	elseif not server_alive then
		add("→ Server did not answer even hover/symbols. It may still be starting,")
		add("  or the cursor is in an empty/non-code buffer. Re-probe shortly.")
	else
		add("→ Cross-file navigation is working. LSP looks healthy here.")
	end
	add("")
	add("(Put the cursor ON a symbol before probing for meaningful results.)")
end

-- Open the report in a scratch floating window.
local function show(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "lspinfo"
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
		title = " LSP Test ",
		title_pos = "center",
	})
	vim.wo[win].wrap = false
	for _, k in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", k, "<cmd>close<CR>", { buffer = buf, nowait = true, silent = true })
	end
end

-- Full report: static matrix + live probe.
function M.test(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = build_report(bufnr)
	if #get_clients(bufnr) > 0 then
		append_probe(bufnr, lines)
	end
	show(lines)
end

-- Just the live probe (fast, assumes a client is attached).
function M.probe_only(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if #get_clients(bufnr) == 0 then
		vim.notify("No LSP client attached to this buffer.", vim.log.levels.WARN)
		return
	end
	local lines = { "LSP Live Probe", string.rep("─", 40) }
	append_probe(bufnr, lines)
	show(lines)
end

-- Quick clients + root_dir summary (notify, no window).
function M.info(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local clients = get_clients(bufnr)
	if #clients == 0 then
		vim.notify("No LSP client attached.", vim.log.levels.WARN)
		return
	end
	local parts = {}
	for _, c in ipairs(clients) do
		local root = c.config.root_dir or "?"
		table.insert(parts, string.format("%s → %s", c.name, vim.fn.fnamemodify(root, ":~")))
	end
	vim.notify(table.concat(parts, "\n"), vim.log.levels.INFO, { title = "LSP clients" })
end

function M.setup()
	vim.api.nvim_create_user_command("LspTest", function()
		M.test()
	end, { desc = "LSP: full test report for current buffer" })
	vim.api.nvim_create_user_command("LspTestProbe", function()
		M.probe_only()
	end, { desc = "LSP: live probe at cursor" })
	vim.api.nvim_create_user_command("LspTestInfo", function()
		M.info()
	end, { desc = "LSP: attached clients + root_dir" })

	vim.keymap.set("n", "<leader>lt", M.test, { desc = "LSP: Test report" })
	vim.keymap.set("n", "<leader>lp", M.probe_only, { desc = "LSP: Live probe at cursor" })
	vim.keymap.set("n", "<leader>li", M.info, { desc = "LSP: Clients + root_dir" })
end

return M
