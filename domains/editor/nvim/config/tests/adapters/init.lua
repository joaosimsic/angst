require("init")

local runner = require("plenary.test_runner")

print("Starting validation pipeline via Plenary Busted Runner...")

runner.run_directory("adapters/suite.lua")
