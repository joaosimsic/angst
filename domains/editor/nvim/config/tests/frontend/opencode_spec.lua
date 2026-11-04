local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local function spec_source(name)
	local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
		.. "/lua/frontend/tools/"
		.. name
		.. ".lua"
	local lines = vim.fn.readfile(path)
	assert(#lines > 0, "expected readable spec source: " .. path)
	return table.concat(lines, "\n")
end

return function()
	describe("opencode ask in zellij", function()
		it("spec is virtual and lazy", function()
			package.loaded["frontend.tools.opencode-ask"] = nil
			local spec = require("frontend.tools.opencode-ask")
			assert(spec[1] == "opencode-ask", "unexpected spec name: " .. vim.inspect(spec[1]))
			assert(spec.virtual == true, "opencode-ask must be virtual")
			assert(spec.event == "VeryLazy", "opencode-ask must load on VeryLazy")
			assert(type(spec.config) == "function", "opencode-ask must define config()")
		end)

		it("binds <leader>oa in normal and visual", function()
			package.loaded["frontend.tools.opencode-ask"] = nil
			local spec = require("frontend.tools.opencode-ask")
			spec.config()
			for _, mode in ipairs({ "n", "v" }) do
				local map = vim.fn.maparg("<leader>oa", mode, false, true)
				assert(
					type(map) == "table" and next(map) ~= nil and type(map.callback) == "function",
					"expected a lua mapping for <leader>oa in mode " .. mode
				)
			end
			local leader_o = vim.api.nvim_replace_termcodes("<leader>o", true, false, true)
			for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
				assert(m.lhs ~= leader_o, "must not clobber bare <leader>o")
			end
			pcall(vim.keymap.del, "n", "<leader>oa")
			pcall(vim.keymap.del, "v", "<leader>oa")
		end)

		it("opens a right zellij pane with context prompt", function()
			local source = spec_source("opencode-ask")
			assert(source:find("new-pane", 1, true), "must use zellij new-pane")
			assert(source:find('"right"', 1, true), "pane must open to the right")
			assert(source:find("resize", 1, true), "must shrink pane toward ~35%")
			assert(source:find("decrease", 1, true), "resize must decrease width")
			assert(source:find("RESIZE_STEPS = 3", 1, true), "must shrink 3 steps of 5% from 50/50 to ~35%")
			assert(source:find('"-p"', 1, true), "resize must target the new pane by id")
			assert(source:find("write_context_file", 1, true), "must stage context in a tmpfile")
			assert(source:find("absolute_ref", 1, true), "Context header must use the absolute path")
			assert(source:find("watch_log_for_connect", 1, true), "must prefill on the connect event")
			assert(source:find("global event connected", 1, true), "must watch the attach event")
			assert(source:find("opencode_log_path", 1, true), "must resolve the opencode log")
			assert(source:find("write-chars", 1, true), "must prefill via zellij write-chars")
			assert(source:find("obj:wait()", 1, true), "must wait for completion before reading the exit code")
			assert(source:find("dump-screen", 1, true), "must poll pane readiness via dump-screen")
			assert(source:find("defer_fn", 1, true), "paste must wait for the TUI to start")
			assert(source:find("My question:", 1, true), "prefill must invite the question")
			assert(source:find("chan_send", 1, true), "fallback must prefill via chan_send")
			assert(not source:find("--prompt", 1, true), "--prompt auto-sends, must prefill instead")
			assert(not source:find("shellescape", 1, true), "no shell involved, nothing to escape")
			assert(source:find("getpos", 1, true), "must capture visual selection marks")
			assert(source:find("vsplit", 1, true), "must fall back to vsplit outside zellij")
			assert(source:find("jobstart", 1, true), "fallback must use jobstart")
			assert(not source:find("termopen", 1, true), "termopen is deprecated")
			assert(source:find("<leader>oa", 1, true), "spec missing key <leader>oa")
			assert(not source:find('"<leader>o"', 1, true), "must not bind bare <leader>o")
		end)
	end)
end
