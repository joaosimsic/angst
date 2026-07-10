---@type Keybinder
local Keybinder = require("common.Keybinder")

local function get_filetypes()
	local filetypes = {}
	local files = vim.api.nvim_get_runtime_file("syntax/*.vim", true)
	for _, file in ipairs(files) do
		local name = vim.fn.fnamemodify(file, ":t:r")
		if name and name ~= "syntax" then
			filetypes[name] = true
		end
	end

	local result = vim.tbl_keys(filetypes)
	table.sort(result)
	return result
end

local function open_scratch()
	local filetypes = get_filetypes()

	vim.ui.select(filetypes, {
		prompt = "Select filetype for scratch buffer:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if not choice then
			return
		end

		vim.cmd("botright vsplit")
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, buf)
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].buflisted = false
		vim.bo[buf].filetype = choice
		vim.api.nvim_buf_set_name(buf, "[Scratch]")

		local binder = Keybinder.new(buf, "SCRATCH")
		binder:nmap("q", function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end, { desc = "Close scratch buffer" })
	end)
end

---@type Plugin
return {
	"scratch",
	virtual = true,
	event = "VeryLazy",
	config = function()
		local binder = Keybinder.new(nil, "SCRATCH")
		binder:nmap("<leader>n", open_scratch, { desc = "Open scratch buffer" })
	end,
}
