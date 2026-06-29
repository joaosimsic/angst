vim.opt.runtimepath:prepend(vim.fn.expand("~/.local/share/tree-sitter"))

local describe = rawget(_G, "describe")
local source = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(source, ":p:h")
local helpers = dofile(test_dir .. "/helpers.lua")

describe("Adapter Engine Validations", function()
	dofile(test_dir .. "/loader_scanner_spec.lua")(helpers)
	dofile(test_dir .. "/lsp_settings_spec.lua")(helpers)
	dofile(test_dir .. "/inlay_hints_spec.lua")(helpers)
	dofile(test_dir .. "/engine_mappings_spec.lua")(helpers)
end)
