---@type Keybinder
local Keybinder = require("common.Keybinder")

---@type Plugin
return {
	"clipboard-auto-indent",
	virtual = true,
	lazy = false,
	config = function()
		vim.opt.clipboard = "unnamedplus"

		local binder = Keybinder.new(nil, "CLIPBOARD")

		local function is_inside_block()
			local bufnr = vim.api.nvim_get_current_buf()
			local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
			if not ok then
				return false
			end

			local row = vim.api.nvim_win_get_cursor(0)[1] - 1
			local col = vim.api.nvim_win_get_cursor(0)[2]
			local root = parser:parse()[1]:root()
			local node = root:descendant_for_range(row, col, row, col)

			while node do
				local start_row, _, end_row, _ = node:range()
				if end_row > start_row and node ~= root and row > start_row then
					return true
				end
				node = node:parent()
			end

			return false
		end

		local function paste_inside_block(forward)
			local lines = vim.fn.getreg('"', 1, true)
			if #lines == 0 then
				return
			end

			local was_inside = is_inside_block()

			vim.cmd("normal! " .. (forward and "]p" or "]P"))

			if was_inside then
				local start = vim.fn.line("'[")
				local end_ = vim.fn.line("']")
				if start and end_ and start <= end_ then
					vim.cmd(string.format("%d,%d>", start, end_))
				end
			end
		end

		binder:nmap("p", function()
			paste_inside_block(true)
		end, { desc = "Paste after with block-aware indent" })

		binder:nmap("P", function()
			paste_inside_block(false)
		end, { desc = "Paste before with block-aware indent" })
	end,
}
