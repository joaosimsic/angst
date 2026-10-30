local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

return function(t)
	describe("loader and scanner", function()
		it("should load adapters through the shared loader", function()
			t.assert_same(t.AdapterLoader.load("backend.adapters"), t.all_adapters)
		end)

		it("should expose adapter-backed filetype support queries", function()
			local opts = { check_executable = false }
			local lua_tools = t.AdapterScanner:tools_for_filetype("treesitter", "lua", opts)

			assert(type(lua_tools) == "table", "Scanner should return a table of tools for a filetype.")
			assert(#lua_tools > 0, "Lua should have at least one configured treesitter parser.")
			assert(
				t.AdapterScanner:supports_filetype("treesitter", "lua", opts),
				"Lua should be supported by treesitter."
			)
			assert(
				not t.AdapterScanner:supports_filetype("treesitter", "definitely-not-a-filetype", opts),
				"Unknown filetypes should not be reported as supported."
			)
		end)
	end)
end
