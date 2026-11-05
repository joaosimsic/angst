local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local function press(lhs)
	local map = vim.fn.maparg(lhs, "n", false, true)
	assert(
		type(map) == "table" and next(map) ~= nil and type(map.callback) == "function",
		"expected a lua mapping for " .. lhs
	)
	map.callback()
end

local function write(path, text)
	local file = assert(io.open(path, "w"))
	file:write(text)
	file:close()
end

return function()
	describe("reference search", function()
		it("shares dependency exclusions between fzf and ripgrep", function()
			local SearchIgnore = require("common.SearchIgnore")
			local fzf_ignore_patterns = SearchIgnore.fzf_ignore_patterns()
			local rg_ignore_globs = SearchIgnore.rg_ignore_globs()

			assert(vim.tbl_contains(fzf_ignore_patterns, "node_modules/"), "fzf must exclude node_modules")
			assert(vim.tbl_contains(fzf_ignore_patterns, "target/"), "fzf must exclude target")
			assert(vim.tbl_contains(rg_ignore_globs, "!**/node_modules/**"), "rg must exclude node_modules")
			assert(vim.tbl_contains(rg_ignore_globs, "!**/target/**"), "rg must exclude target")
			assert(SearchIgnore.is_ignored("/repo/node_modules/pkg/a.lua"), "LSP results must respect exclusions")
			assert(SearchIgnore.is_ignored("/repo/target/debug/a.lua"), "LSP results must respect exclusions")
			assert(SearchIgnore.is_ignored("/repo/Cargo.lock"), "noisy lock files must be ignored")
			assert(not SearchIgnore.is_ignored("/repo/src/a.lua"), "source files must stay visible")
		end)

		it("merges and dedupes lsp and ripgrep results", function()
			local sources = require("frontend.navigation.references.sources")
			local merged = sources.merge({
				{ filename = "/repo/b.lua", lnum = 2, col = 1, text = "b", source = "lsp" },
				{ filename = "/repo/a.lua", lnum = 3, col = 5, text = "a", source = "lsp" },
			}, {
				{ filename = "/repo/b.lua", lnum = 2, col = 1, text = "b", source = "rg" },
				{ filename = "/repo/a.lua", lnum = 1, col = 1, text = "a", source = "rg" },
			})

			assert(#merged == 3, "duplicate locations must collapse")
			assert(merged[1].filename == "/repo/a.lua" and merged[1].lnum == 1, "results must sort by file and line")
			assert(merged[2].lnum == 3, "second a.lua location must remain")
			assert(merged[3].filename == "/repo/b.lua", "b.lua must sort after a.lua")
		end)

		it("ripgrep skips ignored dependency directories", function()
			assert(vim.fn.executable("rg") == 1, "rg binary required for fixture")

			local saved_cwd = vim.fn.getcwd()
			local root = vim.fn.tempname() .. "_references_rg"
			vim.fn.mkdir(root .. "/src", "p")
			vim.fn.mkdir(root .. "/node_modules/pkg", "p")
			vim.fn.mkdir(root .. "/target/debug", "p")
			write(root .. "/src/a.lua", "local reference_word = 1\n")
			write(root .. "/node_modules/pkg/b.lua", "local reference_word = 2\n")
			write(root .. "/target/debug/c.lua", "local reference_word = 3\n")

			vim.cmd("cd " .. vim.fn.fnameescape(root))

			local sources = require("frontend.navigation.references.sources")
			local result = {}
			local finished = false
			local callback_fast = nil
			local callback_getenv_ok = nil
			local callback_getenv_err = nil

			sources.collect_rg("reference_word", { word = true }, function(items)
				callback_fast = vim.in_fast_event()
				callback_getenv_ok, callback_getenv_err = pcall(vim.fn.getenv, "HOME")
				result = items
				finished = true
			end)

			assert(
				vim.wait(3000, function()
					return finished
				end),
				"ripgrep search timed out"
			)

			assert(callback_fast == false, "ripgrep callback must run outside a fast event")
			assert(
				callback_getenv_ok,
				"ripgrep callback must allow restricted API calls: " .. tostring(callback_getenv_err)
			)
			assert(#result == 1, "only source matches must survive, got " .. #result)
			assert(result[1].filename:find("/src/a.lua", 1, true) ~= nil, "source match must be kept")

			vim.cmd("cd " .. vim.fn.fnameescape(saved_cwd))
			vim.fn.delete(root, "rf")
		end)

		it("binds gr in normal and visual modes", function()
			package.loaded["frontend.navigation.references"] = nil
			package.loaded["frontend.navigation.references.actions"] = nil
			package.loaded["frontend.navigation.references.sources"] = nil
			package.loaded["frontend.navigation.spring.state"] = nil
			package.loaded["common.Keybinder"] = nil

			require("frontend.navigation.references").config()

			for _, mode in ipairs({ "n", "v" }) do
				local map = vim.fn.maparg("gr", mode, false, true)
				assert(type(map) == "table" and type(map.callback) == "function", "gr must be mapped in mode " .. mode)
			end

			pcall(vim.keymap.del, "n", "gr")
			pcall(vim.keymap.del, "v", "gr")
		end)

		it("auto-pulls spring only after a gr selection", function()
			package.loaded["frontend.navigation.references"] = nil
			package.loaded["frontend.navigation.references.actions"] = nil
			package.loaded["frontend.navigation.references.sources"] = nil
			package.loaded["frontend.navigation.spring.state"] = nil
			package.loaded["common.Keybinder"] = nil

			local picker = nil
			package.loaded["fzf-lua"] = {
				actions = {
					file_edit = function() end,
					file_vsplit = function() end,
					file_split = function() end,
				},
				fzf_exec = function(entries, opts)
					picker = { entries = entries, opts = opts }
				end,
			}

			package.loaded["frontend.navigation.references.sources"] = {
				collect = function(_, _, callback)
					callback({ { filename = "/repo/a.lua", lnum = 2, col = 1, text = "reference_word" } })
				end,
			}

			local spring = require("frontend.navigation.spring.state")
			spring.reset()

			require("frontend.navigation.references").config()

			local bufnr = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. "_references_auto_pull.lua")
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "reference_word here" })
			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			press("gr")
			assert(picker ~= nil, "gr must open a picker")
			assert(picker.opts.previewer == "builtin", "references must use the builtin previewer")
			assert(picker.opts.winopts.preview.hidden == false, "references preview must start visible")
			assert(not spring.is_active(), "opening the picker must not pull spring")

			picker.opts.actions.default({ picker.entries[1] }, {})
			assert(spring.is_active(), "selecting a reference must pull spring")
			local first = spring.origin()

			press("gr")
			picker.opts.actions.default({ picker.entries[1] }, {})
			assert(spring.origin() == first, "later selections must keep the first spring")

			spring.reset()
			package.loaded["fzf-lua"] = nil
			pcall(vim.keymap.del, "n", "gr")
			pcall(vim.keymap.del, "v", "gr")
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end)

		it("keeps the first spring when a gr jump already has one", function()
			package.loaded["frontend.navigation.spring.state"] = nil
			local state = require("frontend.navigation.spring.state")
			state.reset()

			local first =
				{ bufnr = 1, winid = 1, tabpage = 1, filename = "/repo/a.lua", label = "a.lua", line = 1, col = 0 }
			local second =
				{ bufnr = 2, winid = 2, tabpage = 1, filename = "/repo/b.lua", label = "b.lua", line = 1, col = 0 }

			assert(state.pull_if_inactive(first), "first gr jump must pull spring")
			assert(not state.pull_if_inactive(second), "later gr jumps must keep the first spring")
			assert(state.origin() == first, "origin must stay at the first pull")

			state.reset()
		end)
	end)
end
