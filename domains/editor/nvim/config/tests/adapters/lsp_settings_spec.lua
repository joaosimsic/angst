local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

return function(t)
	describe("LSP settings", function()
		it("should preserve exact settings for single-server adapters", function()
			local settings = {
				gopls = {
					hints = {
						parameterNames = true,
					},
				},
			}
			local adapter = {
				filetypes = { "go" },
				lsp = "gopls",
				lsp_settings = settings,
			}

			local info = t.AdapterTool.info(adapter, "lsp", "gopls")

			t.assert_same(settings, info.settings)
		end)

		it("should select per-server settings for multi-server adapters", function()
			local adapter = {
				filetypes = { "javascript", "typescript" },
				lsp = { "eslint", "ts_ls" },
				lsp_settings = {
					eslint = { workingDirectory = { mode = "auto" } },
					ts_ls = { typescript = { inlayHints = { includeInlayParameterNameHints = "all" } } },
				},
			}

			local eslint = t.AdapterTool.info(adapter, "lsp", "eslint")
			local ts_ls = t.AdapterTool.info(adapter, "lsp", "ts_ls")

			t.assert_same(adapter.lsp_settings.eslint, eslint.settings)
			t.assert_same(adapter.lsp_settings.ts_ls, ts_ls.settings)
		end)

		it("should pass exact inlay hint settings through adapter scanning", function()
			local lsp_servers = t.AdapterScanner:by_tool("lsp", { check_executable = false })

			t.assert_same(t.all_adapters.go.lsp_settings, lsp_servers.gopls.settings)
			t.assert_same(t.all_adapters.lua.lsp_settings, lsp_servers.lua_ls.settings)
		end)
	end)
end
