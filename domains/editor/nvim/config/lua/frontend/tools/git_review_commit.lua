-- Commit-range source for the Git review hydra.
--
-- Same column as the branch source, but the range is `picked..HEAD` and
-- the picker searches commit hashes or messages. Targets persist in
-- vim.g so the mode survives hydra exits.
local files = require("frontend.tools.git_review_files")
local range = require("frontend.tools.git_review_range")

local function short(sha)
	return (sha or ""):sub(1, 7)
end

local function filter_commits(items, query)
	query = vim.trim(query or "")
	if query == "" then
		return items
	end
	local q = query:lower()
	local out = {}
	for _, item in ipairs(items) do
		local full = (item.value or ""):lower()
		local abbreviated = (item.short or ""):lower()
		local subject = (item.subject or ""):lower()
		if full:sub(1, #q) == q or abbreviated:sub(1, #q) == q or subject:find(q, 1, true) ~= nil then
			out[#out + 1] = item
		end
	end
	return out
end

local view = range.new({
	mode = "commit",
	target_var = "angst_git_commit_target",
	badge_name = "git-commit-diff",
	badge_label = function(target)
		return "⇢ " .. short(target) .. "..HEAD"
	end,
	picker_title = "COMMITS",
	picker_empty = "(no commits match)",
	list_targets = function(cwd)
		local head = files.head_sha(cwd)
		local items = {}
		for _, item in ipairs(files.list_commits(cwd)) do
			if head == nil or item.value ~= head then
				items[#items + 1] = item
			end
		end
		return items
	end,
	filter_target = filter_commits,
	resolve_target = function(cwd, query)
		local sha = files.resolve_commit(cwd, query)
		if sha == nil then
			return nil
		end
		return { value = sha, label = short(sha) .. " " .. query }
	end,
	entries_for = files.commit_entries_for,
	empty_range_notice = function(target)
		return string.format("Git commit diff: no changes between HEAD and %s", short(target))
	end,
})

return view
