local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

return function()
	describe("lazydev library guard", function()
		it("never adds the active config or workspace paths to lazydev libraries", function()
			local added = {}
			local workspace = { root = "/tmp/angst-lazydev-root" }

			function workspace:add(path)
				added[#added + 1] = path
			end

			package.loaded["frontend.editing.lazydev"] = nil
			package.loaded["common.ConfigPath"] = nil
			package.loaded["lazydev"] = { setup = function() end }
			package.loaded["lazydev.workspace"] = workspace

			local spec = require("frontend.editing.lazydev")
			spec.config(nil, spec.opts)

			local config_dir = vim.fn.stdpath("config")
			workspace:add(config_dir .. "/lua")
			workspace:add(workspace.root .. "/lua")
			workspace:add({ "/tmp/angst-lazydev-ok", config_dir, workspace.root .. "/vendor" })
			workspace:add("/tmp/angst-lazydev-single")

			assert(workspace.__angst_config_guard, "lazydev workspace guard must be installed")
			assert(
				vim.inspect(added) == vim.inspect({ { "/tmp/angst-lazydev-ok" }, "/tmp/angst-lazydev-single" }),
				"config and workspace paths must be filtered from lazydev libraries"
			)

			package.loaded["frontend.editing.lazydev"] = nil
			package.loaded["lazydev"] = nil
			package.loaded["lazydev.workspace"] = nil
		end)
	end)
end
