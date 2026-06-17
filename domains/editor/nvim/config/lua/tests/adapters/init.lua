local Logger = require("tests.TestLogger")
local logger = Logger.new("ADAPTER_VALIDATION")
local suite = require("tests.adapters.suite")

local errors = {}

local function assert_true(condition, msg)
	if not condition then
		table.insert(errors, msg)
	end
end

local function run_pipeline()
	logger:info("Starting validation pipeline.")

	for idx, step in ipairs(suite.steps) do
		logger:info(string.format("Running step %d: [%s]...", idx, step.name))

		local success, runtime_err = pcall(step.run, assert_true)

		if not success then
			table.insert(
				errors,
				string.format("Step [%s] crashed with runtime error: %s", step.name, tostring(runtime_err))
			)
		end
	end

	if #errors > 0 then
		logger:error(string.format("Pipeline completed with %d failure(s):", #errors))
		for _, err in ipairs(errors) do
			logger:warn("  - " .. err)
		end
		os.exit(1)
	else
		logger:info("Pipeline completed successfully! All engines are properly bound to adapters.")
		os.exit(0)
	end
end

local success, err = pcall(run_pipeline)
if not success then
	logger:error("Orchestrator pipeline failed fatally: " .. tostring(err))
	os.exit(1)
end
