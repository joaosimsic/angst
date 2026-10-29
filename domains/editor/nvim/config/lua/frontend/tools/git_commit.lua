-- Commit-buffer highlight layer (gitcommit filetype, Neogit or plain git).
--
-- Why matchadd instead of syntax matches: it outranks both Vim syntax and
-- treesitter, so footer columns and status words keep their colors even once
-- the gitcommit parser lands. Matches are window-scoped and die with it.
--
-- Fixes:
-- 1. Neogit footer key vs action share gitcommitComment -> GitCommitKey/Action.
-- 2. modified/new file/deleted share gitcommitSelectedType -> per-word groups.
-- 3. Neogit matchadd("NeogitBranch", "main") also paints "do[main]s" ->
--    re-added with word boundaries.

---@param win integer
local function apply_to_window(win)
	for _, match in ipairs(vim.fn.getmatches(win)) do
		if match.group == "NeogitBranch" or match.group == "NeogitRemote" then
			vim.fn.matchdelete(match.id, win)
			vim.fn.matchadd(
				match.group,
				"\\<" .. vim.fn.escape(match.pattern, "\\") .. "\\>",
				100,
				-1,
				{ window = win }
			)
		end
	end

	-- Footer entries look like "#   q          Close".
	vim.fn.matchadd("GitCommitKey", [[^#\s\{3,}\zs\S\+]], 10, -1, { window = win })
	vim.fn.matchadd("GitCommitAction", [[^#\s\{3,}\S\+\s\+\zs.\+$]], 10, -1, { window = win })

	local words = {
		modified = "GitCommitModified",
		["new file"] = "GitCommitNewFile",
		deleted = "GitCommitDeleted",
		renamed = "GitCommitRenamed",
	}
	for word, hl in pairs(words) do
		vim.fn.matchadd(hl, [[^#\t\zs]] .. word .. ":", 10, -1, { window = win })
	end
end

---@type Plugin
return {
	"git-commit-highlight",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local group = vim.api.nvim_create_augroup("GitCommitHighlight", { clear = true })

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "gitcommit",
			callback = function(event)
				local buf = event.buf

				-- Runs after Neogit's editor `after` hook, which adds the
				-- unbounded NeogitBranch/NeogitRemote matches. Windows are
				-- resolved here, not at FileType time: Neogit sets the
				-- filetype before opening the window, so the current window
				-- at event time is the wrong one.
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(buf) then
						return
					end

					for _, win in ipairs(vim.fn.win_findbuf(buf)) do
						if not vim.w[win].git_commit_matches then
							vim.w[win].git_commit_matches = true
							apply_to_window(win)
						end
					end
				end)
			end,
		})
	end,
}
