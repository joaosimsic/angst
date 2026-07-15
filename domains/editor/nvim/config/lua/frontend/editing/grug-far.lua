---@type Keybinder
local Keybinder = require("common.Keybinder")

local backup_root = vim.fn.stdpath("cache") .. "/grug-far-backups"

local function backup_file(filepath, run_id)
	local rel = filepath:gsub("^/+", "")
	local dest = backup_root .. "/" .. run_id .. "/" .. rel
	local dir = vim.fn.fnamemodify(dest, ":h")
	vim.fn.mkdir(dir, "p")
	vim.fn.system({ "cp", filepath, dest })
end

local function with_backup(opts)
	local run_id = os.date("%Y%m%d_%H%M%S") .. "_" .. vim.fn.getpid()
	opts.hooks = opts.hooks or {}
	opts.hooks.on_before_edit_file = function(on_finish, file)
		backup_file(file.path, run_id)
		on_finish()
	end
	return opts
end

local function list_backup_runs()
	local handle = vim.loop.fs_scandir(backup_root)
	if not handle then
		return {}
	end
	local runs = {}
	while true do
		local name, typ = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		if typ == "directory" then
			table.insert(runs, name)
		end
	end
	table.sort(runs, function(a, b)
		return a > b
	end)
	return runs
end

local function count_files(run_id)
	local run_dir = backup_root .. "/" .. run_id
	local count = 0
	local function scan(dir)
		local h = vim.loop.fs_scandir(dir)
		if not h then
			return
		end
		while true do
			local name, typ = vim.loop.fs_scandir_next(h)
			if not name then
				break
			end
			local full = dir .. "/" .. name
			if typ == "file" then
				count = count + 1
			elseif typ == "directory" then
				scan(full)
			end
		end
	end
	scan(run_dir)
	return count
end

local function list_backup_files(run_id)
	local run_dir = backup_root .. "/" .. run_id
	local files = {}
	local function scan(dir)
		local h = vim.loop.fs_scandir(dir)
		if not h then
			return
		end
		while true do
			local name, typ = vim.loop.fs_scandir_next(h)
			if not name then
				break
			end
			local full = dir .. "/" .. name
			if typ == "file" then
				table.insert(files, full)
			elseif typ == "directory" then
				scan(full)
			end
		end
	end
	scan(run_dir)
	return files
end

local function get_file_status(orig_path, backup_path)
	if vim.fn.filereadable(orig_path) == 0 then
		return "DELETED"
	end
	local orig = vim.fn.readfile(orig_path, "c")
	local backup = vim.fn.readfile(backup_path, "c")
	if #orig ~= #backup then
		return "MODIFIED"
	end
	for i, line in ipairs(backup) do
		if line ~= orig[i] then
			return "MODIFIED"
		end
	end
	return "unchanged"
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

local function render_run_list(buf)
	local lines = {
		"  Grug Far Restore",
		"",
		"  Select a backup run:",
		"",
	}
	local runs = list_backup_runs()
	for i, run in ipairs(runs) do
		local count = count_files(run)
		lines[#lines + 1] = string.format("  %d.  %s  (%d files)", i, run, count)
	end
	if #runs == 0 then
		lines[#lines + 1] = "  (no backups found)"
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "  <Enter> select run  q close"

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_name(buf, "grug-far-restore://runs")
	vim.api.nvim_set_option_value("filetype", "grug-far-restore", { buf = buf })
	vim.bo[buf].modified = false
	pcall(vim.api.nvim_win_set_cursor, vim.api.nvim_get_current_win(), { 5, 0 })
end

local function render_file_list(buf, run_id)
	local prefix_len = #(backup_root .. "/" .. run_id) + 1
	local files = list_backup_files(run_id)
	local lines = {
		"  Grug Far Restore - " .. run_id,
		"",
		"  d/<Enter> diff  r restore file  R restore all  q back  <Esc> back",
		"",
	}
	for _, path in ipairs(files) do
		local orig_path = "/" .. path:sub(prefix_len)
		local status = get_file_status(orig_path, path)
		lines[#lines + 1] = string.format("  %s  %s", status, orig_path)
	end
	if #files == 0 then
		lines[#lines + 1] = "  (no files in this run)"
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_name(buf, "grug-far-restore://" .. run_id)
	vim.api.nvim_set_option_value("filetype", "grug-far-restore", { buf = buf })
	vim.bo[buf].modified = false
	pcall(vim.api.nvim_win_set_cursor, vim.api.nvim_get_current_win(), { 5, 0 })
end

local function setup_restore_keymaps(buf, win)
	local binder = Keybinder.new(buf, "GRUG-FAR-RESTORE")

	binder:nmap("q", function()
		if vim.b.restore_state == "files" then
			render_run_list(buf)
			vim.b.restore_state = "runs"
		else
			pcall(vim.api.nvim_win_close, win, true)
		end
	end, { desc = "Close or back" })

	binder:nmap("<Esc>", function()
		if vim.b.restore_state == "files" then
			render_run_list(buf)
			vim.b.restore_state = "runs"
		end
	end, { desc = "Back to run list" })

	binder:nmap("<CR>", function()
		local line = vim.fn.line(".")
		if vim.b.restore_state == "runs" then
			local runs = list_backup_runs()
			if #runs == 0 then
				return
			end
			local idx = line - 3
			if idx >= 1 and idx <= #runs then
				vim.b.restore_run_id = runs[idx]
				vim.b.restore_state = "files"
				render_file_list(buf, vim.b.restore_run_id)
			end
		elseif vim.b.restore_state == "files" then
			local prefix_len = #(backup_root .. "/" .. vim.b.restore_run_id) + 1
			local files = list_backup_files(vim.b.restore_run_id)
			local idx = line - 4
			if idx >= 1 and idx <= #files then
				local backup_path = files[idx]
				local orig_path = "/" .. backup_path:sub(prefix_len)
				if vim.fn.filereadable(orig_path) == 1 then
					show_diff(orig_path, backup_path)
				else
					vim.notify("File no longer exists: " .. orig_path, vim.log.levels.WARN)
				end
			end
		end
	end, { desc = "Select run or diff file" })

	binder:nmap("d", function()
		if vim.b.restore_state ~= "files" then
			return
		end
		local line = vim.fn.line(".")
		local prefix_len = #(backup_root .. "/" .. vim.b.restore_run_id) + 1
		local files = list_backup_files(vim.b.restore_run_id)
		local idx = line - 4
		if idx >= 1 and idx <= #files then
			local backup_path = files[idx]
			local orig_path = "/" .. backup_path:sub(prefix_len)
			if vim.fn.filereadable(orig_path) == 1 then
				show_diff(orig_path, backup_path)
			else
				vim.notify("File no longer exists: " .. orig_path, vim.log.levels.WARN)
			end
		end
	end, { desc = "Diff file" })

	binder:nmap("r", function()
		if vim.b.restore_state ~= "files" then
			return
		end
		local line = vim.fn.line(".")
		local prefix_len = #(backup_root .. "/" .. vim.b.restore_run_id) + 1
		local files = list_backup_files(vim.b.restore_run_id)
		local idx = line - 4
		if idx >= 1 and idx <= #files then
			local backup_path = files[idx]
			local orig_path = "/" .. backup_path:sub(prefix_len)
			vim.fn.mkdir(vim.fn.fnamemodify(orig_path, ":h"), "p")
			vim.fn.system({ "cp", backup_path, orig_path })
			vim.notify("Restored " .. orig_path, vim.log.levels.INFO)
			render_file_list(buf, vim.b.restore_run_id)
		end
	end, { desc = "Restore file" })

	binder:nmap("R", function()
		if vim.b.restore_state ~= "files" then
			return
		end
		local files = list_backup_files(vim.b.restore_run_id)
		local prefix_len = #(backup_root .. "/" .. vim.b.restore_run_id) + 1
		local count = 0
		for _, backup_path in ipairs(files) do
			local orig_path = "/" .. backup_path:sub(prefix_len)
			vim.fn.mkdir(vim.fn.fnamemodify(orig_path, ":h"), "p")
			vim.fn.system({ "cp", backup_path, orig_path })
			count = count + 1
		end
		vim.notify("Restored " .. count .. " files", vim.log.levels.INFO)
		render_file_list(buf, vim.b.restore_run_id)
	end, { desc = "Restore all files" })
end

local function open_restore()
	if vim.fn.isdirectory(backup_root) == 0 then
		vim.notify("No grug-far backups found", vim.log.levels.INFO)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		split = "right",
		width = math.floor(vim.o.columns * 0.45),
	})

	vim.b.restore_state = "runs"
	vim.b.restore_run_id = nil
	render_run_list(buf)
	setup_restore_keymaps(buf, win)
end

---@type Plugin
return {
	"MagicDuck/grug-far.nvim",
	event = "VeryLazy",
	cmd = { "GrugFar" },
	config = function()
		require("grug-far").setup({})

		local binder = Keybinder.new(nil, "GRUG-FAR")

		binder:nmap("<leader>g", function()
			require("grug-far").open(with_backup({
				prefills = { search = vim.fn.expand("<cword>") },
			}))
		end, { desc = "Grug Far word under cursor" })

		binder:vmap("<leader>g", function()
			require("grug-far").with_visual_selection(with_backup({}))
		end, { desc = "Grug Far visual selection" })

		binder:nmap("<leader>gu", function()
			open_restore()
		end, { desc = "Grug Far Restore" })
	end,
}
