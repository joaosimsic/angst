local Keybinder = require("common.Keybinder")

local out_buf = nil
local out_win = nil
local process = nil

local root_markers = { ".latexmkrc", ".texlabroot", "texlab.toml", ".git", "main.tex" }

local function find_root(start_path)
	local dir = vim.fn.fnamemodify(start_path, ":h")
	if dir == "" then
		dir = vim.fn.getcwd()
	end
	for _ = 1, 10 do
		for _, marker in ipairs(root_markers) do
			local candidate = dir .. "/" .. marker
			if vim.fn.filereadable(candidate) == 1 or vim.fn.isdirectory(candidate) == 1 then
				return dir
			end
		end
		local parent = vim.fn.fnamemodify(dir, ":h")
		if parent == dir then
			break
		end
		dir = parent
	end
	return vim.fn.fnamemodify(start_path, ":h")
end

local function ensure_output_buf()
	if out_buf and vim.api.nvim_buf_is_valid(out_buf) then
		return out_buf
	end
	out_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[out_buf].bufhidden = "wipe"
	vim.bo[out_buf].buflisted = false
	vim.bo[out_buf].filetype = "log"
	return out_buf
end

local function show_output(lines, cmd)
	if out_buf and not vim.api.nvim_buf_is_valid(out_buf) then
		out_buf = nil
		out_win = nil
	end
	if process then
		pcall(function()
			process:kill(9)
		end)
		process = nil
	end
	local buf = ensure_output_buf()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	if out_win and vim.api.nvim_win_is_valid(out_win) then
		vim.api.nvim_win_set_buf(out_win, buf)
	else
		local orig = vim.api.nvim_get_current_win()
		vim.cmd("botright split")
		out_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(out_win, buf)
		vim.api.nvim_win_set_height(out_win, 14)
		local binder = Keybinder.new(buf, "TEX_OUT")
		binder:nmap("q", function()
			if vim.api.nvim_win_is_valid(out_win) then
				vim.api.nvim_win_close(out_win, true)
			end
			out_win = nil
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
				out_buf = nil
			end
		end, { desc = "Close tex output" })
		vim.api.nvim_set_current_win(orig)
	end
end

local function compile_tex(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	if ft ~= "tex" and ft ~= "plaintex" and ft ~= "latex" and ft ~= "bib" then
		vim.notify("Not a TeX file (filetype=" .. ft .. ")", vim.log.levels.WARN)
		return
	end
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		vim.notify("Buffer has no file name, save first", vim.log.levels.ERROR)
		return
	end
	-- save buffer
	if vim.bo[bufnr].modified then
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("silent write")
		end)
	end
	local root = find_root(filepath)
	local rel = vim.fn.fnamemodify(filepath, ":p")
	-- latexmk prefers to run from file's dir or root; use -cd and file path
	local cmd = { "latexmk", "-pdf", "-interaction=nonstopmode", "-cd", rel }
	local header = { "Running: " .. table.concat(cmd, " ") .. " (cwd: " .. root .. ")", "" }
	show_output(header, cmd)

	-- try to use latexmk, fallback to pdflatex if missing
	if vim.fn.executable("latexmk") ~= 1 then
		vim.notify("latexmk not found in PATH", vim.log.levels.ERROR)
		return
	end

	process = vim.system(cmd, { cwd = root, text = true }, function(result)
		process = nil
		vim.schedule(function()
			local lines = {}
			table.insert(lines, "[" .. (result.code == 0 and "Success" or "Exit code: " .. result.code) .. "] " .. table.concat(cmd, " "))
			table.insert(lines, "cwd: " .. root)
			table.insert(lines, "")
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
			if result.code == 0 then
				table.insert(lines, "")
				table.insert(lines, "✓ PDF generated (check " .. root .. ")")
			else
				table.insert(lines, "")
				table.insert(lines, "✗ Compilation failed — see errors above")
			end
			show_output(lines, cmd)
			if result.code == 0 then
				vim.notify("TeX compilation succeeded", vim.log.levels.INFO)
			else
				vim.notify("TeX compilation failed (exit " .. result.code .. ")", vim.log.levels.ERROR)
			end
		end)
	end)
end

local function compile_current()
	compile_tex(vim.api.nvim_get_current_buf())
end

---@type Plugin
return {
	"tex",
	virtual = true,
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		vim.api.nvim_create_user_command("TexCompile", function(opts)
			local target = opts.args ~= "" and vim.fn.expand(opts.args) or nil
			if target and target ~= "" then
				local bufnr = vim.fn.bufadd(target)
				vim.fn.bufload(bufnr)
				compile_tex(bufnr)
			else
				compile_current()
			end
		end, { nargs = "?", complete = "file", desc = "Compile TeX project with latexmk" })

		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "tex", "plaintex", "latex", "bib" },
			callback = function(args)
				local binder = Keybinder.new(args.buf, "TEX")
				binder:nmap("<leader>cc", compile_current, { desc = "Compile TeX project (latexmk)" })
				binder:nmap("<leader>cv", function()
					local root = find_root(vim.api.nvim_buf_get_name(args.buf))
					local pdf = root .. "/main.pdf"
					-- try to find any pdf in root
					if vim.fn.filereadable(pdf) ~= 1 then
						local pdfs = vim.fn.glob(root .. "/*.pdf", false, true)
						if #pdfs > 0 then
							pdf = pdfs[1]
						else
							vim.notify("No PDF found in " .. root, vim.log.levels.WARN)
							return
						end
					end
					vim.notify("PDF: " .. pdf, vim.log.levels.INFO)
				end, { desc = "Show PDF path" })
			end,
		})
	end,
}
