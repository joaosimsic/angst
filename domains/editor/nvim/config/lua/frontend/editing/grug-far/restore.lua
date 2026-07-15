local backup = require("frontend.editing.grug-far.backup")
local Keybinder = require("common.Keybinder")

local M = {}

local function resolve_path(path)
	local abs = "/" .. path:gsub("^/+", "")
	if vim.fn.filereadable(abs) == 1 then
		return abs
	end
	local parent = vim.fn.fnamemodify(abs, ":h")
	if vim.fn.isdirectory(parent) == 1 then
		return abs
	end
	return vim.fn.fnamemodify(path, ":p")
end

local function show_diff(orig_path, backup_path)
	local orig_content = vim.fn.readfile(orig_path, "c")
	local backup_content = vim.fn.readfile(backup_path, "c")
	local diff = vim.diff(backup_content, orig_content, {
		result_type = "unified",
		ctxlen = 3,
	})
	if not diff or diff == "" then
		vim.notify("No differences", vim.log.levels.INFO)
		return
	end
	local lines = vim.split(diff, "\n", { plain = true })
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modified = false
	vim.bo[buf].filetype = "diff"
	local width = math.floor(vim.o.columns * 0.55)
	local height = math.floor(vim.o.lines * 0.7)
	local preview_win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
		title = vim.fn.fnamemodify(orig_path, ":t"),
		title_pos = "center",
	})
	vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat", { win = preview_win })
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		silent = true,
		callback = function()
			pcall(vim.api.nvim_win_close, preview_win, true)
		end,
		desc = "Close diff",
	})
end

local function runs_to_data(runs)
	local ResultMarkType = require("grug-far.engine").ResultMarkType
	local data = {
		lines = {},
		marks = {},
		highlights = {},
		stats = { files = 0, matches = #runs },
	}
	for i, run in ipairs(runs) do
		local count = backup.count_files(run)
		local line = string.format("  %s  (%d files)", run, count)
		table.insert(data.lines, line)
		table.insert(data.marks, {
			type = ResultMarkType.SourceLocation,
			start_line = i - 1,
			start_col = 0,
			end_line = i - 1,
			end_col = #line,
			location = { filename = run, is_counted = false },
		})
	end
	return data
end

local function files_to_data(files, run_id)
	local ResultMarkType = require("grug-far.engine").ResultMarkType
	local prefix_len = #(backup.backup_root .. "/" .. run_id) + 1
	local data = {
		lines = {},
		marks = {},
		highlights = {},
		stats = { files = 0, matches = #files },
	}
	for i, backup_path in ipairs(files) do
		local orig_path = resolve_path(backup_path:sub(prefix_len))
		local status = backup.get_file_status(orig_path, backup_path)
		local line = string.format("  %s  %s", status, orig_path)
		table.insert(data.lines, line)
		table.insert(data.marks, {
			type = ResultMarkType.SourceLocation,
			start_line = i - 1,
			start_col = 0,
			end_line = i - 1,
			end_col = #line,
			location = { filename = orig_path, text = backup_path, is_counted = false },
		})
	end
	return data
end

local function render_data(inst, data)
	local buf = inst:get_buf()
	local context = inst._context
	local resultsList = require("grug-far.render.resultsList")
	resultsList.clear(buf, context)
	resultsList.appendResultsChunk(buf, context, data)
end

local function get_location_at_cursor(inst)
	local buf = inst:get_buf()
	local context = inst._context
	local resultsList = require("grug-far.render.resultsList")
	return resultsList.getResultLocationAtCursor(buf, context)
end

local function setup_restore_keymaps(inst, state_ref)
	if state_ref.binder then
		state_ref.binder:purge()
	end

	local buf = inst:get_buf()
	local win = vim.fn.bufwinid(buf)
	state_ref.binder = Keybinder.new(buf, "GRUG-FAR-RESTORE")
	local binder = state_ref.binder

	binder:nmap("q", function()
		if state_ref.state == "files" then
			local runs = backup.list_backup_runs()
			render_data(inst, runs_to_data(runs))
			state_ref.state = "runs"
			state_ref.run_id = nil
		else
			pcall(vim.api.nvim_win_close, win, true)
		end
	end, { desc = "Close or back" })

	binder:nmap("<Esc>", function()
		if state_ref.state == "files" then
			local runs = backup.list_backup_runs()
			render_data(inst, runs_to_data(runs))
			state_ref.state = "runs"
			state_ref.run_id = nil
		end
	end, { desc = "Back to run list" })

	binder:nmap("<CR>", function()
		local loc = get_location_at_cursor(inst)
		if not loc then
			return
		end

		if state_ref.state == "runs" then
			local run_id = loc.filename
			local files = backup.list_backup_files(run_id)
			render_data(inst, files_to_data(files, run_id))
			state_ref.state = "files"
			state_ref.run_id = run_id
		elseif state_ref.state == "files" then
			local orig_path = loc.filename
			local backup_path = loc.text
			if vim.fn.filereadable(orig_path) == 1 then
				show_diff(orig_path, backup_path)
			else
				vim.notify("File no longer exists: " .. orig_path, vim.log.levels.WARN)
			end
		end
	end, { desc = "Select run or diff file" })

	binder:nmap("d", function()
		if state_ref.state ~= "files" then
			return
		end
		local loc = get_location_at_cursor(inst)
		if not loc then
			return
		end
		local orig_path = loc.filename
		local backup_path = loc.text
		if vim.fn.filereadable(orig_path) == 1 then
			show_diff(orig_path, backup_path)
		else
			vim.notify("File no longer exists: " .. orig_path, vim.log.levels.WARN)
		end
	end, { desc = "Diff file" })

	binder:nmap("r", function()
		if state_ref.state ~= "files" then
			return
		end
		local loc = get_location_at_cursor(inst)
		if not loc then
			return
		end
		local orig_path = loc.filename
		local backup_path = loc.text
		vim.fn.mkdir(vim.fn.fnamemodify(orig_path, ":h"), "p")
		vim.fn.system({ "cp", backup_path, orig_path })
		vim.notify("Restored " .. orig_path, vim.log.levels.INFO)
		local files = backup.list_backup_files(state_ref.run_id)
		render_data(inst, files_to_data(files, state_ref.run_id))
	end, { desc = "Restore file" })

	binder:nmap("R", function()
		if state_ref.state ~= "files" then
			return
		end
		local files = backup.list_backup_files(state_ref.run_id)
		local prefix_len = #(backup.backup_root .. "/" .. state_ref.run_id) + 1
		local count = 0
		for _, backup_path in ipairs(files) do
			local orig_path = resolve_path(backup_path:sub(prefix_len))
			vim.fn.mkdir(vim.fn.fnamemodify(orig_path, ":h"), "p")
			vim.fn.system({ "cp", backup_path, orig_path })
			count = count + 1
		end
		vim.notify("Restored " .. count .. " files", vim.log.levels.INFO)
		render_data(inst, files_to_data(files, state_ref.run_id))
	end, { desc = "Restore all files" })
end

local disabled_keymaps
local function get_disabled_keymaps()
	if disabled_keymaps then
		return disabled_keymaps
	end
	disabled_keymaps = {}
	local default_keymap_names = {
		"replace", "qflist", "syncLocations", "syncLine", "close",
		"historyOpen", "historyAdd", "refresh", "openLocation",
		"openNextLocation", "openPrevLocation", "gotoLocation",
		"pickHistoryEntry", "abort", "help", "toggleShowCommand",
		"swapEngine", "previewLocation", "swapReplacementInterpreter",
		"applyNext", "applyPrev", "syncNext", "syncPrev", "syncFile",
		"nextInput", "prevInput",
	}
	for _, name in ipairs(default_keymap_names) do
		disabled_keymaps[name] = false
	end
	return disabled_keymaps
end

local function setup_restore_browser(inst)
	local state_ref = { state = "runs", run_id = nil }
	local runs = backup.list_backup_runs()
	if #runs > 0 then
		render_data(inst, runs_to_data(runs))
	end
	setup_restore_keymaps(inst, state_ref)
end

function M.open_restore()
	if vim.fn.isdirectory(backup.backup_root) == 0 then
		vim.notify("No grug-far backups found", vim.log.levels.INFO)
		return
	end

	if require("grug-far").has_instance("grug-far-restore") then
		local inst = require("grug-far").get_instance("grug-far-restore")
		if inst then
			inst:ensure_open()
			setup_restore_browser(inst)
			return
		end
	end

	local inst = require("grug-far").open({
		instanceName = "grug-far-restore",
		staticTitle = "  Backup Restore  ",
		keymaps = get_disabled_keymaps(),
		startInInsertMode = false,
		normalModeSearch = false,
	})

	inst:when_ready(function()
		setup_restore_browser(inst)
	end)
end

function M.add_instance_keymaps(inst, run_id)
	inst:when_ready(function()
		local buf = inst:get_buf()
		vim.api.nvim_buf_set_keymap(buf, "n", "<localleader>u", "", {
			noremap = true,
			nowait = true,
			silent = true,
			callback = function()
				local context = inst._context
				local resultsList = require("grug-far.render.resultsList")
				local loc = resultsList.getResultLocationAtCursor(buf, context)
				if not loc or not loc.filename then
					vim.notify("No file under cursor", vim.log.levels.INFO)
					return
				end
				local filepath = resolve_path(loc.filename)
				local backup_path = backup.backup_root .. "/" .. run_id .. "/" .. filepath:gsub("^/+", "")
				if vim.fn.filereadable(backup_path) == 0 then
					vim.notify("No backup found for " .. filepath, vim.log.levels.WARN)
					return
				end
				vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
				vim.fn.system({ "cp", backup_path, filepath })
				vim.notify("Restored " .. filepath, vim.log.levels.INFO)
			end,
			desc = "[Grug-Far] Restore file under cursor",
		})
	end)
end

return M
