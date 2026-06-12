local M = {}

local function cleanup_old_sessions()
	local max_sessions_per_project = 10

	local session_dir = vim.fn.expand("~/.local/share/opencode/storage/session/")

	local handle = vim.uv.fs_scandir(session_dir)
	if not handle then
		return
	end

	local dirs_cleaned = 0
	local sessions_deleted = 0

	while true do
		local name, type = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end

		if type == "directory" then
			local project_dir = session_dir .. name .. "/"

			local sessions = {}
			local project_handle = vim.uv.fs_scandir(project_dir)
			if project_handle then
				while true do
					local session_file, session_type = vim.uv.fs_scandir_next(project_handle)
					if not session_file then
						break
					end

					if session_type == "file" and session_file:match("^ses_.*%.json$") then
						local full_path = project_dir .. session_file
						local stat = vim.uv.fs_stat(full_path)
						if stat then
							table.insert(sessions, {
								path = full_path,
								id = session_file:match("^(ses_[^%.]+)"),
								mtime = stat.mtime.sec,
							})
						end
					end
				end
			end

			if #sessions > max_sessions_per_project then
				table.sort(sessions, function(a, b)
					return a.mtime > b.mtime
				end)

				for i = max_sessions_per_project + 1, #sessions do
					local session_id = sessions[i].id

					vim.uv.fs_unlink(sessions[i].path)

					local msg_dir = vim.fn.expand("~/.local/share/opencode/storage/message/" .. session_id)
					if vim.fn.isdirectory(msg_dir) == 1 then
						vim.fn.delete(msg_dir, "rf")
					end

					local part_dir = vim.fn.expand("~/.local/share/opencode/storage/part/" .. session_id)
					if vim.fn.isdirectory(part_dir) == 1 then
						vim.fn.delete(part_dir, "rf")
					end

					local diff_file =
						vim.fn.expand("~/.local/share/opencode/storage/session_diff/" .. session_id .. ".json")
					if vim.fn.filereadable(diff_file) == 1 then
						vim.uv.fs_unlink(diff_file)
					end

					sessions_deleted = sessions_deleted + 1
				end

				dirs_cleaned = dirs_cleaned + 1
			end
		end
	end

	if sessions_deleted > 0 then
		vim.notify(
			string.format("OpenCode: Cleaned up %d old session(s) from %d project(s)", sessions_deleted, dirs_cleaned),
			vim.log.levels.INFO
		)
	end
end

function M.setup()
	local cleanup_done = false
	vim.api.nvim_create_autocmd("User", {
		pattern = "OpencodeEvent:*",
		callback = function()
			if not cleanup_done then
				cleanup_done = true
				vim.schedule(function()
					cleanup_old_sessions()
				end)
			end
		end,
		desc = "Auto-cleanup old OpenCode sessions on first use",
	})
end

return M
