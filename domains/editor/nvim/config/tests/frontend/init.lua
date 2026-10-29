local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = vim.fn.fnamemodify(source, ":p:h:h")
local setup = dofile(tests_dir .. "/setup_plenary.lua")

local config_root = setup.prepare()

require("plenary.test_harness").test_file(config_root .. "/tests/frontend/suite.lua")
