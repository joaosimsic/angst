local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local function reset_adapters()
	package.loaded["backend.adapters"] = nil
	local scanner = require("backend.shared.AdapterScanner")
	scanner.adapters_cache = nil
	scanner.tool_cache = {}
	scanner.filetype_cache = {}
	scanner.executable_cache = {}
end

local function with_temp_buf(filetype, fn)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "/tmp/test_" .. filetype .. ".txt")
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf })
	vim.api.nvim_set_current_buf(buf)
	local ok, err = pcall(fn, buf)
	vim.api.nvim_buf_delete(buf, { force = true })
	if not ok then
		error(err)
	end
end

return function(t)
	describe("startup lazy loading", function()
		it("should not load adapters at module level when requiring lsp/init.lua", function()
			reset_adapters()
			package.loaded["backend.engines.lsp"] = nil

			local lsp_spec = require("backend.engines.lsp")

			assert(type(lsp_spec) == "table", "lsp engine should return a table spec")
			assert(
				not package.loaded["backend.adapters"],
				"backend.adapters should NOT be loaded after requiring lsp/init.lua"
			)
		end)

		it("should use event instead of ft in lsp/init.lua", function()
			package.loaded["backend.engines.lsp"] = nil
			local lsp_spec = require("backend.engines.lsp")

			assert(type(lsp_spec.event) == "table", "lsp spec should have an event table")
			local has_buf_trigger = false
			for _, e in ipairs(lsp_spec.event) do
				if e == "BufReadPre" or e == "BufNewFile" then
					has_buf_trigger = true
				end
			end
			assert(has_buf_trigger, "lsp spec should trigger on BufReadPre or BufNewFile")
			assert(lsp_spec.ft == nil, "lsp spec should NOT have ft (replaced by event)")
		end)

		it("lsp config should load adapters inside setup(), not at module level", function()
			reset_adapters()
			package.loaded["backend.engines.lsp.config"] = nil

			local config_module = require("backend.engines.lsp.config")

			assert(
				not package.loaded["backend.adapters"],
				"backend.adapters should NOT be loaded when requiring config.lua at module level"
			)

			with_temp_buf("rust", function()
				config_module.setup()
			end)

			assert(
				package.loaded["backend.adapters"],
				"backend.adapters should be loaded after config.setup() runs"
			)
		end)

		it("should not enable any LSP for an unknown filetype", function()
			reset_adapters()
			package.loaded["backend.engines.lsp.config"] = nil
			pcall(vim.api.nvim_del_augroup_by_name, "LspDynamicEnable")

			local enabled = {}
			local orig_lsp_config = vim.lsp.config
			local orig_lsp_enable = vim.lsp.enable

			local stub_config = setmetatable({}, {
				__index = function()
					return {}
				end,
				__call = function(_, name, _)
					enabled[name] = (enabled[name] or 0) + 1
				end,
			})
			vim.lsp.config = stub_config
			vim.lsp.enable = function(name)
				enabled[name] = (enabled[name] or 0) + 1
			end

			local config_module = require("backend.engines.lsp.config")
			with_temp_buf("unknown_filetype_xyz", function()
				config_module.setup()
			end)

			vim.lsp.config = orig_lsp_config
			vim.lsp.enable = orig_lsp_enable

			local enabled_names = vim.tbl_keys(enabled)
			assert(
				#enabled_names == 0,
				"no LSP should be enabled for unknown filetype, got: " .. vim.inspect(enabled_names)
			)
		end)

		it("should enable only rust_analyzer for filetype 'rust'", function()
			reset_adapters()
			package.loaded["backend.engines.lsp.config"] = nil
			pcall(vim.api.nvim_del_augroup_by_name, "LspDynamicEnable")

			local enabled = {}
			local orig_lsp_config = vim.lsp.config
			local orig_lsp_enable = vim.lsp.enable
			local scanner = require("backend.shared.AdapterScanner")
			local orig_executable = scanner.executable_exists
			scanner.executable_exists = function()
				return true
			end

			local stub_config = setmetatable({}, {
				__index = function()
					return {}
				end,
				__call = function(_, name, _)
					enabled[name] = (enabled[name] or 0) + 1
				end,
			})
			vim.lsp.config = stub_config
			vim.lsp.enable = function(name)
				enabled[name] = (enabled[name] or 0) + 1
			end

			local config_module = require("backend.engines.lsp.config")
			with_temp_buf("rust", function()
				config_module.setup()
			end)

			vim.lsp.config = orig_lsp_config
			vim.lsp.enable = orig_lsp_enable
			scanner.executable_exists = orig_executable

			local enabled_names = vim.tbl_keys(enabled)
			assert(#enabled_names > 0, "at least one LSP should be enabled for rust")

			local has_ra = false
			local unexpected = {}
			for _, name in ipairs(enabled_names) do
				if name == "rust_analyzer" then
					has_ra = true
				else
					table.insert(unexpected, name)
				end
			end

			assert(has_ra, "rust_analyzer should be enabled for filetype 'rust', got: " .. vim.inspect(enabled_names))
			assert(
				#unexpected == 0,
				"only rust_analyzer should be enabled for 'rust', got: " .. vim.inspect(unexpected)
			)
		end)

		it("should enable only ts_ls for filetype 'typescript'", function()
			reset_adapters()
			package.loaded["backend.engines.lsp.config"] = nil
			pcall(vim.api.nvim_del_augroup_by_name, "LspDynamicEnable")

			local enabled = {}
			local orig_lsp_config = vim.lsp.config
			local orig_lsp_enable = vim.lsp.enable
			local scanner = require("backend.shared.AdapterScanner")
			local orig_executable = scanner.executable_exists
			scanner.executable_exists = function()
				return true
			end

			local stub_config = setmetatable({}, {
				__index = function()
					return {}
				end,
				__call = function(_, name, _)
					enabled[name] = (enabled[name] or 0) + 1
				end,
			})
			vim.lsp.config = stub_config
			vim.lsp.enable = function(name)
				enabled[name] = (enabled[name] or 0) + 1
			end

			local config_module = require("backend.engines.lsp.config")
			with_temp_buf("typescript", function()
				config_module.setup()
			end)

			vim.lsp.config = orig_lsp_config
			vim.lsp.enable = orig_lsp_enable
			scanner.executable_exists = orig_executable

			local enabled_names = vim.tbl_keys(enabled)
			assert(#enabled_names > 0, "at least one LSP should be enabled for typescript")
			assert(
				enabled["ts_ls"],
				"ts_ls should be enabled for filetype 'typescript', got: " .. vim.inspect(enabled_names)
			)

			local unexpected = {}
			for _, name in ipairs(enabled_names) do
				if name ~= "ts_ls" then
					table.insert(unexpected, name)
				end
			end
			assert(
				#unexpected == 0,
				"only ts_ls should be enabled for 'typescript', got: " .. vim.inspect(unexpected)
			)
		end)

		it("should use event instead of ft in formatter.lua", function()
			package.loaded["backend.engines.formatter"] = nil
			local spec = require("backend.engines.formatter")
			assert(type(spec.event) == "table", "formatter spec should have event")
			assert(spec.ft == nil, "formatter spec should NOT have ft")
		end)

		it("should use event instead of ft in linter.lua", function()
			package.loaded["backend.engines.linter"] = nil
			local spec = require("backend.engines.linter")
			assert(type(spec.event) == "table", "linter spec should have event")
			assert(spec.ft == nil, "linter spec should NOT have ft")
		end)

		it("should use event instead of ft in treesitter.lua", function()
			package.loaded["backend.engines.treesitter"] = nil
			local spec = require("backend.engines.treesitter")
			assert(type(spec.event) == "table", "treesitter spec should have event")
			assert(spec.ft == nil, "treesitter spec should NOT have ft")
		end)
	end)
end
