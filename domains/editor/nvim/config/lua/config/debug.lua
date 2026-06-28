local Hydra = require("common.Hydra")
local AdapterScanner = require("backend.shared.AdapterScanner")

local M = {}

local function get_engine_status()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype

	if ft == "" then
		ft = "none"
	end

	local lines = {
		" 🛠️  Backend Engine Debug Mode ",
		"==============================",
		string.format(" Buffer: %d | Filetype: %s", bufnr, ft),
		"------------------------------",
		"",
	}

	table.insert(lines, "● LSP:")
	local lsp_clients = vim.lsp.get_clients({ bufnr = bufnr })
	if #lsp_clients == 0 then
		table.insert(lines, "  State: 🛑 No active clients attached.")
	else
		for _, client in ipairs(lsp_clients) do
			table.insert(lines, string.format("  State: 🟢 Active [%s] (ID: %d)", client.name, client.id))
		end
	end
	table.insert(lines, "")

	table.insert(lines, "● Tree-sitter:")
	local has_highlighter = vim.treesitter.highlighter.active[bufnr] ~= nil
	if has_highlighter then
		local lang = vim.treesitter.language.get_lang(ft) or ft
		table.insert(lines, string.format("  State: 🟢 Active (Parser: %s)", lang))
	else
		table.insert(lines, "  State: 🛑 Inactive / No parser attached to buffer.")
	end
	table.insert(lines, "")

	table.insert(lines, "● Formatter:")
	local formatters = AdapterScanner:tools_for_filetype("formatter", ft, { check_executable = true })
	if #formatters == 0 then
		table.insert(lines, "  State: 🛑 None configured or available.")
	else
		table.insert(lines, "  Configured: " .. table.concat(formatters, ", "))
	end
	table.insert(lines, "")

	table.insert(lines, "● Linter:")
	local linters = AdapterScanner:tools_for_filetype("linter", ft, { check_executable = true })
	if #linters == 0 then
		table.insert(lines, "  State: 🛑 None configured or available.")
	else
		table.insert(lines, "  Configured: " .. table.concat(linters, ", "))
	end

	return lines
end

function M.open_debug_window()
	local lines = get_engine_status()

	local width = 60
	local height = #lines + 2
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "single",
		title = " Backend Debug Status ",
		title_pos = "center",
	}

	local win = vim.api.nvim_open_win(buf, true, opts)

	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.keymap.set("n", "q", function()
		pcall(vim.api.nvim_win_close, win, true)
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", function()
		pcall(vim.api.nvim_win_close, win, true)
	end, { buffer = buf, silent = true })
end

M.hydra = Hydra.new({
	name = "Debug",
	fg_color = "yellow_bright",
	bg_color = "black",
	enter = "<leader>v",
	heads = {
		{ "s", M.open_debug_window, "Show Backend Engine Status" },
	},
})

return M
