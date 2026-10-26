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

local function collect_repos(spec)
	local repos = {}
	for _, entry in ipairs(require("common.PluginLoader").collect(spec)) do
		if type(entry[1]) == "string" then
			repos[#repos + 1] = entry[1]
		end
	end
	return repos
end

return function()
	describe("git review tooling", function()
		it("diffview spec points at sindrets/diffview with plenary dep", function()
			package.loaded["frontend.tools.diffview"] = nil
			local spec = require("frontend.tools.diffview")

			assert(spec[1] == "sindrets/diffview.nvim", "unexpected diffview repo: " .. vim.inspect(spec[1]))
			assert(
				vim.tbl_contains(spec.dependencies, "nvim-lua/plenary.nvim"),
				"diffview spec must depend on plenary"
			)
			assert(vim.tbl_contains(spec.cmd, "DiffviewOpen"), "diffview spec must lazy-load DiffviewOpen")
			assert(vim.tbl_contains(spec.cmd, "DiffviewFileHistory"), "diffview spec must lazy-load history")
			assert(type(spec.config) == "function", "diffview spec must define config()")
		end)

		it("diffview binds working-tree, base-prompt, history and close keys", function()
			local source = spec_source("diffview")
			for _, lhs in ipairs({ "<leader>gd", "<leader>gm", "<leader>gh", "<leader>gq" }) do
				assert(source:find(lhs, 1, true), "diffview spec missing key " .. lhs)
			end
			assert(source:find("origin/main", 1, true), "base prompt must default to origin/main")
		end)

		it("neogit spec opens status as tab with diffview integration", function()
			package.loaded["frontend.tools.neogit"] = nil
			local spec = require("frontend.tools.neogit")

			assert(spec[1] == "NeogitOrg/neogit", "unexpected neogit repo: " .. vim.inspect(spec[1]))
			assert(
				vim.tbl_contains(spec.dependencies, "sindrets/diffview.nvim"),
				"neogit spec must depend on diffview"
			)
			assert(vim.tbl_contains(spec.cmd, "Neogit"), "neogit spec must lazy-load Neogit")
			assert(type(spec.config) == "function", "neogit spec must define config()")

			local source = spec_source("neogit")
			assert(source:find('kind = "tab"', 1, true), "neogit must open in a tab")
			assert(source:find("diffview = true", 1, true), "neogit must integrate with diffview")
			for _, lhs in ipairs({ "<leader>gs", "<leader>gc", "<leader>gl" }) do
				assert(source:find(lhs, 1, true), "neogit spec missing key " .. lhs)
			end
		end)

		it("gitsigns attaches buffer-local hunk navigation and quickfix", function()
			package.loaded["infra.plugins"] = nil
			local specs = require("infra.plugins")
			local repos = collect_repos(specs)

			assert(vim.tbl_contains(repos, "lewis6991/gitsigns.nvim"), "gitsigns must stay registered")

			local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
				.. "/lua/infra/plugins.lua"
			local source = table.concat(vim.fn.readfile(path), "\n")
			assert(source:find("on_attach", 1, true), "gitsigns setup must define on_attach")
			for _, lhs in ipairs({ "]c", "[c", "<leader>gp", "<leader>gb", "<leader>gt", "<leader>gQ" }) do
				assert(source:find(lhs, 1, true), "gitsigns on_attach missing key " .. lhs)
			end
			assert(source:find("Gitsigns setqflist all", 1, true), "quickfix must span all hunks")
		end)

		it("grug-far moved off <leader>g so git owns it", function()
			local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
				.. "/lua/frontend/editing/grug-far/init.lua"
			local source = table.concat(vim.fn.readfile(path), "\n")
			for _, lhs in ipairs({ "<leader>r", "<leader>ru" }) do
				assert(source:find(lhs, 1, true), "grug-far spec missing key " .. lhs)
			end
			assert(not source:find('<leader>g"', 1, true), "grug-far must not bind bare <leader>g")
			assert(not source:find("<leader>gu", 1, true), "grug-far must not bind <leader>gu")
		end)

		it("only the menu binds bare <leader>g, no Shift chords remain", function()
			local base = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/lua/"
			local paths = {
				"frontend/tools/diffview.lua",
				"frontend/tools/neogit.lua",
				"infra/plugins.lua",
				"frontend/editing/grug-far/init.lua",
			}
			for _, rel in ipairs(paths) do
				local source = table.concat(vim.fn.readfile(base .. rel), "\n")
				assert(
					not source:find("<leader>G%a"),
					rel .. " must not bind Shift+G chords"
				)
				assert(
					not source:find('"<leader>g"'),
					rel .. " must not bind bare <leader>g (menu owns it)"
				)
			end
			local menu = spec_source("git_menu")
			assert(menu:find('"<leader>g"', 1, true), "menu must bind bare <leader>g")

			local env = table.concat(
				vim.fn.readfile(base .. "config/env.lua"),
				"\n"
			)
			local timeout = env:match("timeoutlen%s*=%s*(%d+)")
			assert(
				timeout ~= nil and tonumber(timeout) <= 300,
				"timeoutlen must stay snappy so bare <leader>g opens without lag"
			)
		end)

		it("git menu exposes every review action", function()
			package.loaded["frontend.tools.git_menu"] = nil
			local spec = require("frontend.tools.git_menu")

			assert(spec.virtual == true, "menu must be a virtual spec")
			assert(
				vim.tbl_contains(spec.dependencies, "ibhagwan/fzf-lua"),
				"menu must depend on fzf-lua"
			)
			assert(type(spec.config) == "function", "menu spec must define config()")

			package.loaded["frontend.tools.git_menu_actions"] = nil
			local actions = require("frontend.tools.git_menu_actions")
			assert(#actions >= 12, "menu must list all review actions, got " .. #actions)

			local labels = {}
			for _, action in ipairs(actions) do
				assert(type(action.label) == "string", "menu action needs a label")
				assert(type(action.run) == "function", "menu action needs run()")
				labels[#labels + 1] = action.label
			end
			local text = table.concat(labels, "\n")
			for _, want in ipairs({
				"Neogit",
				"commit",
				"log",
				"working tree",
				"PR range",
				"current file",
				"all files",
				"close",
				"preview",
				"blame",
				"quickfix",
			}) do
				assert(text:find(want, 1, true), "menu missing action: " .. want)
			end
		end)

		it("gitcommit adapter enables treesitter for commit buffers", function()
			package.loaded["backend.adapters.gitcommit"] = nil
			local adapter = require("backend.adapters.gitcommit")

			assert(
				vim.tbl_contains(adapter.filetypes, "gitcommit"),
				"gitcommit adapter must claim the gitcommit filetype"
			)
			assert(
				adapter.treesitter == "gitcommit",
				"gitcommit adapter must resolve to the gitcommit parser"
			)
		end)

		it("commit highlight layer bounds branch matches and paints footer/status", function()
			package.loaded["frontend.tools.git_commit"] = nil
			local spec = require("frontend.tools.git_commit")

			assert(spec.virtual == true, "commit layer must be a virtual spec")
			assert(type(spec.config) == "function", "commit layer must define config()")
			spec.config()

			-- Mirror Neogit's real ordering: filetype is set while the
			-- buffer is hidden, then shown in a *different* window, and the
			-- branch matches land in the editor `after` hook afterwards.
			local other = vim.api.nvim_create_buf(false, true)
			local stale_win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(stale_win, other)

			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
				"my summary",
				"# Commands:",
				"#   q          Close",
				"# On branch main",
				"# Changes to be committed:",
				"#\tmodified:   domains/foo.lua",
				"#\tnew file:   domains/bar.lua",
			})
			vim.bo[buf].filetype = "gitcommit"
			vim.cmd("vsplit")
			local win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(win, buf)
			vim.fn.matchadd("NeogitBranch", "main", 100, -1, { window = win })

			local done = vim.wait(2000, function()
				return vim.w[win].git_commit_matches
			end)
			assert(done, "scheduled commit highlight pass never ran")

			local seen = {}
			for _, match in ipairs(vim.fn.getmatches(win)) do
				seen[match.group] = match.pattern
			end

			assert(
				seen["NeogitBranch"] == "\\<main\\>",
				"branch match must be word-bounded, got: " .. vim.inspect(seen["NeogitBranch"])
			)
			for _, group in ipairs({
				"GitCommitKey",
				"GitCommitAction",
				"GitCommitModified",
				"GitCommitNewFile",
			}) do
				assert(seen[group] ~= nil, "commit layer missing window match " .. group)
			end

			for _, match in ipairs(vim.fn.getmatches(stale_win)) do
				assert(
					not vim.startswith(match.group, "GitCommit"),
					"commit layer leaked into stale window: " .. match.group
				)
			end

			vim.api.nvim_win_close(win, true)
			vim.api.nvim_buf_delete(buf, { force = true })
			vim.api.nvim_buf_delete(other, { force = true })
		end)

		it("git theme groups cover diffview, neogit and gitsigns", function()
			package.loaded["config.theme.groups.git"] = nil
			local groups = require("config.theme.groups.git").get()
			for _, name in ipairs({
				"DiffAdd",
				"DiffChange",
				"DiffDelete",
				"DiffText",
				"GitSignsAdd",
				"GitSignsChange",
				"GitSignsDelete",
				"DiffviewFilePanelTitle",
				"DiffviewDiffAdd",
				"NeogitHunkHeader",
				"NeogitDiffAdd",
				"NeogitBranch",
				"gitcommitSummary",
				"gitcommitOverflow",
				"gitcommitComment",
				"gitcommitSelectedFile",
				"gitcommitDiscardedFile",
				"gitcommitUntrackedFile",
				"gitcommitBranch",
				"gitcommitHeader",
				"GitCommitKey",
				"GitCommitAction",
				"GitCommitModified",
				"GitCommitNewFile",
				"GitCommitDeleted",
				"GitCommitRenamed",
			}) do
				assert(groups[name] ~= nil, "git theme missing group " .. name)
			end

			package.loaded["config.theme.groups.init"] = nil
			local all = require("config.theme.groups").get()
			assert(all["DiffviewFilePanelTitle"] ~= nil, "theme init must include git groups")
			assert(all["NeogitHunkHeader"] ~= nil, "theme init must include git groups")
			assert(all["GitSignsAdd"] ~= nil, "theme init must include git groups")
		end)
	end)
end
