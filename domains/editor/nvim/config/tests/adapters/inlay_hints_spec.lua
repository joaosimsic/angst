local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

return function(t)
	describe("inlay hints", function()
		it("should enable hints when an attached LSP supports them", function()
			t.with_lsp_inlay_hint_stubs(function(state)
				require("backend.engines.lsp").config()
				vim.api.nvim_exec_autocmds("LspAttach", {
					buffer = state.buf,
					data = { client_id = 42 },
				})

				t.assert_equal(state.buf, state.keymap_buf)
				t.assert_equal(1, #state.enable_calls)
				t.assert_equal(true, state.enable_calls[1].enabled)
				t.assert_same({ bufnr = state.buf }, state.enable_calls[1].opts)
			end)
		end)
	end)
end
