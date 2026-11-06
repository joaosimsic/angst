local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local function make_buffer(name)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, name)
	return bufnr
end

local function make_item(bufnr, lnum, col, severity, message, source)
	return {
		bufnr = bufnr,
		lnum = lnum,
		col = col,
		severity = severity,
		message = message,
		source = source,
		key = table.concat({ bufnr, lnum, col, severity, message }, ":"),
	}
end

local function row_signature(row)
	if row.kind == "diagnostic" then
		return string.format("diag:%d:%d:%d", row.item.lnum, row.item.col, row.item.severity)
	elseif row.kind == "line" then
		return "line:" .. row.label
	elseif row.kind == "file" then
		return "file:" .. row.label .. ":" .. tostring(row.indent)
	elseif row.kind == "folder" then
		return "folder:" .. row.name .. ":" .. row.dir
	elseif row.kind == "separator" then
		return "separator:" .. row.label
	end
	return row.kind
end

return function()
	describe("diagnostics history grouping", function()
		it("puts current buffer first and groups the rest by folder and line", function()
			package.loaded["frontend.tools.diagnostics-history.layout"] = nil
			local layout = require("frontend.tools.diagnostics-history.layout")

			local current = make_buffer("/repo/app/src/current.lua")
			local a = make_buffer("/repo/app/src/a.lua")
			local b = make_buffer("/repo/app/src/b.lua")
			local root = make_buffer("/repo/README.md")
			local items = {
				make_item(current, 10, 4, vim.diagnostic.severity.ERROR, "e", "lua"),
				make_item(current, 10, 0, vim.diagnostic.severity.WARN, "w", "lua"),
				make_item(current, 2, 2, vim.diagnostic.severity.INFO, "i", "lua"),
				make_item(a, 5, 1, vim.diagnostic.severity.WARN, "aw", "lua"),
				make_item(b, 7, 0, vim.diagnostic.severity.HINT, "bh", "lua"),
				make_item(root, 0, 0, vim.diagnostic.severity.INFO, "ri", "lua"),
			}

			local rows = layout.build(items, current, "/repo")
			local got = {}
			for _, row in ipairs(rows) do
				got[#got + 1] = row_signature(row)
			end
			assert(vim.inspect(got) == vim.inspect({
				"separator:CURRENT",
				"file:app/src/current.lua:0",
				"line:3",
				string.format("diag:2:2:%d", vim.diagnostic.severity.INFO),
				"line:11",
				string.format("diag:10:0:%d", vim.diagnostic.severity.WARN),
				string.format("diag:10:4:%d", vim.diagnostic.severity.ERROR),
				"blank",
				"file:README.md:0",
				"line:1",
				string.format("diag:0:0:%d", vim.diagnostic.severity.INFO),
				"folder:src:app/src",
				"file:a.lua:1",
				"line:6",
				string.format("diag:5:1:%d", vim.diagnostic.severity.WARN),
				"file:b.lua:1",
				"line:8",
				string.format("diag:7:0:%d", vim.diagnostic.severity.HINT),
			}), "unexpected diagnostic layout: " .. vim.inspect(got))

			for _, bufnr in ipairs({ current, a, b, root }) do
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end)

		it("renders grouped diagnostics and expands folders from child rows", function()
			package.loaded["frontend.tools.diagnostics-history.window"] = nil
			local window = require("frontend.tools.diagnostics-history.window")
			local old_cwd = vim.fn.getcwd()
			local root = vim.fn.tempname() .. "_diag_history"
			vim.fn.mkdir(root .. "/app/src", "p")

			local current = make_buffer(root .. "/app/src/current.lua")
			local a = make_buffer(root .. "/app/src/a.lua")
			local b = make_buffer(root .. "/app/src/b.lua")
			local root_buf = make_buffer(root .. "/README.md")
			local filler = {}
			for i = 1, 20 do
				filler[i] = ""
			end
			vim.api.nvim_buf_set_lines(current, 0, -1, false, filler)
			local items = {
				make_item(current, 10, 4, vim.diagnostic.severity.ERROR, "current error", "lua"),
				make_item(current, 10, 0, vim.diagnostic.severity.WARN, "current warn", "lua"),
				make_item(current, 2, 2, vim.diagnostic.severity.INFO, "current info", "lua"),
				make_item(a, 5, 1, vim.diagnostic.severity.WARN, "aw", "lua"),
				make_item(b, 7, 0, vim.diagnostic.severity.HINT, "bh", "lua"),
				make_item(root_buf, 0, 0, vim.diagnostic.severity.INFO, "ri", "lua"),
			}

			vim.api.nvim_set_current_buf(current)
			vim.cmd("cd " .. vim.fn.fnameescape(root))
			window.toggle({ items = items, keys = {} })

			local win, buf = nil, nil
			for _, candidate in ipairs(vim.api.nvim_list_wins()) do
				local candidate_buf = vim.api.nvim_win_get_buf(candidate)
				if vim.bo[candidate_buf].filetype == "DiagnosticsHistory" then
					win, buf = candidate, candidate_buf
					break
				end
			end
			assert(win ~= nil, "diagnostics history window missing")

			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert(lines[1] == "── CURRENT ──", "current separator missing: " .. vim.inspect(lines))
			assert(lines[2] == "▸ app/src/current.lua", "current file must be first: " .. vim.inspect(lines))
			assert(lines[3] == "  3:", "current line header missing: " .. vim.inspect(lines))
			assert(
				lines[4]:find("3: [lua] current info", 1, true) ~= nil,
				"current info row missing: " .. vim.inspect(lines)
			)
			assert(lines[5] == "  11:", "same line must stay grouped: " .. vim.inspect(lines))
			assert(lines[6]:find("1: [lua] current warn", 1, true) ~= nil, "same-line warn must sort first")
			assert(lines[7]:find("5: [lua] current error", 1, true) ~= nil, "same-line error must follow")
			assert(lines[8] == "", "current section must be separated from the rest")
			assert(lines[9] == "▸ README.md", "root file must come before folders")
			assert(lines[12] == "▾ src/", "shared folders must start collapsed")
			assert(lines[13] == "  ▸ a.lua", "folder files must be indented")
			assert(lines[15]:find("2: [lua] aw", 1, true) ~= nil, "grouped diagnostic row missing")

			vim.api.nvim_set_current_win(win)
			vim.api.nvim_win_set_cursor(win, { 15, 0 })
			vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
			lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert(lines[12] == "▾ app/src/", "child rows must expand the folder: " .. lines[12])

			vim.api.nvim_win_set_cursor(win, { 9, 0 })
			vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
			lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert(lines[12] == "▾ src/", "leaving the folder must collapse it: " .. lines[12])

			local jump = nil
			for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
				if map.lhs == "g" then
					jump = map.callback
					break
				end
			end
			assert(jump ~= nil, "diagnostics history needs a jump mapping")
			vim.api.nvim_win_set_cursor(win, { 6, 0 })
			jump()
			assert(vim.api.nvim_get_current_buf() == current, "jump must land in the diagnostic buffer")
			assert(
				vim.api.nvim_win_get_cursor(0)[1] == 11,
				"jump must land on the diagnostic line, got " .. vim.inspect(vim.api.nvim_win_get_cursor(0))
			)
			assert(not vim.api.nvim_win_is_valid(win), "jump must close the history window")

			window.close()
			vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))
			vim.fn.delete(root, "rf")
			for _, bufnr in ipairs({ current, a, b, root_buf }) do
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.api.nvim_buf_delete(bufnr, { force = true })
				end
			end
			package.loaded["frontend.tools.diagnostics-history.window"] = nil
		end)
	end)
end
