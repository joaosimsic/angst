---@type Keybinder
local Keybinder = require("common.Keybinder")
local AdapterScanner = require("backend.shared.AdapterScanner")

local filetype_extensions = {
	python = "py",
	go = "go",
	rust = "rs",
	javascript = "js",
	javascriptreact = "jsx",
	typescript = "ts",
	typescriptreact = "tsx",
	lua = "lua",
	bash = "sh",
	sh = "sh",
	zsh = "sh",
	c = "c",
	cpp = "cpp",
	java = "java",
	php = "php",
	blade = "blade.php",
	nix = "nix",
	["yaml.docker-compose"] = "yaml",
	terraform = "tf",
	tf = "tf",
	prisma = "prisma",
	html = "html",
	htmldjango = "html",
	css = "css",
	scss = "scss",
	less = "less",
	json = "json",
	jsonc = "jsonc",
	vue = "vue",
	toml = "toml",
	xml = "xml",
	conf = "conf",
	dockerfile = "",
}

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

local function resolve_placeholders(cmd, filepath)
	local base = vim.fn.fnamemodify(filepath, ":r")
	local name = vim.fn.fnamemodify(filepath, ":t")
	local resolved = {}
	for _, arg in ipairs(cmd) do
		if arg == "$FILE" then
			table.insert(resolved, filepath)
		elseif arg == "$FILEBASE" then
			table.insert(resolved, base)
		elseif arg == "$FILENAME" then
			table.insert(resolved, name)
		else
			table.insert(resolved, (arg:gsub("%$FILE", filepath):gsub("%$FILEBASE", base):gsub("%$FILENAME", name)))
		end
	end
	return resolved
end

local function ensure_scratch_dir()
	local dir = vim.fn.stdpath("cache") .. "/scratch"
	vim.fn.mkdir(dir, "p")
	return dir
end

local function get_scratch_filepath(ft)
	local ext = filetype_extensions[ft] or ft
	local suffix = ext ~= "" and "." .. ext or ""
	local dir = ensure_scratch_dir()
	return dir .. "/scratch_" .. vim.fn.strftime("%Y%m%d_%H%M%S") .. suffix
end

local tmp_filepath = nil

local function get_temp_filepath(ft)
	if tmp_filepath then
		return tmp_filepath
	end
	local ext = filetype_extensions[ft] or ft
	local suffix = ext ~= "" and "." .. ext or ""
	tmp_filepath = vim.fn.tempname() .. suffix
	return tmp_filepath
end

local function save_to_temp(buf, ft)
	local filepath = get_temp_filepath(ft)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local content = table.concat(lines, "\n")

	local fd = io.open(filepath, "w")
	if not fd then
		vim.notify("Failed to write temp file: " .. filepath, vim.log.levels.ERROR)
		return nil
	end
	fd:write(content)
	fd:close()

	return filepath
end

local out_buf = nil
local out_win = nil
local process = nil

local function run_compiler(buf)
	local ft = vim.bo[buf].filetype
	if not ft or ft == "" then
		vim.notify("No filetype set on scratch buffer")
		return
	end

	local scanner = AdapterScanner.new()
	local compiler_tools = scanner:by_filetype("compiler")
	local tool_names = compiler_tools[ft]

	if not tool_names or #tool_names == 0 then
		vim.notify("No compiler configured for filetype '" .. ft .. "'")
		return
	end

	local all_compilers = scanner:by_tool("compiler")
	local compiler_name = tool_names[1]
	local compiler_info = all_compilers[compiler_name]

	local raw_cmd = compiler_info.cmd
	if not raw_cmd then
		vim.notify("No compiler command for '" .. compiler_name .. "'")
		return
	end

	local cmd = type(raw_cmd) == "function" and raw_cmd() or raw_cmd

	local filepath = save_to_temp(buf, ft)
	if not filepath then
		return
	end

	cmd = resolve_placeholders(cmd, filepath)

	if process then
		pcall(function()
			process:kill(9)
		end)
		process = nil
	end

	if out_buf and not vim.api.nvim_buf_is_valid(out_buf) then
		out_buf = nil
	end
	if out_win and not vim.api.nvim_win_is_valid(out_win) then
		out_win = nil
	end

	if out_buf then
		vim.bo[out_buf].modifiable = true
		vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, {
			"Running: " .. table.concat(cmd, " "),
			"",
		})
		vim.bo[out_buf].modifiable = false

		if out_win then
			vim.api.nvim_win_set_buf(out_win, out_buf)
		end
		vim.api.nvim_win_set_height(out_win or vim.api.nvim_get_current_win(), 12)
	else
		local orig_win = vim.api.nvim_get_current_win()
		vim.cmd("botright split")
		out_win = vim.api.nvim_get_current_win()
		out_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(out_win, out_buf)
		vim.bo[out_buf].bufhidden = "wipe"
		vim.bo[out_buf].buflisted = false
		vim.api.nvim_win_set_height(out_win, 12)

		vim.bo[out_buf].modifiable = true
		vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, {
			"Running: " .. table.concat(cmd, " "),
			"",
		})
		vim.bo[out_buf].modifiable = false

		local out_binder = Keybinder.new(out_buf, "SCRATCH_OUT")
		out_binder:nmap("q", function()
			if vim.api.nvim_buf_is_valid(out_buf) then
				vim.api.nvim_buf_delete(out_buf, { force = true })
				out_buf = nil
				out_win = nil
			end
		end, { desc = "Close output buffer" })

		vim.api.nvim_set_current_win(orig_win)
	end

	if not out_win or not vim.api.nvim_win_is_valid(out_win) then
		local orig_win = vim.api.nvim_get_current_win()
		vim.cmd("botright split")
		out_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(out_win, out_buf)
		vim.api.nvim_set_current_win(orig_win)
	end

	process = vim.system(cmd, { text = true }, function(result)
		process = nil
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(out_buf) then
				return
			end

			local lines = {}

			if result.stdout and result.stdout ~= "" then
				for line in vim.gsplit(result.stdout, "\n", { plain = true }) do
					table.insert(lines, line)
				end
			end

			if result.stderr and result.stderr ~= "" then
				if #lines > 0 then
					table.insert(lines, "")
				end
				table.insert(lines, "--- stderr ---")
				for line in vim.gsplit(result.stderr, "\n", { plain = true }) do
					table.insert(lines, line)
				end
			end

			local status = result.code == 0 and "Success" or "Exit code: " .. result.code
			table.insert(lines, 1, "[" .. status .. "] " .. table.concat(cmd, " "))

			vim.bo[out_buf].modifiable = true
			vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, lines)
			vim.bo[out_buf].modifiable = false
		end)
	end)
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

		vim.cmd("tabnew")
		local buf = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_win_set_buf(0, buf)
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].buflisted = false
		vim.bo[buf].swapfile = false
		local scratch_path = get_scratch_filepath(choice)
		vim.api.nvim_buf_set_name(buf, scratch_path)
		vim.api.nvim_exec_autocmds("BufNewFile", { buffer = buf })
		vim.bo[buf].filetype = choice

		local binder = Keybinder.new(buf, "SCRATCH")
		binder:nmap("q", function()
			if vim.api.nvim_buf_is_valid(buf) then
				if tmp_filepath then
					pcall(os.remove, tmp_filepath)
					tmp_filepath = nil
				end
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end, { desc = "Close scratch buffer" })
		binder:nmap("r", function()
			run_compiler(buf)
		end, { desc = "Run compiler" })
	end)
end

---@type Plugin
return {
	"scratch",
	virtual = true,
	lazy = false,
	config = function()
		local binder = Keybinder.new(nil, "SCRATCH")
		binder:nmap("<leader>n", open_scratch, { desc = "Open scratch buffer" })
	end,
}
