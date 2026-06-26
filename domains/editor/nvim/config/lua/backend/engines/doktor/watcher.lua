local a = require("plenary.async")
local cache = require("backend.engines.doktor.cache")
local logging = require("backend.engines.doktor.logging")

local M = {}
local log = logging.for_module("watcher")

---@class DoktorWatcher
---@field package _config DoktorConfig
---@field package _graph Graph
---@field package _provider ProviderRegistry
---@field package _resolver ResolverRegistry
---@field package _scheduler Scheduler
---@field package _timers table<integer, uv.uv_timer_t>
---@field package _fs_timers table<string, uv.uv_timer_t>
---@field package _fs_handles uv.uv_fs_event_t[]
---@field package _watched_dirs table<string, true>
local DoktorWatcher = {}
DoktorWatcher.__index = DoktorWatcher

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
		_fs_timers = {},
		_fs_handles = {},
		_watched_dirs = {},
	}, DoktorWatcher)
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
---@param cascade table
---@param filetype string
---@param priority DoktorPriority
local function enqueue_cascade(self, cascade, filetype, priority)
	local source_priority = priority
	self._scheduler:enqueue_diagnostics(cascade.source, filetype, source_priority)

	for _, dependent_path in ipairs(cascade.direct) do
		local node = self._graph:get(dependent_path)
		local dependent_ft = node and node.filetype or filetype
		self._scheduler:enqueue_diagnostics(dependent_path, dependent_ft, 1)
	end

	for _, dependent_path in ipairs(cascade.transitive) do
		local node = self._graph:get(dependent_path)
		local dependent_ft = node and node.filetype or filetype
		self._scheduler:enqueue_diagnostics(dependent_path, dependent_ft, 2)
	end
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
	local cascade = self._graph:apply(path, resolved)
	enqueue_cascade(self, cascade, filetype, priority)
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
---@param path string
local function debounce_fs_path(self, path)
	if self._fs_timers[path] then
		self._fs_timers[path]:stop()
		self._fs_timers[path]:close()
	end

	local timer = vim.uv.new_timer()
	self._fs_timers[path] = timer
	timer:start(self._config.debounce_ms, 0, function()
		vim.schedule(function()
			self._fs_timers[path] = nil
			local filetype = vim.filetype.match({ filename = path }) or ""
			if filetype == "" or not self._provider:get(filetype) then
				return
			end

			self._graph:upsert(path, filetype)
			analyze_path(self, path, filetype, 0)
		end)
	end)
end

---@param self DoktorWatcher
---@param dir string
local function watch_directory(self, dir)
	if self._watched_dirs[dir] then
		return
	end

	self._watched_dirs[dir] = true

	local ok, handle = pcall(vim.uv.new_fs_event, dir, function(_, filename)
		if not filename or filename == "" then
			return
		end

		local path = dir .. "/" .. filename
		debounce_fs_path(self, path)
	end)

	if ok and handle then
		self._fs_handles[#self._fs_handles + 1] = handle
	end
end

---@param self DoktorWatcher
---@param dir string
---@param stack string[]
local function collect_dirs(self, dir, stack)
	if SKIP_DIRS[vim.fn.fnamemodify(dir, ":t")] then
		return
	end

	stack[#stack + 1] = dir
	watch_directory(self, dir)

	local scanner = vim.uv.fs_scandir(dir)
	if not scanner then
		return
	end

	while true do
		local name, kind = vim.uv.fs_scandir_next(scanner)
		if not name then
			break
		end

		if kind == "directory" and not SKIP_DIRS[name] then
			collect_dirs(self, dir .. "/" .. name, stack)
		end
	end
end

---@param self DoktorWatcher
---@param root string
local function setup_fs_watchers(self, root)
	local recursive_ok, recursive_handle = pcall(vim.uv.new_fs_event, root, function(_, filename)
		if not filename or filename == "" then
			return
		end

		local path = root .. "/" .. filename
		debounce_fs_path(self, path)
	end, { recursive = true })

	if recursive_ok and recursive_handle then
		self._fs_handles[#self._fs_handles + 1] = recursive_handle
		return
	end

	local dirs = {}
	collect_dirs(self, root, dirs)
end

function DoktorWatcher:bootstrap()
	a.void(function()
		local loaded = cache.load(self._config)
		if loaded then
			self._graph:hydrate(loaded:serialize())
		end

		a.util.scheduler()

		local root = vim.fn.getcwd()
		setup_fs_watchers(self, root)

		local stack = { root }
		local batch = {}

		local function flush_batch()
			for _, entry in ipairs(batch) do
				self._graph:upsert(entry.path, entry.filetype)
				self._scheduler:enqueue_diagnostics(entry.path, entry.filetype, 3)
			end
			batch = {}
			a.util.scheduler()
		end

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
							batch[#batch + 1] = { path = path, filetype = filetype }
							if #batch >= self._config.bootstrap.max_files_per_tick then
								flush_batch()
							end
						end
					end
				end
			end

			a.util.scheduler()
		end

		if #batch > 0 then
			flush_batch()
		end

		cache.save(self._graph, self._config)
	end)()
end

function DoktorWatcher:setup()
	local group = vim.api.nvim_create_augroup("DoktorWatcher", { clear = true })

	vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged" }, {
		group = group,
		callback = function(event)
			debounce_buffer(self, event.buf)
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "*",
		callback = function(event)
			local data = event.data or {}
			if not data.client_id or not data.bufnr then
				return
			end

			local bufnr = data.bufnr
			if not vim.api.nvim_buf_is_valid(bufnr) then
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
function DoktorWatcher:rescan(path)
	local target = path ~= "" and path or vim.api.nvim_buf_get_name(0)
	if target == "" then
		log:warn(":DoktorRescan ignored — no path and no named buffer")
		return
	end

	local filetype = vim.filetype.match({ filename = target }) or vim.bo.filetype
	analyze_path(self, target, filetype, 0)
	a.void(function()
		cache.save(self._graph, self._config)
	end)()
end

M.Watcher = DoktorWatcher

return M
