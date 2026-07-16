local backup_root = vim.fn.stdpath("cache") .. "/grug-far-backups"

local M = {}

function M.backup_file(filepath, run_id)
	local abs = vim.fn.fnamemodify(filepath, ":p")
	local rel = abs:gsub("^/+", "")
	local dest = backup_root .. "/" .. run_id .. "/" .. rel
	local dir = vim.fn.fnamemodify(dest, ":h")

	vim.fn.mkdir(dir, "p")
	vim.fn.system({ "cp", abs, dest })
end

function M.with_backup(opts, run_id)
	opts.hooks = opts.hooks or {}

	opts.hooks.on_before_edit_file = function(on_finish, file)
		M.backup_file(file.path, run_id)
		on_finish()
	end

	return opts
end

function M.list_backup_runs()
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

function M.count_files(run_id)
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

function M.list_backup_files(run_id)
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

function M.get_file_status(orig_path, backup_path)
	if vim.fn.filereadable(orig_path) == 0 then
		return "DELETED"
	end

	local orig = vim.fn.readfile(orig_path, "")
	local backup = vim.fn.readfile(backup_path, "")

	if #orig ~= #backup then
		return "MODIFIED"
	end

	for i, line in ipairs(backup) do
		if line ~= orig[i] then
			return "MODIFIED"
		end
	end

	return "RESTORED"
end

M.backup_root = backup_root

return M
