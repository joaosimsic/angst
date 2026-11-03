local sources = require("frontend.navigation.references.sources")
local spring = require("frontend.navigation.spring.state")

local LSP_TIMEOUT_MS = 1500

local M = {}

---@return string
local function visual_selection()
	local start = vim.fn.getpos("v")
	local finish = vim.fn.getpos(".")

	if start[2] > finish[2] or (start[2] == finish[2] and start[3] > finish[3]) then
		start, finish = finish, start
	end

	local lines = vim.fn.getregion(start, finish, { type = vim.fn.visualmode() })
	return table.concat(lines, "\n")
end

---@param query string
local function notify_no_references(query)
	vim.notify("No references for " .. query, vim.log.levels.INFO)
end

---@param query string
---@param whole_word boolean
---@param logger Logger|nil
local function open_references(query, whole_word, logger)
	if not query or query == "" then
		vim.notify("No word or selection to search", vim.log.levels.INFO)
		return
	end

	if logger then
		logger:debug(function()
			return "References: " .. query
		end)
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local winid = vim.api.nvim_get_current_win()
	local pending_origin = nil

	if not spring.is_active() then
		pending_origin = spring.capture()
	end

	sources.collect(query, {
		bufnr = bufnr,
		winid = winid,
		word = whole_word,
		timeout = LSP_TIMEOUT_MS,
	}, function(items)
		if #items == 0 then
			notify_no_references(query)
			return
		end

		local picker_entries = {}

		for _, item in ipairs(items) do
			picker_entries[#picker_entries + 1] =
				string.format("%s:%d:%d: %s", item.filename, item.lnum, item.col, item.text)
		end

		local fzf = require("fzf-lua")

		local function accept_with_spring(action)
			return function(selected, opts)
				if pending_origin then
					spring.pull(pending_origin)
				end

				action(selected, opts)
			end
		end

		fzf.fzf_exec(picker_entries, {
			prompt = "References> ",
			previewer = "builtin",
			winopts = { preview = { hidden = false } },
			fzf_opts = { ["--no-multi"] = true },
			actions = {
				["default"] = accept_with_spring(fzf.actions.file_edit),
				["ctrl-v"] = accept_with_spring(fzf.actions.file_vsplit),
				["ctrl-z"] = accept_with_spring(fzf.actions.file_split),
			},
		})
	end)
end

---@param logger Logger|nil
function M.open_word(logger)
	open_references(vim.fn.expand("<cword>"), true, logger)
end

---@param logger Logger|nil
function M.open_selection(logger)
	open_references(visual_selection(), false, logger)
end

return M
