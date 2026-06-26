---@type Logger
local logger = require("frontend.navigation.doktor.logger")
local runner = require("frontend.navigation.doktor.engine.runner")
local parser = require("frontend.navigation.doktor.engine.parser")
local Guard = require("frontend.navigation.doktor.engine.guard")
local AdapterScanner = require("backend.shared.AdapterScanner")
local AdapterTool = require("backend.shared.AdapterTool")

local M = {}

---@type DoktorGuard?
local guard = nil

---@param adapter Adapter
---@param filetype string
---@param cwd string
---@param config DoktorConfig
---@return DoktorJobSpec?
local function resolve_compiler_job(adapter, filetype, cwd, config)
	---@type string|nil
	local doktor = adapter.doktor
	if not doktor then
		return nil
	end

	---@type DoktorJobOverride|nil
	local override = config.adapter_overrides[filetype]
		and config.adapter_overrides[filetype].compiler

	---@type string[]|fun():string[]|nil
	local raw_cmd = override and override.cmd or adapter.doktor_cmd
	---@type string[]
	local cmd = AdapterTool.resolve_cmd(raw_cmd) or {}

	if #cmd == 0 then
		logger:debug(function()
			return string.format("No doktor_cmd for filetype '%s', skipping compiler", filetype)
		end)
		return nil
	end

	---@type string
	local compiler_profile = (override and override.compiler) or adapter.doktor_compiler or doktor

	return {
		cmd = cmd,
		cwd = cwd,
		compiler = compiler_profile,
		kind = "compiler",
		filetypes = { filetype },
	}
end

---@param adapter Adapter
---@param filetype string
---@param cwd string
---@param config DoktorConfig
---@return DoktorJobSpec?
local function resolve_linter_job(adapter, filetype, cwd, config)
	---@type string|nil
	local doktor_linter = adapter.doktor_linter
	if not doktor_linter then
		return nil
	end

	---@type DoktorJobOverride|nil
	local override = config.adapter_overrides[filetype]
		and config.adapter_overrides[filetype].linter

	---@type string[]|fun():string[]|nil
	local raw_cmd = override and override.cmd or adapter.doktor_linter_cmd
	---@type string[]
	local cmd = AdapterTool.resolve_cmd(raw_cmd) or {}

	if #cmd == 0 then
		logger:debug(function()
			return string.format("No doktor_linter_cmd for filetype '%s', skipping linter", filetype)
		end)
		return nil
	end

	---@type string
	local compiler_profile = (override and override.compiler) or adapter.doktor_linter_compiler or doktor_linter

	return {
		cmd = cmd,
		cwd = cwd,
		compiler = compiler_profile,
		kind = "linter",
		filetypes = { filetype },
	}
end

---@param filetype string
---@param cwd string
---@param config DoktorConfig
---@return DoktorJobSpec[]
local function resolve_jobs(filetype, cwd, config)
	---@type DoktorJobSpec[]
	local jobs = {}

	---@type table<string, Adapter>|nil
	local adapters = AdapterScanner:adapters()
	if not adapters then
		return jobs
	end

	for _, adapter in pairs(adapters) do
		---@type boolean
		local matches_filetype = false
		for _, ft in ipairs(adapter.filetypes) do
			if ft == filetype then
				matches_filetype = true
				break
			end
		end
		if not matches_filetype then
			goto continue
		end

		---@type DoktorJobSpec?
		local compiler_job = resolve_compiler_job(adapter, filetype, cwd, config)
		if compiler_job then
			table.insert(jobs, compiler_job)
		end

		---@type DoktorJobSpec?
		local linter_job = resolve_linter_job(adapter, filetype, cwd, config)
		if linter_job then
			table.insert(jobs, linter_job)
		end

		::continue::
	end

	return jobs
end

---@param filetype string
---@param workspace_ns integer
---@param config DoktorConfig
---@param on_complete fun()
---@return nil
local function run_scan(filetype, workspace_ns, config, on_complete)
	---@type string
	local cwd = vim.fn.getcwd()

	logger:info(function()
		return string.format("Scan started: filetype='%s', cwd='%s'", filetype, cwd)
	end)

	---@type DoktorJobSpec[]
	local jobs = resolve_jobs(filetype, cwd, config)

	if #jobs == 0 then
		logger:debug(function()
			return string.format("No doktor jobs for filetype '%s'", filetype)
		end)
		on_complete()
		return
	end

	logger:info(function()
		return string.format("Resolved %d jobs for filetype '%s'", #jobs, filetype)
	end)

	---@type integer
	local remaining = #jobs

	---@param result DoktorRunResult
	local function on_job_complete(result)
		parser.parse_and_set(result, result.compiler, workspace_ns)
		remaining = remaining - 1
		if remaining <= 0 then
			on_complete()
		end
	end

	for _, job in ipairs(jobs) do
		runner.run(job, on_job_complete)
	end
end

---@param workspace_ns integer
---@param config DoktorConfig
---@return nil
function M.setup(workspace_ns, config)
	---@type fun()
	local scan_fn = function()
	end

	guard = Guard.new(function()
		scan_fn()
	end)

	---@type fun()
	scan_fn = function()
		---@type integer
		local bufnr = vim.api.nvim_get_current_buf()
		---@type string
		local filetype = vim.bo[bufnr].filetype

		if filetype == "" then
			logger:debug(function()
				return "Skipping scan: empty filetype"
			end)
			guard:release()
			return
		end

		---@type string
		local buftype = vim.bo[bufnr].buftype
		---@type string
		local bufname = vim.api.nvim_buf_get_name(bufnr)

		if buftype ~= "" or bufname == "" then
			logger:debug(function()
				return string.format("Skipping scan: buftype='%s', bufname='%s'", buftype, bufname)
			end)
			guard:release()
			return
		end

		run_scan(filetype, workspace_ns, config, function()
			if guard then
				guard:release()
			end
		end)
	end

	if config.auto_start then
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = vim.api.nvim_create_augroup("DoktorWorkspaceScan", { clear = true }),
			callback = function()
				if guard then
					if guard:try_acquire() then
						scan_fn()
					end
				end
			end,
		})
	end
end

---@param filetype string
---@param workspace_ns integer
---@param config DoktorConfig
---@return nil
function M.trigger_scan(filetype, workspace_ns, config)
	logger:info(function()
		return string.format("Manual scan triggered for filetype '%s'", filetype)
	end)

	if guard and not guard:try_acquire() then
		return
	end

	run_scan(filetype, workspace_ns, config, function()
		if guard then
			guard:release()
		end
	end)
end

return M
