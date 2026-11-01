-- Branch-diff source for the Git review hydra.
--
-- The column itself is the shared range view; this adapter supplies the
-- branch list and `base..HEAD` entries. Targets persist in vim.g so the
-- mode survives hydra exits.
local files = require("frontend.tools.git_review_files")
local range = require("frontend.tools.git_review_range")

local view = range.new({
	mode = "branch",
	target_var = "angst_git_branch_target",
	badge_name = "git-branch-diff",
	badge_label = function(target)
		return "⇄ " .. target
	end,
	picker_title = "BRANCHES",
	picker_empty = "(no branches)",
	filter_target = function(items, query)
		query = vim.trim(query or "")
		if query == "" then
			return items
		end
		local q = query:lower()
		local out = {}
		for _, item in ipairs(items) do
			local label = (item.label or ""):lower()
			if label:find(q, 1, true) ~= nil then
				out[#out + 1] = item
			end
		end
		return out
	end,
	list_targets = function(cwd)
		local own = files.current_branch(cwd)
		local items = {}
		for _, branch in ipairs(files.list_branches(cwd)) do
			if own == nil or (branch ~= own and branch ~= "origin/" .. own) then
				items[#items + 1] = { value = branch, label = branch }
			end
		end
		return items
	end,
	entries_for = files.branch_entries_for,
	empty_range_notice = function(target)
		return string.format("Git branch diff: no changes between HEAD and %s", target)
	end,
})

return view
