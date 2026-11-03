local SearchIgnore = require("common.SearchIgnore")

local LSP_TIMEOUT_MS = 1500

local M = {}

---@param bufnr number
---@return vim.lsp.Client[]
local function clients_supporting_references(bufnr)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	---@type vim.lsp.Client[]
	local supporting_clients = {}

	for _, client in ipairs(clients) do
		if client:supports_method("textDocument/references") then
			supporting_clients[#supporting_clients + 1] = client
		end
	end

	return supporting_clients
end

---@param bufnr number
---@param winid number
---@param timeout number
---@param callback fun(items: table[])
---@return function
function M.collect_lsp(bufnr, winid, timeout, callback)
	local clients = clients_supporting_references(bufnr)

	if #clients == 0 then
		callback({})
		return function() end
	end

	local items = {}
	local remaining_clients = #clients
	local finished = false

	local function finish_lsp()
		if finished then
			return
		end

		finished = true
		callback(items)
	end

	local timer = vim.fn.timer_start(timeout or LSP_TIMEOUT_MS, finish_lsp)

	local function mark_client_done()
		remaining_clients = remaining_clients - 1

		if remaining_clients <= 0 then
			vim.fn.timer_stop(timer)
			finish_lsp()
		end
	end

	for _, client in ipairs(clients) do
		local params = vim.tbl_extend("force", vim.lsp.util.make_position_params(winid, client.offset_encoding), {
			context = { includeDeclaration = true },
		})

		local ok = client:request("textDocument/references", params, function(err, result)
			if finished then
				return
			end

			if not err and type(result) == "table" then
				for _, item in ipairs(vim.lsp.util.locations_to_items(result, client.offset_encoding)) do
					if item.filename and not SearchIgnore.is_ignored(item.filename) then
						items[#items + 1] = {
							filename = item.filename,
							lnum = item.lnum,
							col = item.col,
							text = item.text or "",
							source = "lsp",
						}
					end
				end
			end

			mark_client_done()
		end, bufnr)

		if not ok then
			mark_client_done()
		end
	end

	return function()
		finished = true

		if timer then
			pcall(vim.fn.timer_stop, timer)
		end
	end
end

---@param query string
---@param opts {cwd?: string, word?: boolean}
---@param callback fun(items: table[])
function M.collect_rg(query, opts, callback)
	if vim.fn.executable("rg") ~= 1 then
		callback({})
		return
	end

	local args = {
		"rg",
		"--json",
		"--hidden",
		"--no-messages",
		"--fixed-strings",
		"--max-columns=4096",
	}

	if opts.word then
		args[#args + 1] = "--word-regexp"
	end

	vim.list_extend(args, SearchIgnore.rg_args())
	vim.list_extend(args, { "--", query })

	local cwd = opts.cwd or vim.fn.getcwd()

	local on_exit = vim.schedule_wrap(function(process)
		if process.code ~= 0 and process.code ~= 1 then
			callback({})
			return
		end

		local items = {}

		for line in (process.stdout or ""):gmatch("[^\n]+") do
			local ok, event = pcall(vim.json.decode, line)

			if ok and event.type == "match" then
				local data = event.data
				local path = data.path and data.path.text
				local submatch = data.submatches and data.submatches[1]
				local text = data.lines and data.lines.text or ""

				if path and not SearchIgnore.is_ignored(path) then
					items[#items + 1] = {
						filename = vim.fn.fnamemodify(path, ":p"),
						lnum = data.line_number,
						col = submatch and (submatch.start + 1) or 1,
						text = text:gsub("[\r\n]+$", ""),
						source = "rg",
					}
				end
			end
		end

		callback(items)
	end)

	local ok = pcall(vim.system, args, { cwd = cwd, text = true }, on_exit)

	if not ok then
		callback({})
	end
end

---@param lsp_items table[]
---@param rg_items table[]
---@return table[]
function M.merge(lsp_items, rg_items)
	local seen = {}
	local merged = {}

	local function add(item)
		local key = string.format("%s:%d:%d", item.filename, item.lnum or 0, item.col or 0)

		if seen[key] then
			return
		end

		seen[key] = true
		merged[#merged + 1] = item
	end

	for _, item in ipairs(lsp_items) do
		add(item)
	end

	for _, item in ipairs(rg_items) do
		add(item)
	end

	table.sort(merged, function(a, b)
		if a.filename ~= b.filename then
			return a.filename < b.filename
		end

		if a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end

		return (a.col or 0) < (b.col or 0)
	end)

	return merged
end

---@param query string
---@param opts {bufnr: number, winid: number, word?: boolean, cwd?: string, timeout?: number}
---@param callback fun(items: table[])
---@return function
function M.collect(query, opts, callback)
	local lsp_items = {}
	local rg_items = {}
	local lsp_done = false
	local rg_done = false
	local finished = false

	local function finish()
		if finished or not lsp_done or not rg_done then
			return
		end

		finished = true
		callback(M.merge(lsp_items, rg_items))
	end

	local cancel_lsp = M.collect_lsp(opts.bufnr, opts.winid, opts.timeout, function(items)
		lsp_items = items
		lsp_done = true
		finish()
	end)

	M.collect_rg(query, { cwd = opts.cwd, word = opts.word }, function(items)
		rg_items = items
		rg_done = true
		finish()
	end)

	return function()
		finished = true
		cancel_lsp()
	end
end

return M
