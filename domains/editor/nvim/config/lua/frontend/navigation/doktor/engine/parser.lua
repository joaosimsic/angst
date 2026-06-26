---@type Logger
local logger = require("frontend.navigation.doktor.logger")

local M = {}

---@type string
local FALLBACK_EFM = [[%f: line %l\, col %c\, %m]]

---@param profile_name string
---@return boolean
local function activate_compiler_profile(profile_name)
	local ok = pcall(vim.cmd, "compiler " .. profile_name)
	if not ok then
		logger:warn(function()
			return string.format("Compiler profile '%s' not found, using fallback errorformat", profile_name)
		end)
		vim.opt.errorformat = FALLBACK_EFM
		return false
	end
	logger:debug(function()
		return string.format("Compiler profile '%s' activated", profile_name)
	end)
	return true
end

---@param result DoktorRunResult
---@param compiler_profile string
---@param workspace_ns integer
---@return nil
function M.parse_and_set(result, compiler_profile, workspace_ns)
	---@type string
	local raw_output = result.stderr ~= "" and result.stderr or result.stdout

	if raw_output == "" then
		logger:debug(function()
			return string.format("Empty output from %s job, clearing namespace", result.kind)
		end)
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.diagnostic.set(workspace_ns, bufnr, {})
			end
		end
		return
	end

	---@type integer
	local scratch_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buf].bufhidden = "wipe"
	vim.bo[scratch_buf].buftype = "nofile"

	vim.api.nvim_set_current_buf(scratch_buf)

	activate_compiler_profile(compiler_profile)

	---@type string[]
	local output_lines = vim.split(raw_output, "\n", { plain = true, trimempty = true })

	vim.fn.setqflist({}, " ", {
		lines = output_lines,
		efm = vim.opt.errorformat:get(),
	})

	---@type table[]
	local qf_items = vim.fn.getqflist()

	---@type table<string, vim.Diagnostic[]>
	local diags_by_bufname = {}

	for _, item in ipairs(qf_items) do
		---@type string
		local filename = item.filename or ""
		if filename ~= "" then
			---@type string
			local full_path = vim.fn.fnamemodify(filename, ":p")

			if not diags_by_bufname[full_path] then
				diags_by_bufname[full_path] = {}
			end

			---@type vim.diagnostic.Severity
			local severity = vim.diagnostic.severity.ERROR
			if item.type == "W" or item.type == "w" then
				severity = vim.diagnostic.severity.WARN
			elseif item.type == "I" or item.type == "i" then
				severity = vim.diagnostic.severity.INFO
			elseif item.type == "H" or item.type == "h" then
				severity = vim.diagnostic.severity.HINT
			end

			---@type vim.Diagnostic
			local diag = {
				lnum = (item.lnum or 1) - 1,
				col = (item.col or 1) - 1,
				message = item.text or "",
				severity = severity,
				source = result.cmd[1],
			}
			table.insert(diags_by_bufname[full_path], diag)
		end
	end

	for full_path, diags in pairs(diags_by_bufname) do
		---@type integer
		local target_bufnr = vim.fn.bufnr(full_path)
		if target_bufnr == -1 then
			target_bufnr = vim.fn.bufadd(full_path)
			logger:debug(function()
				return string.format("Buffer added for path: %s", full_path)
			end)
		end
		if vim.api.nvim_buf_is_valid(target_bufnr) then
			vim.diagnostic.set(workspace_ns, target_bufnr, diags)
		end
	end

	vim.fn.setqflist({}, "r")
	vim.api.nvim_buf_delete(scratch_buf, { force = true })

	logger:info(function()
		---@type integer
		local total = 0
		for _, diags in pairs(diags_by_bufname) do
			total = total + #diags
		end
		return string.format("Parsed %d diagnostics from %s job", total, result.kind)
	end)
end

return M
