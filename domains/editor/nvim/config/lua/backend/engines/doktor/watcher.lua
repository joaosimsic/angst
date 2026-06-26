local cache = require("backend.engines.doktor.cache")
local logging = require("backend.engines.doktor.logging")

local M = {}
local log = logging.for_module("watcher")

---@class DoktorWatcher
---@field private _config DoktorConfig
---@field private _graph Graph
---@field private _provider ProviderRegistry
---@field private _resolver ResolverRegistry
---@field private _scheduler Scheduler
---@field private _timers table<integer, uv.uv_timer_t>
local Watcher = {}
Watcher.__index = Watcher

local SKIP_DIRS = {
	[".git"] = true,
	[".hg"] = true,
	[".svn"] = true,
	["node_modules"] = true,
	[".direnv"] = true,
	["target"] = true,
	["dist"] = true,
	["build"] = true,
}

---@param opts { config: DoktorConfig, graph: Graph, provider: ProviderRegistry, resolver: ResolverRegistry, scheduler: Scheduler }
---@return DoktorWatcher
function M.new(opts)
	return setmetatable({
		_config = opts.config,
		_graph = opts.graph,
		_provider = opts.provider,
		_resolver = opts.resolver,
		_scheduler = opts.scheduler,
		_timers = {},
	}, Watcher)
end

---@param path string
---@return integer
local function buffer_for_path(path)
	local bufnr = vim.fn.bufnr(path)
	if bufnr ~= -1 then
		return bufnr
	end

	bufnr = vim.fn.bufadd(path)
	pcall(vim.fn.bufload, bufnr)
	return bufnr
end

---@param self DoktorWatcher
---@param path string
---@param filetype string
---@param priority DoktorPriority
local function analyze_path(self, path, filetype, priority)
	if filetype == "" then
		return
	end

	local bufnr = buffer_for_path(path)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.bo[bufnr].filetype = filetype
	self._graph:upsert(path, filetype)

	local data = self._provider:analyze(bufnr)
	if not data then
		log:debug(function()
			return string.format("no provider data path=%s ft=%s", path, filetype)
		end)
		self._scheduler:enqueue_diagnostics(path, filetype, priority)
		return
	end

	local resolved = self._resolver:resolve_data(data, bufnr)
	local invalidated = self._graph:apply(path, resolved)

	for index, invalidated_path in ipairs(invalidated) do
		local invalidated_node = self._graph:get(invalidated_path)
		local invalidated_ft = invalidated_node and invalidated_node.filetype or filetype
		local invalidated_priority = priority
		if index == 2 then
			invalidated_priority = 1
		elseif index > 2 then
			invalidated_priority = 2
		end

		self._scheduler:enqueue_diagnostics(invalidated_path, invalidated_ft, invalidated_priority)
	end
end

---@param self DoktorWatcher
---@param bufnr integer
local function debounce_buffer(self, bufnr)
	if self._timers[bufnr] then
		self._timers[bufnr]:stop()
		self._timers[bufnr]:close()
	end

	local timer = vim.uv.new_timer()
	self._timers[bufnr] = timer
	timer:start(self._config.debounce_ms, 0, function()
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local path = vim.api.nvim_buf_get_name(bufnr)
			local filetype = vim.bo[bufnr].filetype
			if path ~= "" and vim.bo[bufnr].buftype == "" then
				analyze_path(self, path, filetype, 0)
			end
		end)
	end)
end

---@param self DoktorWatcher
---@param root string
---@return string[]
local function collect_workspace_files(self, root)
	local files = {}
	local stack = { root }

	while #stack > 0 do
		local dir = table.remove(stack)
		local scanner = vim.uv.fs_scandir(dir)
		if scanner then
			while true do
				local name, kind = vim.uv.fs_scandir_next(scanner)
				if not name then
					break
				end

				local path = dir .. "/" .. name
				if kind == "directory" and not SKIP_DIRS[name] then
					stack[#stack + 1] = path
				elseif kind == "file" then
					local filetype = vim.filetype.match({ filename = path }) or ""
					if self._provider:get(filetype) then
						files[#files + 1] = path
					end
				end
			end
		end
	end

	table.sort(files)
	return files
end

function Watcher:bootstrap()
	local loaded = cache.load(self._config)
	if loaded then
		self._graph:hydrate(loaded:serialize())
	end

	local files = collect_workspace_files(self, vim.fn.getcwd())
	local index = 1

	local function step()
		local limit = math.min(#files, index + self._config.bootstrap.max_files_per_tick - 1)
		while index <= limit do
			local path = files[index]
			local filetype = vim.filetype.match({ filename = path }) or ""
			self._graph:upsert(path, filetype)
			self._scheduler:enqueue_diagnostics(path, filetype, 3)
			index = index + 1
		end

		if index <= #files then
			vim.defer_fn(step, 0)
		else
			cache.save(self._graph, self._config)
		end
	end

	step()
end

function Watcher:setup()
	local group = vim.api.nvim_create_augroup("DoktorWatcher", { clear = true })

	vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(event)
			debounce_buffer(self, event.buf)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "DoktorLspReady",
		callback = function(event)
			local data = event.data or {}
			local bufnr = data.bufnr
			if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local path = vim.api.nvim_buf_get_name(bufnr)
			local filetype = data.filetype or vim.bo[bufnr].filetype
			if path ~= "" then
				vim.diagnostic.reset(self._scheduler:namespaces().lsp, bufnr)
				self._scheduler:enqueue_diagnostics(path, filetype, 0)
				self._scheduler:drain_pending_lsp(filetype)
				log:debug(function()
					return string.format("lsp ready path=%s ft=%s", path, filetype)
				end)
			end
		end,
	})

	if self._config.bootstrap.on_vim_enter then
		vim.api.nvim_create_autocmd("VimEnter", {
			group = group,
			once = true,
			callback = function()
				self:bootstrap()
			end,
		})
	end
end

---@param path string
function Watcher:rescan(path)
	local target = path ~= "" and path or vim.api.nvim_buf_get_name(0)
	if target == "" then
		self:bootstrap()
		return
	end

	local filetype = vim.filetype.match({ filename = target }) or vim.bo.filetype
	analyze_path(self, target, filetype, 0)
	cache.save(self._graph, self._config)
end

M.Watcher = Watcher

return M
