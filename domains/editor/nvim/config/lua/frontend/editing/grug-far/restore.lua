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

local function file_diff_to_data(orig_path, backup_path)
	local ResultMarkType = require("grug-far.engine").ResultMarkType
	local ResultHighlightType = require("grug-far.engine").ResultHighlightType
	local ResultHighlightByType = require("grug-far.engine").ResultHighlightByType
	local ResultSigns = require("grug-far.engine").ResultSigns

	local data = {
		lines = {},
		marks = {},
		highlights = {},
		stats = { files = 0, matches = 0 },
	}

	local header = orig_path

	table.insert(data.lines, header)

	table.insert(data.marks, {
		type = ResultMarkType.SourceLocation,
		start_line = 0,
		start_col = 0,
		end_line = 0,
		end_col = #header,
		location = { filename = orig_path, text = backup_path, is_counted = false },
	})

	table.insert(data.highlights, {
		hl_group = ResultHighlightByType[ResultHighlightType.FilePath],
		start_line = 0,
		start_col = 0,
		end_line = 0,
		end_col = #header,
	})

	data.stats.files = 1

	if vim.fn.filereadable(orig_path) == 0 then
		local bk_lines = vim.fn.readfile(backup_path, "")

		for i, line in ipairs(bk_lines) do
			local dl = "- " .. line

			table.insert(data.lines, dl)

			data.stats.matches = data.stats.matches + 1

			table.insert(data.marks, {
				type = ResultMarkType.SourceLocation,
				start_line = i,
				start_col = 0,
				end_line = i,
				end_col = #dl,
				sign = ResultSigns.Removed,
				location = { filename = orig_path, lnum = i, text = dl, is_counted = true },
			})

			table.insert(data.highlights, {
				hl_group = ResultHighlightByType[ResultHighlightType.MatchRemoved],
				start_line = i,
				start_col = 0,
				end_line = i,
				end_col = #dl,
			})
		end

		return data
	end

	local orig_content = table.concat(vim.fn.readfile(orig_path, ""), "\n")
	local backup_content = table.concat(vim.fn.readfile(backup_path, ""), "\n")

	if orig_content == backup_content then
		table.insert(data.lines, "  (unchanged)")
		return data
	end

	local diff_text = vim.diff(backup_content, orig_content, {
		result_type = "unified",
		ctxlen = 3,
	})

	if not diff_text or diff_text == "" then
		table.insert(data.lines, "  (no diff)")
		return data
	end

	---@type string[]
	local diff_lines = vim.split(diff_text, "\n", { plain = true })
	local line_num = 0
	local orig_lnum, backup_lnum = 0, 0

	for _, dl in ipairs(diff_lines) do
		if dl == "" then
			goto continue
		end

		local p = dl:sub(1, 1)

		if p == "-" and dl:sub(2, 2) == "-" then
			goto continue
		end

		if p == "+" and dl:sub(2, 2) == "+" then
			goto continue
		end

		if p == "@" then
			local _, _, bl = dl:find("@@%-(%d+)")
			local _, _, ol = dl:find("%+(%d+)")

			if bl then
				backup_lnum = tonumber(bl) - 1
			end

			if ol then
				orig_lnum = tonumber(ol) - 1
			end

			goto continue
		end

		if p == " " then
			backup_lnum = backup_lnum + 1
			orig_lnum = orig_lnum + 1

			local display = "  " .. dl:sub(2)

			table.insert(data.lines, display)
			line_num = line_num + 1
		elseif p == "-" then
			backup_lnum = backup_lnum + 1

			local display = "- " .. dl:sub(2)

			table.insert(data.lines, display)
			line_num = line_num + 1
			data.stats.matches = data.stats.matches + 1

			table.insert(data.marks, {
				type = ResultMarkType.SourceLocation,
				start_line = line_num,
				start_col = 0,
				end_line = line_num,
				end_col = #display,
				sign = ResultSigns.Removed,
				location = { filename = orig_path, lnum = backup_lnum, text = display, is_counted = true },
			})

			table.insert(data.highlights, {
				hl_group = ResultHighlightByType[ResultHighlightType.MatchRemoved],
				start_line = line_num,
				start_col = 0,
				end_line = line_num,
				end_col = #display,
			})
		elseif p == "+" then
			orig_lnum = orig_lnum + 1
			local display = "+ " .. dl:sub(2)

			table.insert(data.lines, display)
			line_num = line_num + 1
			data.stats.matches = data.stats.matches + 1

			table.insert(data.marks, {
				type = ResultMarkType.SourceLocation,
				start_line = line_num,
				start_col = 0,
				end_line = line_num,
				end_col = #display,
				sign = ResultSigns.Added,
				location = { filename = orig_path, lnum = orig_lnum, text = display, is_counted = true },
			})

			table.insert(data.highlights, {
				hl_group = ResultHighlightByType[ResultHighlightType.MatchAdded],
				start_line = line_num,
				start_col = 0,
				end_line = line_num,
				end_col = #display,
			})
		end
		::continue::
	end

	return data
end

local function runs_to_data(runs)
	local ResultMarkType = require("grug-far.engine").ResultMarkType

	local data = {
		lines = {},
		marks = {},
		highlights = {},
		stats = { files = 0, matches = #runs },
	}

	local hint = "  [<CR>] Select run  |  [q] Close"

	table.insert(data.lines, hint)
	table.insert(data.highlights, {
		hl_group = "GrugFarHelpHeader",
		start_line = 0,
		start_col = 0,
		end_line = 0,
		end_col = #hint,
	})
	table.insert(data.lines, "")
	for i, run in ipairs(runs) do
		local count = backup.count_files(run)
		local line = string.format("  %s  (%d files)", run, count)

		table.insert(data.lines, line)
		table.insert(data.marks, {
			type = ResultMarkType.SourceLocation,
			start_line = i + 1,
			start_col = 0,
			end_line = i + 1,
			end_col = #line,
			location = { filename = run, is_counted = false },
		})
	end

	return data
end

local function files_to_diff_data(files, run_id, backup_paths)
	local prefix_len = #(backup.backup_root .. "/" .. run_id) + 1

	local all_data = {
		lines = {},
		marks = {},
		highlights = {},
		stats = { files = 0, matches = 0 },
	}

	local hint = "  [q] Back  |  [r] Restore  |  [R] All  |  [d/<CR>] Open file"

	table.insert(all_data.lines, hint)

	table.insert(all_data.highlights, {
		hl_group = "GrugFarHelpHeader",
		start_line = 0,
		start_col = 0,
		end_line = 0,
		end_col = #hint,
	})

	table.insert(all_data.lines, "")

	local offset = 2

	for _, bp in ipairs(files) do
		local orig_path = resolve_path(bp:sub(prefix_len))
		backup_paths[orig_path] = bp

		local fd = file_diff_to_data(orig_path, bp)
		if fd and #fd.lines > 0 then
			for _, m in ipairs(fd.marks) do
				m.start_line = m.start_line + offset
				m.end_line = m.end_line + offset
			end

			for _, h in ipairs(fd.highlights) do
				h.start_line = h.start_line + offset
				h.end_line = h.end_line + offset
			end

			for _, l in ipairs(fd.lines) do
				table.insert(all_data.lines, l)
			end

			for _, m in ipairs(fd.marks) do
				table.insert(all_data.marks, m)
			end

			for _, h in ipairs(fd.highlights) do
				table.insert(all_data.highlights, h)
			end

			all_data.stats.files = all_data.stats.files + fd.stats.files
			all_data.stats.matches = all_data.stats.matches + fd.stats.matches

			table.insert(all_data.lines, "")
			offset = #all_data.lines
		end
	end

	return all_data
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

local function open_file_at_location(loc, backup_path)
	local orig_path = loc.filename
	if not orig_path or vim.fn.filereadable(orig_path) == 0 then
		return
	end

	vim.api.nvim_command("tabedit " .. vim.fn.fnameescape(orig_path))

	if backup_path and vim.fn.filereadable(backup_path) == 1 then
		vim.api.nvim_command("vertical diffsplit " .. vim.fn.fnameescape(backup_path))
		vim.api.nvim_command("wincmd h")
	end

	if loc.lnum then
		vim.api.nvim_win_set_cursor(0, { loc.lnum, 0 })
		vim.cmd("normal! zz")
	end
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
			local backup_paths = {}
			local data = files_to_diff_data(files, run_id, backup_paths)

			data.stats.files = #files

			render_data(inst, data)

			state_ref.state = "files"
			state_ref.run_id = run_id
			state_ref.backup_paths = backup_paths
		elseif state_ref.state == "files" then
			open_file_at_location(loc, state_ref.backup_paths and state_ref.backup_paths[loc.filename])
		end
	end, { desc = "Select run or open file" })

	binder:nmap("d", function()
		if state_ref.state ~= "files" then
			return
		end

		local loc = get_location_at_cursor(inst)

		if not loc then
			return
		end

		open_file_at_location(loc, state_ref.backup_paths and state_ref.backup_paths[loc.filename])
	end, { desc = "Open file at cursor" })

	binder:nmap("r", function()
		if state_ref.state ~= "files" then
			return
		end

		local loc = get_location_at_cursor(inst)

		if not loc then
			return
		end

		local orig_path = loc.filename
		local backup_path = state_ref.backup_paths and state_ref.backup_paths[orig_path]

		if not backup_path then
			vim.notify("No backup path for " .. orig_path, vim.log.levels.WARN)
			return
		end

		vim.fn.mkdir(vim.fn.fnamemodify(orig_path, ":h"), "p")
		vim.fn.system({ "cp", backup_path, orig_path })

		local context = inst._context

		context.state.actionMessage = "Restored " .. vim.fn.fnamemodify(orig_path, ":t")

		pcall(require("grug-far.render.resultsHeader"), inst:get_buf(), context)

		local files = backup.list_backup_files(state_ref.run_id)
		local backup_paths = {}

		render_data(inst, files_to_diff_data(files, state_ref.run_id, backup_paths))

		state_ref.backup_paths = backup_paths
	end, { desc = "Restore file" })

	binder:nmap("R", function()
		if state_ref.state ~= "files" then
			return
		end

		local files = backup.list_backup_files(state_ref.run_id)
		local prefix_len = #(backup.backup_root .. "/" .. state_ref.run_id) + 1
		local count = 0
		local context = inst._context

		for _, backup_path in ipairs(files) do
			local orig_path = resolve_path(backup_path:sub(prefix_len))
			vim.fn.mkdir(vim.fn.fnamemodify(orig_path, ":h"), "p")
			vim.fn.system({ "cp", backup_path, orig_path })
			count = count + 1
		end

		context.state.actionMessage = "Restored " .. count .. " files"

		pcall(require("grug-far.render.resultsHeader"), inst:get_buf(), context)

		local backup_paths = {}

		render_data(inst, files_to_diff_data(files, state_ref.run_id, backup_paths))

		state_ref.backup_paths = backup_paths
	end, { desc = "Restore all files" })
end

local disabled_keymaps
local function get_disabled_keymaps()
	if disabled_keymaps then
		return disabled_keymaps
	end

	disabled_keymaps = {}

	local names = {
		"replace",
		"qflist",
		"syncLocations",
		"syncLine",
		"close",
		"historyOpen",
		"historyAdd",
		"refresh",
		"openLocation",
		"openNextLocation",
		"openPrevLocation",
		"gotoLocation",
		"pickHistoryEntry",
		"abort",
		"help",
		"toggleShowCommand",
		"swapEngine",
		"previewLocation",
		"swapReplacementInterpreter",
		"applyNext",
		"applyPrev",
		"syncNext",
		"syncPrev",
		"syncFile",
		"nextInput",
		"prevInput",
	}

	for _, name in ipairs(names) do
		disabled_keymaps[name] = false
	end

	return disabled_keymaps
end

local function setup_restore_browser(inst)
	local state_ref = { state = "runs", run_id = nil, backup_paths = {} }
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
