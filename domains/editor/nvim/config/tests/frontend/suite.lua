local describe = rawget(_G, "describe")
local source = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(source, ":p:h")
dofile(test_dir .. "/../rtp_pin.lua")

describe("Frontend Validations", function()
	dofile(test_dir .. "/git_spec.lua")()
end)
