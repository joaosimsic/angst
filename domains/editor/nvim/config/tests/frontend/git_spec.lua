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
		-- Invoke mapping callbacks directly: headless typeahead does not
		-- dispatch fed keys, but this exercises the identical code path.
		local function press(lhs)
			local map = vim.fn.maparg(lhs, "n", false, true)
			assert(
				type(map) == "table" and next(map) ~= nil and type(map.callback) == "function",
				"expected a lua mapping for " .. lhs
			)
			map.callback()
		end
		local function hint_win(text)
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
				if ok and cfg.relative ~= "" then
					local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
					if table.concat(lines, "\n"):find(text, 1, true) then
						return win
					end
				end
			end
			return nil
		end

		it("diffview stays removed; review lives in the hydra panes", function()
			local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
				.. "/lua/frontend/tools/diffview.lua"
			assert(vim.fn.filereadable(path) == 0, "diffview spec must stay deleted")
		end)

		it("neogit spec opens status as tab without diffview", function()
			package.loaded["frontend.tools.neogit"] = nil
			local spec = require("frontend.tools.neogit")

			assert(spec[1] == "NeogitOrg/neogit", "unexpected neogit repo: " .. vim.inspect(spec[1]))
			assert(
				not vim.tbl_contains(spec.dependencies, "sindrets/diffview.nvim"),
				"neogit spec must not depend on diffview"
			)
			assert(vim.tbl_contains(spec.cmd, "Neogit"), "neogit spec must lazy-load Neogit")
			assert(type(spec.config) == "function", "neogit spec must define config()")

			local source = spec_source("neogit")
			assert(source:find('kind = "tab"', 1, true), "neogit must open in a tab")
			assert(source:find("diffview = false", 1, true), "neogit must not integrate with diffview")
			for _, lhs in ipairs({ "<leader>lg", "<leader>gc", "<leader>gm" }) do
				assert(source:find(lhs, 1, true), "neogit spec missing key " .. lhs)
			end
			assert(not source:find("<leader>gs", 1, true), "neogit status moved off <leader>gs")
		end)

		it("gitsigns attaches buffer-local hunk navigation and quickfix", function()
			package.loaded["infra.plugins"] = nil
			local specs = require("infra.plugins")
			local repos = collect_repos(specs)

			assert(vim.tbl_contains(repos, "lewis6991/gitsigns.nvim"), "gitsigns must stay registered")

			local path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/lua/infra/plugins.lua"
			local source = table.concat(vim.fn.readfile(path), "\n")
			assert(source:find("on_attach", 1, true), "gitsigns setup must define on_attach")
			for _, lhs in ipairs({ "]c", "[c", "<leader>gp", "<leader>gb", "<leader>gt", "<leader>gQ" }) do
				assert(source:find(lhs, 1, true), "gitsigns on_attach missing key " .. lhs)
			end
			assert(source:find("Gitsigns setqflist all", 1, true), "quickfix must span all hunks")
			assert(source:find("word_diff = false", 1, true), "gitsigns must keep word_diff off (bg-only hunks)")
			assert(source:find("preview_config", 1, true), "gitsigns must style floating preview")
			assert(source:find("git_hunk_display", 1, true), "gitsigns on_attach must respect the global hunk switch")
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

		it("hydra owns bare <leader>g, menu lives on <leader>gl, no Shift chords", function()
			local base = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h") .. "/lua/"
			local paths = {
				"frontend/tools/git_menu.lua",
				"frontend/tools/neogit.lua",
				"infra/plugins.lua",
				"frontend/editing/grug-far/init.lua",
			}
			for _, rel in ipairs(paths) do
				local source = table.concat(vim.fn.readfile(base .. rel), "\n")
				assert(not source:find("<leader>G%a"), rel .. " must not bind Shift+G chords")
				assert(not source:find('"<leader>g"'), rel .. " must not bind bare <leader>g (hydra owns it)")
			end
			local review = spec_source("git_review")
			assert(review:find('"<leader>g"', 1, true), "hydra must bind bare <leader>g")
			local menu = spec_source("git_menu")
			assert(menu:find('"<leader>gl"', 1, true), "menu must bind <leader>gl")

			local env = table.concat(vim.fn.readfile(base .. "config/env.lua"), "\n")
			local timeout = env:match("timeoutlen%s*=%s*(%d+)")
			assert(
				timeout ~= nil and tonumber(timeout) <= 300,
				"timeoutlen must stay snappy so hydra enter plus a pause steps diffs"
			)
		end)

		it("git menu exposes every review action", function()
			package.loaded["frontend.tools.git_menu"] = nil
			local spec = require("frontend.tools.git_menu")

			assert(spec.virtual == true, "menu must be a virtual spec")
			assert(vim.tbl_contains(spec.dependencies, "ibhagwan/fzf-lua"), "menu must depend on fzf-lua")
			assert(type(spec.config) == "function", "menu spec must define config()")

			package.loaded["frontend.tools.git_menu_actions"] = nil
			local actions = require("frontend.tools.git_menu_actions")
			assert(#actions >= 6, "menu must list all review actions, got " .. #actions)

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
				"preview",
				"blame",
				"diff",
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
			assert(adapter.treesitter == "gitcommit", "gitcommit adapter must resolve to the gitcommit parser")
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

		it("git review hydra is minimal with d/h/l/p/n/N and a flat filenames-only list", function()
			vim.g.mapleader = " "

			local calls = {}
			local function log(name)
				return function(...)
					calls[#calls + 1] = name
				end
			end
			package.loaded["gitsigns"] = {
				setqflist = log("setqflist"),
				nav_hunk = log("nav_hunk"),
				toggle_deleted = function(v)
					calls[#calls + 1] = "deleted:" .. tostring(v)
				end,
				toggle_linehl = function(v)
					calls[#calls + 1] = "linehl:" .. tostring(v)
				end,
				toggle_word_diff = function(v)
					calls[#calls + 1] = "word:" .. tostring(v)
				end,
			}
			-- Stub the file supplement: real git must not leak into asserts.
			package.loaded["frontend.tools.git_review_files"] = {
				repo_toplevels = function()
					return {}
				end,
				extra_entries_for = function()
					return {}
				end,
				append_missing = function()
					calls[#calls + 1] = "append"
					return 0
				end,
				collect = function()
					calls[#calls + 1] = "collect"
					return vim.fn.getqflist({ size = 0 }).size
				end,
			}

			-- Evict framework modules: the harness may hand us preloaded
			-- copies, and the spec must bind against the working tree.
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_hunk_display"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review"] = nil
			vim.g.angst_git_hunks_enabled = nil
			local spec = require("frontend.tools.git_review")
			assert(spec.virtual == true, "review must be a virtual spec")
			assert(type(spec.config) == "function", "review spec must define config()")
			spec.config()
			local pages_mod = require("frontend.tools.git_review_pages")

			local enter = vim.fn.maparg("<leader>g", "n", false, true)
			assert(type(enter) == "table" and next(enter) ~= nil, "review hydra must bind <leader>g")
			assert(type(enter.callback) == "function", "review enter must be a lua callback")

			local review_source = spec_source("git_review")
			local pages_source = spec_source("git_review_pages")
			for _, lhs in ipairs({ '"d"', '"<Tab>"', '"h"', '"l"', '"n"', '"N"', '"q"' }) do
				assert(review_source:find(lhs, 1, true), lhs .. " must be a hydra head")
			end
			for _, lhs in ipairs({ '"j"', '"k"', '"f"', '"s"', '"u"', '"x"', '"v"', '"b"', '"r"', '"p"' }) do
				assert(not review_source:find(lhs, 1, true), lhs .. " must not be a hydra head")
			end
			assert(not review_source:find('"D"', 1, true), "D diffview head must be gone")
			assert(not review_source:find("nav_hunk", 1, true), "h/l must step quickfix diffs, not gitsigns hunks")
			assert(review_source:find('"cc "', 1, true), "h/l must step quickfix entries via cc")
			assert(not review_source:find("preview_hunk", 1, true), "hydra must never pop a hunk preview")
			assert(not review_source:find("nav_hunk", 1, true), "h/l must step quickfix diffs, not gitsigns hunks")
			assert(review_source:find('"cc "', 1, true), "h/l must step quickfix entries via cc")
			assert(review_source:find("git_review_pages", 1, true), "hydra must drive the page pane")
			assert(review_source:find("git_review_branch", 1, true), "hydra must drive the branch pane")
			assert(review_source:find("on_exit", 1, true), "hydra must close the pane on every exit path")
			local branch_source = spec_source("git_review_branch")
			assert(
				branch_source:find("angst_git_branch_diff_enabled", 1, true),
				"branch mode must persist in vim.g across hydra exits"
			)
			assert(
				branch_source:find("angst-git-branch-files", 1, true),
				"branch column must use its own files pane"
			)
			assert(
				branch_source:find("angst-git-branch-diffs", 1, true),
				"branch column must use its own diffs pane"
			)
			assert(
				branch_source:find("common.Badge", 1, true),
				"branch mode must badge the target markdown-style"
			)
			assert(branch_source:find('"⇄ "', 1, true), "badge must show the compared-against branch")
			assert(
				branch_source:find("git_branch_hunks", 1, true),
				"branch mode must tint code hunks bg-only"
			)
			assert(
				pages_source:find("botright vertical", 1, true),
				"file list must open as a right-side vertical column"
			)
			assert(
				pages_source:find("belowright split", 1, true),
				"diffs must open as a second pane below the file list"
			)
			assert(pages_source:find("FILES_HEADER", 1, true), "pane must list every changed file")
			assert(pages_source:find("DIFFS_HEADER", 1, true), "diffs pane must show the current file diffs")
			assert(pages_source:find("GitReviewCursor", 1, true), "panes must paint a strong cursor row")
			assert(pages_source:find("GitReviewHeader", 1, true), "winbars must use the header group")
		for _, group in ipairs({
			"GitReviewAdded",
			"GitReviewChanged",
			"GitReviewDeleted",
			"GitReviewUntracked",
			"GitReviewCursorAdded",
			"GitReviewCursorChanged",
			"GitReviewCursorDeleted",
			"GitReviewCursorUntracked",
		}) do
			assert(pages_source:find(group, 1, true), "diff rows must tint by kind: " .. group)
		end
			assert(pages_source:find("winbar", 1, true), "each pane must title its winbar")
			assert(pages_source:find('statusline", " ")', 1, true), "panes must blank the statusline to quiet heirline")
			assert(not pages_source:find("Page ", 1, true), "pane must have no pages")
			assert(pages_source:find("render_all", 1, true), "panes must rebuild around the current file")
			assert(
				not pages_source:find("set_extmark", 1, true),
				"hover must not use extmarks (end_row bled onto the row below)"
			)
			assert(pages_source:find("cursorline", 1, true), "each pane must hover with its own cursorline")
			assert(pages_source:find('":t"', 1, true), "pane must show filenames only")
			assert(
				not review_source:find("toggle_word_diff(true)", 1, true),
				"word diff must never be enabled (bg-only hunks)"
			)

			press(" g")
			assert(vim.g.active_hydra ~= nil and vim.g.active_hydra.name == "Git", "Git hydra never activated")
			assert(hint_win("Prev diff") == nil, "Git hydra hint must stay hidden by default")
			assert(not vim.tbl_contains(calls, "setqflist"), "enter must not populate the file list")
			assert(vim.g.angst_git_hunks_enabled == true, "hunk switch must default on")
			assert(vim.tbl_contains(calls, "deleted:true"), "enter must enable deleted overlay")
			assert(vim.tbl_contains(calls, "linehl:true"), "enter must enable line bg")
			assert(vim.tbl_contains(calls, "word:false"), "enter must force word diff off (bg-only)")
			assert(not vim.tbl_contains(calls, "word:true"), "word diff must never turn on")
			assert(
				vim.fn.getqflist({ winid = 0 }).winid == 0,
				"enter must not open a quickfix window (pages replace it)"
			)
			assert(pages_mod.is_open(), "enter must auto-open the panes")

			press("?")
			assert(hint_win("Prev diff") ~= nil, "? must open hint float")
			press("?")
			assert(hint_win("Prev diff") == nil, "? must close hint float again")

			local buf_a = vim.api.nvim_create_buf(false, true)
			local buf_b = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_a, "/tmp/gitpages_aaa.lua")
			vim.api.nvim_buf_set_name(buf_b, "/tmp/gitpages_bbb.lua")
			vim.fn.setqflist({
				{ bufnr = buf_a, lnum = 1, text = "1: (+1) A" },
				{ bufnr = buf_a, lnum = 2, text = "2: (~2) M" },
				{ bufnr = buf_b, lnum = 1, text = "1: (+1) A" },
			})
			vim.cmd("cc 1")
			vim.b[buf_a].gitsigns_status_dict = {}
			vim.b[buf_b].gitsigns_status_dict = {}

			-- `j`/`k` stay normal cursor motion: no hydra heads bound.
			for _, lhs in ipairs({ "j", "k" }) do
				local got = vim.fn.maparg(lhs, "n", false, true)
				assert(type(got) ~= "table" or got.callback == nil, lhs .. " must not be a hydra head")
			end

			-- h/l cycle diffs in the same file only, never leaving it.
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "fixture must start on the first diff")
			calls = {}
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 2, "l must step to the next diff in the file")
			assert(vim.api.nvim_get_current_buf() == buf_a, "l must not leave the file")
			assert(not vim.tbl_contains(calls, "nav_hunk"), "l must not use gitsigns hunk nav")
			calls = {}
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "l must wrap to the first diff")
			calls = {}
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 2, "h must wrap to the last diff")
			assert(vim.api.nvim_get_current_buf() == buf_a, "h must not leave the file")
			assert(not vim.tbl_contains(calls, "nav_hunk"), "h must not use gitsigns hunk nav")

			calls = {}
			press("d")
			assert(vim.g.angst_git_hunks_enabled == false, "d must flip the global hunk switch off")
			assert(vim.tbl_contains(calls, "deleted:false"), "d head never disabled deleted overlay")
			assert(vim.tbl_contains(calls, "linehl:false"), "d off must clear line bg")
			assert(not vim.tbl_contains(calls, "nav_hunk"), "d must not touch hunk nav")

			-- Diff steps still move while hunks are off.
			calls = {}
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "l must still step diffs while hunks are off")
			assert(vim.api.nvim_get_current_buf() == buf_a, "l must not leave the file")
			assert(not vim.tbl_contains(calls, "nav_hunk"), "l must not use gitsigns hunk nav")

			-- Enter auto-opened two stacked panes on the right: files over diffs.
			assert(pages_mod.is_open(), "panes must open with the hydra")
			local files_win, files_buf, diffs_win, diffs_buf = nil, nil, nil, nil
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].filetype == "angst-git-files" then
					files_win, files_buf = win, buf
				elseif vim.bo[buf].filetype == "angst-git-diffs" then
					diffs_win, diffs_buf = win, buf
				end
			end
			assert(files_win ~= nil, "files pane window missing")
			assert(diffs_win ~= nil, "diffs pane window missing")
			for _, win in ipairs({ files_win, diffs_win }) do
				assert(
					vim.api.nvim_win_get_width(win) == 30,
					"panes must be narrow, got width " .. vim.api.nvim_win_get_width(win)
				)
				assert(vim.wo[win].cursorline == true, "each pane must hover with its own cursorline")
			end
			local files_h = vim.api.nvim_win_get_height(files_win)
			local diffs_h = vim.api.nvim_win_get_height(diffs_win)
			local share = files_h / (files_h + diffs_h)
			assert(files_h > diffs_h, "files pane must be taller than the diffs pane")
			assert(share > 0.6 and share < 0.8, "panes must split 70/30, got share " .. share)

			for _, win in ipairs({ files_win, diffs_win }) do
				assert(
					vim.api.nvim_win_get_option(win, "winhighlight"):find("CursorLine:GitReviewCursor", 1, true),
					"panes must paint a strong cursor row"
				)
				assert(
					vim.api.nvim_win_get_option(win, "statusline") == " ",
					"panes must keep heirline out with a blank statusline"
				)
				local header_marks = 0
				for _, m in ipairs(vim.fn.getmatches(win)) do
					if m.group == "GitReviewHeader" then
						header_marks = header_marks + 1
					end
				end
				assert(header_marks == 0, "titles moved to the winbar; no buffer matches remain")
			end
			assert(
				vim.api.nvim_win_get_option(files_win, "winbar") == "%#GitReviewHeader# ▸ FILES (2)%*",
				"files pane must title its winbar, got: " .. vim.api.nvim_win_get_option(files_win, "winbar")
			)
			assert(
				vim.api.nvim_win_get_option(diffs_win, "winbar")
					== "%#GitReviewHeader# ▸ DIFFS · gitpages_aaa.lua (2)%*",
				"diffs pane must title its winbar, got: " .. vim.api.nvim_win_get_option(diffs_win, "winbar")
			)

			local file_lines = vim.api.nvim_buf_get_lines(files_buf, 0, -1, false)
			assert(
				vim.inspect(file_lines) == vim.inspect({ "▸ /tmp/gitpages_aaa.lua", "  gitpages_bbb.lua" }),
				"files pane must show tails plus the selected path, got: " .. vim.inspect(file_lines)
			)
			assert(
				vim.api.nvim_win_get_option(diffs_win, "winhighlight") == "CursorLine:GitReviewCursorAdded",
				"selection cursor must take the marked hunk kind"
			)
			local diff_lines = vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false)
			assert(
				vim.inspect(diff_lines) == vim.inspect({ "> 1: (+1) A", "  2: (~2) M" }),
				"diffs pane must list the current-file diffs, got: " .. vim.inspect(diff_lines)
			)
			for _, win in ipairs({ files_win, diffs_win }) do
				assert(vim.api.nvim_get_current_win() ~= win, "focus must stay in the code window")
			end

			local function files_row()
				return vim.api.nvim_win_get_cursor(files_win)[1]
			end
			local function diffs_row()
				return vim.api.nvim_win_get_cursor(diffs_win)[1]
			end
			assert(files_row() == 1, "files pane must highlight the current file on open")
			assert(diffs_row() == 1, "diffs pane must mark the current diff on open")

			-- `n` / `N` step files; both panes follow, focus stays put.
			press("n")
			assert(vim.api.nvim_get_current_buf() == buf_b, "n must jump to the next file")
			assert(files_row() == 2, "files pane must highlight the landed file")
			assert(diffs_row() == 1, "diffs pane must mark the landed diff")
			assert(vim.api.nvim_get_current_win() ~= files_win, "n must not move focus into a pane")
			assert(vim.api.nvim_get_current_win() ~= diffs_win, "n must not move focus into a pane")
			local diffs_b = vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false)
			assert(
				vim.inspect(diffs_b) == vim.inspect({ "> 1: (+1) A" }),
				"diffs pane must switch to the landed file, got: " .. vim.inspect(diffs_b)
			)
			local file_lines_b = vim.api.nvim_buf_get_lines(files_buf, 0, -1, false)
			assert(
				vim.inspect(file_lines_b) == vim.inspect({ "  gitpages_aaa.lua", "▸ /tmp/gitpages_bbb.lua" }),
				"files pane must move the marker, got: " .. vim.inspect(file_lines_b)
			)
			assert(
				vim.api.nvim_win_get_option(diffs_win, "winbar")
					== "%#GitReviewHeader# ▸ DIFFS · gitpages_bbb.lua (1)%*",
				"diffs winbar must follow the landed file"
			)
			press("N")
			assert(vim.api.nvim_get_current_buf() == buf_a, "N must jump back to the previous file")
			assert(files_row() == 1, "files pane must highlight the landed file")
			assert(diffs_row() == 1, "diffs pane must mark the landed diff")
			local diffs_a = vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false)
			assert(
				vim.inspect(diffs_a) == vim.inspect({ "> 1: (+1) A", "  2: (~2) M" }),
				"diffs pane must switch back, got: " .. vim.inspect(diffs_a)
			)
			-- Wrap-around at the ends of the file list.
			press("N")
			assert(vim.api.nvim_get_current_buf() == buf_b, "N must wrap to the last file")
			assert(files_row() == 2, "files pane must highlight the landed file")
			assert(diffs_row() == 1, "diffs pane must mark the landed diff")
			press("n")
			assert(vim.api.nvim_get_current_buf() == buf_a, "n must wrap to the first file")
			assert(files_row() == 1, "files pane must highlight the landed file")
			assert(diffs_row() == 1, "diffs pane must mark the landed diff")

			-- h/l move the marker within the diffs pane; files stay put.
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 2, "l must step to the next diff in the file")
			assert(vim.api.nvim_get_current_buf() == buf_a, "l must not leave the file")
			local diffs_l = vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false)
			assert(
				vim.inspect(diffs_l) == vim.inspect({ "  1: (+1) A", "> 2: (~2) M" }),
				"marker must follow h/l, got: " .. vim.inspect(diffs_l)
			)
			assert(
				vim.api.nvim_win_get_option(diffs_win, "winbar")
					== "%#GitReviewHeader# ▸ DIFFS · gitpages_aaa.lua (2)%*",
				"winbar must stay exact across re-renders"
			)
			assert(
				vim.api.nvim_win_get_option(diffs_win, "winhighlight") == "CursorLine:GitReviewCursorChanged",
				"selection cursor must follow the marked hunk kind"
			)
			assert(files_row() == 1, "files pane must keep highlighting the file")
			assert(diffs_row() == 2, "diffs pane must move to the marked diff")
			assert(vim.api.nvim_get_current_win() ~= files_win, "h/l must not move focus into a pane")
			assert(vim.api.nvim_get_current_win() ~= diffs_win, "h/l must not move focus into a pane")
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "h must step back to the previous diff")
			local diffs_h = vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false)
			assert(
				vim.inspect(diffs_h) == vim.inspect({ "> 1: (+1) A", "  2: (~2) M" }),
				"marker must follow h back, got: " .. vim.inspect(diffs_h)
			)
			assert(files_row() == 1, "files pane must keep highlighting the file")
			assert(diffs_row() == 1, "diffs pane must move back to the marked diff")

			calls = {}
			press("d")
			assert(vim.g.angst_git_hunks_enabled == true, "d must flip the global hunk switch back on")
			assert(vim.tbl_contains(calls, "deleted:true"), "d on must restore deleted overlay")
			assert(vim.tbl_contains(calls, "linehl:true"), "d on must restore line bg")

			press("q")
			assert(vim.g.active_hydra == nil, "q head never exited review mode")
			assert(hint_win("Prev diff") == nil, "hint window must close on exit")
			assert(not pages_mod.is_open(), "q must hide the page pane")
			assert(vim.fn.getqflist({ winid = 0 }).winid == 0, "q must leave the quickfix window closed")
			vim.b[buf_a].gitsigns_status_dict = nil
			vim.b[buf_b].gitsigns_status_dict = nil

			package.loaded["gitsigns"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })
		end)

		it("h/l cycles four staged diffs in one file without leaving it", function()
			vim.g.mapleader = " "

			package.loaded["gitsigns"] = {
				setqflist = function() end,
				nav_hunk = function() end,
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
			}
			-- Fake the supplement for the hydra: the list is prebuilt
			-- below, so collection short-circuits and jumps stay sync.
			package.loaded["frontend.tools.git_review_files"] = {
				repo_toplevels = function()
					return {}
				end,
				extra_entries_for = function()
					return {}
				end,
				append_missing = function()
					return 0
				end,
				collect = function()
					return vim.fn.getqflist({ size = 0 }).size
				end,
			}
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_hunk_display"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review"] = nil
			require("frontend.tools.git_review").config()

			-- Per-hunk dedupe: four hunks in one staged file must all
			-- survive append_missing, not just the first per file.
			local base = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
				.. "/lua/frontend/tools/git_review_files.lua"
			local real_files = dofile(base)
			local path = "/tmp/gitpages_four.lua"
			local f = assert(io.open(path, "w"))
			for i = 1, 40 do
				f:write("line" .. i .. "\n")
			end
			f:close()
			local extras = {
				{ filename = path, lnum = 5, text = "Staged (-5 +5): one" },
				{ filename = path, lnum = 15, text = "Staged (-15 +15): two" },
				{ filename = path, lnum = 25, text = "Staged (-25 +25): three" },
				{ filename = path, lnum = 35, text = "Staged (-35 +35): four" },
			}
			vim.fn.setqflist({}, "r")
			assert(real_files.append_missing(extras) == 4, "all four staged hunks must be appended")
			assert(real_files.append_missing(extras) == 0, "re-append must add nothing")
			assert(vim.fn.getqflist({ size = 0 }).size == 4, "quickfix must hold all four diffs")

			vim.cmd("edit " .. path)
			local buf = vim.api.nvim_get_current_buf()
			vim.b[buf].gitsigns_status_dict = {}
			vim.cmd("cc 1")

			press(" g")
			assert(vim.g.active_hydra ~= nil and vim.g.active_hydra.name == "Git", "Git hydra never activated")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "must start on the first diff")

			-- l walks every middle block, not just first/last.
			local want_l = { 2, 3, 4, 1 }
			for _, want in ipairs(want_l) do
				press("l")
				assert(
					vim.fn.getqflist({ idx = 0 }).idx == want,
					"l must land on diff " .. want .. ", got " .. vim.fn.getqflist({ idx = 0 }).idx
				)
				assert(vim.api.nvim_get_current_buf() == buf, "l must not leave the file")
			end
			-- h wraps back to the last block, then walks down.
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 4, "h must wrap to the last diff")
			assert(vim.api.nvim_get_current_buf() == buf, "h must not leave the file")
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 3, "h must step to the third diff")
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 2, "h must step to the second diff")
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "h must step to the first diff")

			press("q")
			assert(vim.g.active_hydra == nil, "q head never exited review mode")
			vim.b[buf].gitsigns_status_dict = nil
			package.loaded["gitsigns"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			vim.api.nvim_buf_delete(buf, { force = true })
			vim.fn.setqflist({}, "r")
			os.remove(path)
		end)

		it("h/l with a stale quickfix index jumps to the hunk nearest the cursor", function()
			vim.g.mapleader = " "

			package.loaded["gitsigns"] = {
				setqflist = function() end,
				nav_hunk = function() end,
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
			}
			package.loaded["frontend.tools.git_review_files"] = {
				repo_toplevels = function()
					return {}
				end,
				extra_entries_for = function()
					return {}
				end,
				append_missing = function()
					return 0
				end,
				collect = function()
					return vim.fn.getqflist({ size = 0 }).size
				end,
			}
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_hunk_display"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review"] = nil
			require("frontend.tools.git_review").config()

			-- Stale idx: the list was rebuilt under us (idx reset to an
			-- entry of another file). Blind jump-to-end would strand h
			-- on last / l on first forever; cursor-nearest must win.
			local path = "/tmp/gitpages_stale.lua"
			local other = "/tmp/gitpages_stale_other.lua"
			for _, p in ipairs({ path, other }) do
				local f = assert(io.open(p, "w"))
				for i = 1, 40 do
					f:write("line" .. i .. "\n")
				end
				f:close()
			end
			vim.fn.setqflist({}, "r")
			vim.fn.setqflist({
				{ filename = other, lnum = 1, col = 1, text = "elsewhere" },
				{ filename = path, lnum = 5, col = 1, text = "Staged h1" },
				{ filename = path, lnum = 15, col = 1, text = "Staged h2" },
				{ filename = path, lnum = 25, col = 1, text = "Staged h3" },
			})
			vim.cmd("edit " .. path)
			local buf = vim.api.nvim_get_current_buf()
			vim.b[buf].gitsigns_status_dict = {}
			vim.cmd("cc 1")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 1, "fixture must start on the stale entry")
			-- cc 1 lands in the other file: come back so the cursor
			-- sits in the reviewed file while the index stays stale.
			vim.cmd("edit " .. path)

			press(" g")
			vim.api.nvim_win_set_cursor(0, { 15, 0 })

			-- h from a stale idx lands on the hunk under the cursor,
			-- not the last one; the next h then walks normally.
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 3, "h must land on the nearest hunk")
			press("h")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 2, "h must step to the previous diff")
			assert(vim.api.nvim_get_current_buf() == buf, "h must not leave the file")

			-- Same for l: resync to nearest, then step forward.
			vim.cmd("cc 1")
			vim.cmd("edit " .. path)
			vim.api.nvim_win_set_cursor(0, { 15, 0 })
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 3, "l must land on the nearest hunk")
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 4, "l must step to the next diff")

			press("q")
			assert(vim.g.active_hydra == nil, "q head never exited review mode")
			vim.b[buf].gitsigns_status_dict = nil
			package.loaded["gitsigns"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			for _, b in ipairs(vim.api.nvim_list_bufs()) do
				local name = vim.api.nvim_buf_get_name(b)
				if name == path or name == other then
					pcall(vim.api.nvim_buf_delete, b, { force = true })
				end
			end
			vim.fn.setqflist({}, "r")
			os.remove(path)
			os.remove(other)
		end)

		it("panes open with the hydra, show placeholders when empty, close on quit", function()
			vim.g.mapleader = " "

			package.loaded["gitsigns"] = {
				setqflist = function() end,
				nav_hunk = function() end,
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
				preview_hunk = function() end,
			}
			package.loaded["frontend.tools.git_review_files"] = {
				repo_toplevels = function()
					return {}
				end,
				extra_entries_for = function()
					return {}
				end,
				append_missing = function()
					return 0
				end,
				collect = function()
					return vim.fn.getqflist({ size = 0 }).size
				end,
			}
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_hunk_display"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review"] = nil
			require("frontend.tools.git_review").config()
			local pages_mod = require("frontend.tools.git_review_pages")

			local buf_a = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_a, "/tmp/gitpages_single.lua")
			vim.fn.setqflist({ { bufnr = buf_a, lnum = 1, text = "own" } })
			vim.cmd("cc 1")
			vim.b[buf_a].gitsigns_status_dict = {}

			press(" g")
			assert(pages_mod.is_open(), "enter must auto-open the panes")
			assert(vim.fn.getqflist({ winid = 0 }).winid == 0, "enter must keep the quickfix window closed")

			-- A stuck bottom quickfix (e.g. left open from elsewhere) must
			-- not survive opening the panes: opening replaces it.
			vim.cmd("copen")
			assert(vim.fn.getqflist({ winid = 0 }).winid ~= 0, "fixture needs an open quickfix window")
			pages_mod.close()
			pages_mod.open()
			assert(pages_mod.is_open(), "open must reopen the panes")
			assert(vim.fn.getqflist({ winid = 0 }).winid == 0, "open must close the bottom quickfix window")
			press("q")
			assert(vim.g.active_hydra == nil, "q head never exited review mode")
			assert(not pages_mod.is_open(), "exit must close the page pane")
			assert(vim.fn.getqflist({ winid = 0 }).winid == 0, "exit must keep the quickfix window closed")

			-- Empty list: titled placeholder rows, cursor parked, no jump.
			vim.fn.setqflist({}, "r")
			press(" g")
			assert(pages_mod.is_open(), "enter must open panes even when empty")
			local files_buf, diffs_buf = nil, nil
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].filetype == "angst-git-files" then
					files_buf = buf
				elseif vim.bo[buf].filetype == "angst-git-diffs" then
					diffs_buf = buf
				end
			end
			assert(
				vim.inspect(vim.api.nvim_buf_get_lines(files_buf, 0, -1, false))
					== vim.inspect({ "(no changed files)" }),
				"empty files pane must show its placeholder"
			)
			assert(
				vim.inspect(vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false)) == vim.inspect({ "(no diffs)" }),
				"empty diffs pane must show its placeholder"
			)
			press("q")

			pcall(vim.cmd, "cclose")
			vim.fn.setqflist({}, "r")
			package.loaded["gitsigns"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			vim.api.nvim_buf_delete(buf_a, { force = true })
		end)

		it("Tab swaps the whole column to a branch diff that persists across hydra exits", function()
			vim.g.mapleader = " "
			assert(vim.fn.executable("git") == 1, "git binary required for fixture")

			local saved_cwd = vim.fn.getcwd()
			local root = vim.fn.tempname() .. "_gitbranch_tab"
			vim.fn.mkdir(root, "p")
			local function git(args)
				local cmd = { "git", "-C", root }
				vim.list_extend(cmd, args)
				local out = vim.fn.system(cmd)
				assert(
					vim.v.shell_error == 0,
					"fixture git failed: " .. table.concat(cmd, " ") .. "\n" .. out
				)
			end
			local function write(path, text)
				local fh = assert(io.open(path, "w"))
				fh:write(text)
				fh:close()
			end
			git({ "init", "-b", "main" })
			git({ "config", "user.email", "test@local" })
			git({ "config", "user.name", "test" })
			write(root .. "/a.txt", "one\ntwo\nthree\nfour\n")
			git({ "add", "." })
			git({ "commit", "-m", "base" })
			git({ "checkout", "-qb", "feature" })
			write(root .. "/a.txt", "one\nTWO\nthree\nfour\nfive\n")
			git({ "add", "a.txt" })
			git({ "commit", "-m", "feature change" })

			package.loaded["gitsigns"] = {
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
			}
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_review_files"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review_branch"] = nil
			package.loaded["frontend.tools.git_review"] = nil
			vim.g.angst_git_branch_diff_enabled = nil
			vim.g.angst_git_branch_diff_target = nil
			require("frontend.tools.git_review").config()
			local branch = require("frontend.tools.git_review_branch")
			local pages_mod = require("frontend.tools.git_review_pages")

			vim.cmd("cd " .. vim.fn.fnameescape(root))
			vim.cmd("edit " .. vim.fn.fnameescape(root .. "/a.txt"))
			local buf = vim.api.nvim_get_current_buf()

			press(" g")
			assert(pages_mod.is_open(), "enter must open the worktree panes")
			assert(not branch.is_enabled(), "branch mode must start disabled")

			branch._pick_override = function(cb)
				cb("main")
			end
			press("<Tab>")
			assert(branch.is_enabled(), "Tab must enable branch mode")
			assert(branch.target() == "main", "Tab must diff against the picked branch")
			assert(branch.is_open(), "Tab must open the branch column")
			assert(not pages_mod.is_open(), "Tab must replace the whole worktree column")
			local branch_files = branch.ordered_files()
			assert(
				#branch_files == 1 and branch_files[1].filename == root .. "/a.txt",
				"branch column must list the branch-changed file"
			)

			-- Markdown-style badge shows the compared-against branch.
			assert(
				branch._badge.entries["git-branch-diff"] == "⇄ main",
				"badge must show the diff target, got: " .. vim.inspect(branch._badge.entries)
			)

			-- Bg-tint overlay paints the branch hunks in the code
			-- buffer (feature changed line 2, added line 5).
			local branch_hunks = require("frontend.tools.git_branch_hunks")
			local function tint_groups()
				local seen = {}
				for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, branch_hunks.ns, 0, -1, { details = true })) do
					seen[m[4].line_hl_group] = true
				end
				return seen
			end
			local tints = tint_groups()
			assert(
				tints["GitSignsChangeLn"] and tints["GitSignsAddLn"],
				"code buffer must tint branch hunks bg-only, got: " .. vim.inspect(tints)
			)

			vim.fn.setqflist({}, "r")
			press("l")
			assert(vim.api.nvim_get_current_buf() == buf, "branch l must not leave the file")
			assert(
				vim.fn.getqflist({ size = 0 }).size == 0,
				"branch navigation must not touch the worktree quickfix"
			)
			assert(next(tint_groups()) ~= nil, "branch l must keep the overlay painted")

			-- `d` flips the branch overlay together with gitsigns.
			vim.b[buf].gitsigns_status_dict = {}
			press("d")
			assert(next(tint_groups()) == nil, "d off must clear the branch overlay")
			press("d")
			assert(next(tint_groups()) ~= nil, "d on must restore the branch overlay")
			vim.b[buf].gitsigns_status_dict = nil

			press("q")
			assert(vim.g.active_hydra == nil, "q head never exited review mode")
			assert(branch.is_enabled(), "branch mode must persist after hydra exit")
			assert(not branch.is_open(), "q must close the branch column")
			assert(
				branch._badge.entries["git-branch-diff"] == "⇄ main",
				"badge must persist after hydra exit"
			)
			assert(next(tint_groups()) ~= nil, "overlay must persist after hydra exit")

			press(" g")
			assert(branch.is_open(), "re-enter must reopen the branch column")
			assert(not pages_mod.is_open(), "re-enter must not reopen worktree panes while branch persists")

			branch._pick_override = function()
				error("picker must not run on disable")
			end
			press("<Tab>")
			assert(not branch.is_enabled(), "second Tab must disable branch mode")
			assert(not branch.is_open(), "second Tab must close the branch column")
			assert(pages_mod.is_open(), "second Tab must restore the worktree column")
			assert(
				next(branch._badge.entries) == nil,
				"disable must hide the badge, got: " .. vim.inspect(branch._badge.entries)
			)
			assert(
				#vim.api.nvim_buf_get_extmarks(buf, branch_hunks.ns, 0, -1, {}) == 0,
				"disable must clear the branch overlay"
			)
			press("q")

			branch._reset()
			pages_mod._reset()
			vim.g.angst_git_branch_diff_enabled = nil
			vim.g.angst_git_branch_diff_target = nil
			vim.cmd("cd " .. vim.fn.fnameescape(saved_cwd))
			package.loaded["gitsigns"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review_branch"] = nil
			vim.api.nvim_buf_delete(buf, { force = true })
			vim.fn.setqflist({}, "r")
			vim.fn.delete(root, "rf")
		end)

		it("branch toggle skips the current branch and auto-disables on empty ranges", function()
			vim.g.mapleader = " "
			assert(vim.fn.executable("git") == 1, "git binary required for fixture")

			local saved_cwd = vim.fn.getcwd()
			local root = vim.fn.tempname() .. "_gitbranch_empty"
			vim.fn.mkdir(root, "p")
			local function git(args)
				local cmd = { "git", "-C", root }
				vim.list_extend(cmd, args)
				local out = vim.fn.system(cmd)
				assert(
					vim.v.shell_error == 0,
					"fixture git failed: " .. table.concat(cmd, " ") .. "\n" .. out
				)
			end
			git({ "init", "-b", "main" })
			git({ "config", "user.email", "test@local" })
			git({ "config", "user.name", "test" })
			local fh = assert(io.open(root .. "/a.txt", "w"))
			fh:write("one\n")
			fh:close()
			git({ "add", "." })
			git({ "commit", "-m", "base" })
			git({ "checkout", "-qb", "feature" })

			package.loaded["gitsigns"] = {
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
			}
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_hunk_display"] = nil
			package.loaded["frontend.tools.git_review_files"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review_branch"] = nil
			package.loaded["frontend.tools.git_review"] = nil
			vim.g.angst_git_branch_diff_enabled = nil
			vim.g.angst_git_branch_diff_target = nil
			require("frontend.tools.git_review").config()
			local branch = require("frontend.tools.git_review_branch")
			local pages_mod = require("frontend.tools.git_review_pages")

			vim.cmd("cd " .. vim.fn.fnameescape(root))
			vim.cmd("edit " .. vim.fn.fnameescape(root .. "/a.txt"))
			local buf = vim.api.nvim_get_current_buf()

			-- The picker must not offer the current branch:
			-- self-compare is always empty.
			package.preload["fzf-lua"] = function()
				error("fzf must stay out of the picker test")
			end
			local picked_items = nil
			local orig_select = vim.ui.select
			vim.ui.select = function(items, _, on_choice)
				picked_items = items
				on_choice(nil)
			end
			branch._pick_override = nil
			local chosen = "unset"
			branch.pick_target(function(target)
				chosen = target
			end)
			assert(chosen == nil, "cancelling the picker must yield nil")
			assert(picked_items ~= nil, "picker must list branches")
			assert(
				not vim.tbl_contains(picked_items, "feature"),
				"picker must skip the current branch, got: " .. vim.inspect(picked_items)
			)
			assert(
				vim.tbl_contains(picked_items, "main"),
				"picker must keep other branches, got: " .. vim.inspect(picked_items)
			)
			vim.ui.select = orig_select
			package.preload["fzf-lua"] = nil

			-- Enabling against the current branch finds no changes:
			-- auto-disable with a notice, worktree column restored.
			press(" g")
			local notes = {}
			local orig_notify = vim.notify
			vim.notify = function(msg, ...)
				notes[#notes + 1] = tostring(msg)
			end
			branch._pick_override = function(cb)
				cb("feature")
			end
			press("<Tab>")
			vim.notify = orig_notify
			assert(not branch.is_enabled(), "empty range must auto-disable branch mode")
			assert(not branch.is_open(), "empty range must not leave a branch column")
			assert(next(branch._badge.entries) == nil, "empty range must not show a badge")
			assert(pages_mod.is_open(), "empty range must restore the worktree column")
			assert(
				table.concat(notes, "\n"):find("no changes between HEAD and feature", 1, true),
				"empty range must explain itself, got: " .. vim.inspect(notes)
			)
			press("q")

			branch._reset()
			pages_mod._reset()
			vim.g.angst_git_branch_diff_enabled = nil
			vim.g.angst_git_branch_diff_target = nil
			vim.cmd("cd " .. vim.fn.fnameescape(saved_cwd))
			package.loaded["gitsigns"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			package.loaded["frontend.tools.git_review_branch"] = nil
			vim.api.nvim_buf_delete(buf, { force = true })
			vim.fn.setqflist({}, "r")
			vim.fn.delete(root, "rf")
		end)

		it("hydra runs on_exit when deactivating", function()
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			local Hydra = require("common.Hydra")
			local palette = require("config.theme.palette")

			local exited = 0
			local hydra = Hydra.new({
				name = "ExitTest",
				fg_color = palette.p.accent.base,
				bg_color = palette.p.background.base,
				enter = "<leader>Y",
				global = true,
				logger = require("common.Logger").new("TEST"),
				on_exit = function()
					exited = exited + 1
				end,
				heads = {
					{ "a", function() end, "Alpha" },
				},
			})

			press("<leader>Y")
			assert(vim.g.active_hydra ~= nil and vim.g.active_hydra.name == "ExitTest", "test hydra never activated")
			assert(exited == 0, "on_exit must not run on enter")
			hydra:deactivate()
			assert(exited == 1, "on_exit must run once on deactivate")
			hydra:purge()
			assert(vim.g.active_hydra == nil, "test hydra never deactivated")
		end)

		it("every hydra toggles help with ?", function()
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			local Hydra = require("common.Hydra")
			local palette = require("config.theme.palette")

			local hydra = Hydra.new({
				name = "HelpTest",
				fg_color = palette.p.accent.base,
				bg_color = palette.p.background.base,
				enter = "<leader>Z",
				global = true,
				logger = require("common.Logger").new("TEST"),
				heads = {
					{ "a", function() end, "Alpha action" },
					{ "b", function() end, "Beta action" },
				},
			})

			press("<leader>Z")
			assert(vim.g.active_hydra ~= nil and vim.g.active_hydra.name == "HelpTest", "test hydra never activated")
			assert(hint_win("Alpha action") == nil, "? hydra must not auto-popup without hint flag")

			press("?")
			assert(hint_win("Alpha action") ~= nil, "? never opened help float")
			assert(hint_win("Beta action") ~= nil, "help float must list every head")
			press("?")
			assert(hint_win("Alpha action") == nil, "? never closed help float")

			hydra:deactivate()
			hydra:purge()
			assert(vim.g.active_hydra == nil, "test hydra never deactivated")
		end)

		it("hydra keeps its own ? head when defined", function()
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			local Hydra = require("common.Hydra")
			local palette = require("config.theme.palette")

			local ran = false
			local hydra = Hydra.new({
				name = "OwnHelp",
				fg_color = palette.p.accent.base,
				bg_color = palette.p.background.base,
				enter = "<leader>X",
				global = true,
				logger = require("common.Logger").new("TEST"),
				heads = {
					{
						"?",
						function()
							ran = true
						end,
						"Custom help",
						exit = true,
					},
				},
			})

			press("<leader>X")
			press("?")
			assert(ran, "hydra's own ? head must run instead of the toggle")
			assert(vim.g.active_hydra == nil, "exiting ? head must deactivate")
			hydra:purge()
		end)

		it("n collects once synchronously, then diagnoses emptiness", function()
			package.loaded["common.Hydra"] = nil
			package.loaded["common.Keybinder"] = nil
			package.loaded["frontend.tools.git_review_pages"] = nil
			local buf_a = vim.api.nvim_create_buf(false, true)
			local buf_b = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf_a, "/tmp/gitpages_async_a.lua")
			vim.api.nvim_buf_set_name(buf_b, "/tmp/gitpages_async_b.lua")
			local fills = 0
			package.loaded["frontend.tools.git_review_files"] = {
				repo_toplevels = function()
					return {}
				end,
				extra_entries_for = function()
					return {}
				end,
				append_missing = function()
					return 0
				end,
				collect = function()
					fills = fills + 1
					vim.fn.setqflist({
						{ bufnr = buf_a, lnum = 1, text = "1: (+1) A" },
						{ bufnr = buf_a, lnum = 2, text = "2: (~2) M" },
						{ bufnr = buf_b, lnum = 1, text = "1: (+1) A" },
					}, "r")
					return 3
				end,
			}
			package.loaded["frontend.tools.git_review"] = nil
			require("frontend.tools.git_review").config()

			package.loaded["gitsigns"] = {
				get_hunks = function()
					return nil
				end,
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
			}

			press(" g")
			vim.fn.setqflist({}, "r")
			press("n")
			-- Single synchronous fill: the jump lands in the same tick,
			-- no waiting for a deferred or async pass.
			assert(vim.api.nvim_get_current_buf() == buf_a, "n must jump after a single fill")
			assert(fills == 1, "n must fill exactly once, got " .. fills)
			assert(vim.fn.getqflist({ winid = 0 }).winid == 0, "collection must never show a bottom quickfix window")
			-- The diffs pane lists every diff and h/l cycles them.
			local pages_mod = require("frontend.tools.git_review_pages")
			assert(pages_mod.is_open(), "n must open the pane after fill")
			local diffs_buf = nil
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				local buf = vim.api.nvim_win_get_buf(win)
				if vim.bo[buf].filetype == "angst-git-diffs" then
					diffs_buf = buf
					break
				end
			end
			assert(diffs_buf ~= nil, "diffs pane missing")
			assert(
				vim.inspect(vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false))
					== vim.inspect({ "> 1: (+1) A", "  2: (~2) M" }),
				"pane must show every diff after the fill, got: "
					.. vim.inspect(vim.api.nvim_buf_get_lines(diffs_buf, 0, -1, false))
			)
			press("l")
			assert(vim.fn.getqflist({ idx = 0 }).idx == 2, "l must cycle to the next diff")
			assert(vim.api.nvim_get_current_buf() == buf_a, "l must not leave the file")
			assert(fills == 1, "stepping diffs must not re-collect, got " .. fills)
			press("q")

			package.loaded["gitsigns"] = {
				get_hunks = function()
					return nil
				end,
				toggle_deleted = function() end,
				toggle_linehl = function() end,
				toggle_word_diff = function() end,
				preview_hunk = function() end,
				nav_hunk = function() end,
			}
			package.loaded["frontend.tools.git_review_files"] = {
				repo_toplevels = function()
					return {}
				end,
				extra_entries_for = function()
					return {}
				end,
				append_missing = function()
					return 0
				end,
				collect = function()
					return 0
				end,
			}
			-- Rebind: the hydra holds the previous fake as an upvalue.
			package.loaded["frontend.tools.git_review"] = nil
			require("frontend.tools.git_review").config()
			vim.fn.setqflist({}, "r")
			local messages = {}
			local orig_notify = vim.notify
			vim.notify = function(msg, ...)
				messages[#messages + 1] = tostring(msg)
			end
			press(" g")
			press("n")
			vim.wait(1500, function()
				return #messages > 1
			end)
			vim.notify = orig_notify
			local text = table.concat(messages, "\n")
			assert(text:find("collecting", 1, true), "must announce collection, got: " .. text)
			assert(text:find("no changed files", 1, true), "must diagnose emptiness, got: " .. text)
			assert(text:find(vim.fn.getcwd(), 1, true), "diagnosis must show cwd, got: " .. text)
			press("q")

			package.loaded["gitsigns"] = nil
			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })
		end)

		it("collect writes worktree hunks and extras as one replaced list", function()
			-- Real module, stubbed gitsigns cache, cwd outside any repo
			-- so no real git leaks in: the list must hold exactly the
			-- cached hunks, and a second collect must replace, not grow.
			local saved_cwd = vim.fn.getcwd()
			local dir = vim.fn.tempname() .. "_gitreview_nowhere"
			vim.fn.mkdir(dir, "p")
			vim.cmd("cd " .. vim.fn.fnameescape(dir))

			local buf_a = vim.api.nvim_create_buf(true, false)
			local buf_b = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(buf_a, "/tmp/gitpages_collect_a.lua")
			vim.api.nvim_buf_set_name(buf_b, "/tmp/gitpages_collect_b.lua")
			package.loaded["gitsigns"] = {
				get_hunks = function(bufnr)
					if bufnr == buf_a then
						return {
							{
								type = "change",
								added = { start = 3, count = 1 },
								removed = { start = 3, count = 1 },
								lines = { "-old", "+new" },
							},
						}
					elseif bufnr == buf_b then
						return {
							{
								type = "add",
								added = { start = 1, count = 2 },
								removed = { start = 0, count = 0 },
								lines = { "+one", "+two" },
							},
						}
					end
					return nil
				end,
			}
			package.loaded["frontend.tools.git_review_files"] = nil
			local files = require("frontend.tools.git_review_files")

			vim.fn.setqflist({}, "r")
			local n = files.collect()
			local n2 = files.collect()
			vim.cmd("cd " .. vim.fn.fnameescape(saved_cwd))
			assert(n == 2, "collect must write both cached hunks, got " .. n)
			local items = vim.fn.getqflist()
			assert(#items == 2, "quickfix must hold exactly the combined list")
			assert(
				items[1].bufnr == buf_a and items[1].lnum == 3,
				"first hunk must keep bufnr and line, got: " .. vim.inspect(items[1])
			)
			assert(
				items[1].text == "3: (~1) M",
				"worktree change must render compact, got: " .. items[1].text
			)
			assert(
				items[2].bufnr == buf_b and items[2].lnum == 1 and items[2].text == "1: (+2) A",
				"second hunk must keep bufnr, line and compact text, got: " .. vim.inspect(items[2])
			)
			assert(
				n2 == 2 and vim.fn.getqflist({ size = 0 }).size == 2,
				"a second collect must replace the list, not append"
			)

			vim.fn.setqflist({}, "r")
			package.loaded["gitsigns"] = nil
			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })
			vim.fn.delete(dir, "rf")
		end)

		it("pane rows show icons and repo-relative paths", function()
			package.loaded["frontend.tools.git_review_pages"] = nil
			local pages = require("frontend.tools.git_review_pages")

			assert(pages.icon_for("/tmp/x.lua") == "", "icon must fall back to empty without devicons")

			package.loaded["nvim-web-devicons"] = {
				get_icon = function(name)
					assert(type(name) == "string", "icon lookup needs the filename")
					return "I"
				end,
			}
			package.loaded["frontend.tools.git_review_pages"] = nil
			pages = require("frontend.tools.git_review_pages")
			assert(pages.icon_for("/tmp/x.lua") == "I ", "icon must render with a trailing space")
			package.loaded["nvim-web-devicons"] = nil

			assert(vim.fn.executable("git") == 1, "git binary required for fixture")
			local root = vim.fn.tempname() .. "_gitreview_rel"
			local sub = root .. "/work/a/b"
			vim.fn.mkdir(sub, "p")
			local out = vim.fn.system({ "git", "-C", sub, "init", "-q" })
			assert(vim.v.shell_error == 0, "fixture git init failed: " .. out)
			local top = vim.fn.systemlist({ "git", "-C", sub, "rev-parse", "--show-toplevel" })[1]
			local abs = top .. "/a/b/c.lua"
			assert(pages.relpath(abs, { top }) == "a/b/c.lua", "rows must be repo-rooted")
			assert(pages.relpath(abs, { top, top .. "/a" }) == "b/c.lua", "longest toplevel must win")
			assert(pages.relpath("/tmp/elsewhere.lua", { top }) == "/tmp/elsewhere.lua", "outside files stay absolute")
			vim.fn.delete(root, "rf")
		end)

		it("file rows show tails, selected rows the whole repo-rooted path", function()
			package.loaded["frontend.tools.git_review_pages"] = nil
			local pages = require("frontend.tools.git_review_pages")

			-- Non-selected rows: marker, tail only (no icon headless).
			assert(
				pages.file_row("/repo/a/b/c.lua", false, { "/repo" }) == "  c.lua",
				"non-selected rows show bare tails"
			)
			assert(
				pages.file_row("/tmp/x.lua", false, {}) == "  x.lua",
				"outside-repo tails stay bare"
			)
			-- Selected rows: marker plus the whole repo-rooted path on
			-- one logical line (soft-wrapped by the window itself).
			assert(
				pages.file_row("/repo/a/b.lua", true, { "/repo" }) == "▸ a/b.lua",
				"selected rows show the whole path"
			)
			assert(
				pages.file_row("/tmp/x.lua", true, {}) == "▸ /tmp/x.lua",
				"selected rows fall back to absolute paths"
			)
		end)

		it("diff rows tint by change kind", function()
			package.loaded["frontend.tools.git_review_pages"] = nil
			local pages = require("frontend.tools.git_review_pages")

			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf, "/tmp/gitpages_kinds.lua")
			vim.fn.setqflist({}, "r")
			vim.fn.setqflist({
				{ bufnr = buf, lnum = 1, text = "1: (+2) A" },
				{ bufnr = buf, lnum = 3, text = "3: (~1) M" },
				{ bufnr = buf, lnum = 5, text = "5: (-1) D" },
				{ bufnr = buf, lnum = 1, text = "1: (+1) ??" },
			})
			vim.api.nvim_set_current_buf(buf)
			vim.cmd("cc 1")
			pages.open()
			assert(pages.is_open(), "panes must open for the tint check")

			local diffs_win = nil
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "angst-git-diffs" then
					diffs_win = win
					break
				end
			end
			assert(diffs_win ~= nil, "diffs pane missing")
			local seen = {}
			for _, m in ipairs(vim.fn.getmatches(diffs_win)) do
				seen[m.group] = (seen[m.group] or 0) + 1
			end
			for _, group in ipairs({
				"GitReviewAdded",
				"GitReviewChanged",
				"GitReviewDeleted",
				"GitReviewUntracked",
			}) do
				assert(seen[group] == 1, "expected exactly one match for " .. group)
			end
			-- cc 1 marked the A row: the selection cursor takes its kind.
			assert(
				vim.api.nvim_win_get_option(diffs_win, "winhighlight") == "CursorLine:GitReviewCursorAdded",
				"selection cursor must take the marked hunk kind"
			)

			pages.close()
			vim.fn.setqflist({}, "r")
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("review extras cover staged and unpushed files", function()
			assert(vim.fn.executable("git") == 1, "git binary required for fixture")

			local root = vim.fn.tempname() .. "_gitreview"
			vim.fn.mkdir(root, "p")
			local origin = root .. "/origin.git"
			local work = root .. "/work"

			local function git(cwd, args)
				local cmd = { "git", "-C", cwd }
				vim.list_extend(cmd, args)
				local out = vim.fn.systemlist(cmd)
				assert(
					vim.v.shell_error == 0,
					"fixture git failed: " .. table.concat(cmd, " ") .. "\n" .. table.concat(out, "\n")
				)
				return out
			end
			local function write(path, text)
				local f = assert(io.open(path, "w"))
				f:write(text)
				f:close()
			end

			git(root, { "init", "--bare", "-b", "main", origin })
			git(root, {
				"clone",
				"-c",
				"protocol.file.allow=always",
				origin,
				work,
			})
			git(work, { "config", "user.email", "test@local" })
			git(work, { "config", "user.name", "test" })
			write(work .. "/a.txt", "one\n")
			write(work .. "/c.txt", "see\n")
			write(work .. "/d.txt", "gone\n")
			git(work, { "add", "a.txt", "c.txt", "d.txt" })
			git(work, { "commit", "-m", "base" })
			git(work, { "push", "-u", "origin", "main" })

			write(work .. "/e.txt", "local\n")
			git(work, { "add", "e.txt" })
			git(work, { "commit", "-m", "local-only" })

			local f = assert(io.open(work .. "/a.txt", "a"))
			f:write("two\n")
			f:close()
			git(work, { "add", "a.txt" })
			write(work .. "/b.txt", "new\n")
			git(work, { "add", "b.txt" })
			git(work, { "rm", "-q", "d.txt" })
			local c = assert(io.open(work .. "/c.txt", "a"))
			c:write("un-staged\n")
			c:close()

			package.loaded["frontend.tools.git_review_files"] = nil
			local files = require("frontend.tools.git_review_files")
			local entries = files.extra_entries_for({ work })

			local by_file = {}
			for _, e in ipairs(entries) do
				assert(e.lnum ~= nil and e.lnum >= 1, "entry needs a sane lnum")
				by_file[e.filename] = by_file[e.filename] or {}
				by_file[e.filename][#by_file[e.filename] + 1] = e
			end

			local function texts_for(path)
				local out = {}
				for _, e in ipairs(by_file[path] or {}) do
					out[#out + 1] = e.text
				end
				return out
			end

			assert(
				vim.inspect(texts_for(work .. "/a.txt")) == vim.inspect({ "2: (+1) A" }),
				"staged-only modify must list, got: " .. vim.inspect(texts_for(work .. "/a.txt"))
			)
			assert(
				vim.inspect(texts_for(work .. "/b.txt")) == vim.inspect({ "1: (+1) A" }),
				"staged-new file must list, got: " .. vim.inspect(texts_for(work .. "/b.txt"))
			)
			assert(
				vim.inspect(texts_for(work .. "/e.txt")) == vim.inspect({ "1: (+1) A" }),
				"local-only commit must list, got: " .. vim.inspect(texts_for(work .. "/e.txt"))
			)
			assert(
				vim.inspect(texts_for(work .. "/c.txt")) == vim.inspect({ "2: (+1) A" }),
				"unopened unstaged file must list, got: " .. vim.inspect(texts_for(work .. "/c.txt"))
			)
			assert(by_file[work .. "/d.txt"] == nil, "staged-deleted has no buffer to show")

			-- c.txt's unstaged hunk is already listed at the same
			-- file+lnum (e.g. by gitsigns): only the rest may append.
			local c_lnum = by_file[work .. "/c.txt"][1].lnum
			vim.fn.setqflist({ { filename = work .. "/c.txt", lnum = c_lnum, text = "x" } })
			local added = files.append_missing(entries)
			assert(added == 3, "must append exactly staged+unpushed, got " .. added)

			local counts = {}
			for _, item in ipairs(vim.fn.getqflist()) do
				local name = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or item.filename
				counts[name] = (counts[name] or 0) + 1
			end
			assert(counts[work .. "/c.txt"] == 1, "already-listed hunks must not duplicate")
			assert(counts[work .. "/a.txt"] == 1, "a.txt must appear once")
			assert(counts[work .. "/b.txt"] == 1, "b.txt must appear once")
			assert(counts[work .. "/e.txt"] == 1, "e.txt must appear once")

			vim.fn.setqflist({}, "r")
			vim.fn.delete(root, "rf")
		end)

		it("review extras cover unstaged and untracked files without opening them", function()
			assert(vim.fn.executable("git") == 1, "git binary required for fixture")

			local root = vim.fn.tempname() .. "_gitreview_unstaged"
			local work = root .. "/work"
			vim.fn.mkdir(work, "p")

			local function git(args)
				local cmd = { "git", "-C", work }
				vim.list_extend(cmd, args)
				local out = vim.fn.systemlist(cmd)
				assert(
					vim.v.shell_error == 0,
					"fixture git failed: " .. table.concat(cmd, " ") .. "\n" .. table.concat(out, "\n")
				)
				return out
			end
			local function write(path, text)
				local f = assert(io.open(path, "w"))
				f:write(text)
				f:close()
			end

			git({ "init", "-b", "main" })
			git({ "config", "user.email", "test@local" })
			git({ "config", "user.name", "test" })
			write(work .. "/x.txt", "x\n")
			write(work .. "/y.txt", "y1\ny2\ny3\n")
			git({ "add", "x.txt", "y.txt" })
			git({ "commit", "-m", "base" })

			-- Staged modify of x, unstaged modify of y (never opened in
			-- any buffer), plus a brand-new untracked file z.
			local xf = assert(io.open(work .. "/x.txt", "a"))
			xf:write("x2\n")
			xf:close()
			git({ "add", "x.txt" })
			write(work .. "/y.txt", "y1\nCHANGED\ny3\n")
			write(work .. "/z.txt", "fresh\n")

			package.loaded["frontend.tools.git_review_files"] = nil
			local files = require("frontend.tools.git_review_files")
			local entries = files.extra_entries_for({ work })

			local by_file = {}
			for _, e in ipairs(entries) do
				assert(e.lnum ~= nil and e.lnum >= 1, "entry needs a sane lnum")
				by_file[e.filename] = by_file[e.filename] or {}
				by_file[e.filename][#by_file[e.filename] + 1] = e
			end

			local function texts_for(path)
				local out = {}
				for _, e in ipairs(by_file[path] or {}) do
					out[#out + 1] = e.text
				end
				return out
			end

			assert(
				vim.inspect(texts_for(work .. "/x.txt")) == vim.inspect({ "2: (+1) A" }),
				"staged modify must list, got: " .. vim.inspect(texts_for(work .. "/x.txt"))
			)
			assert(
				vim.inspect(texts_for(work .. "/y.txt")) == vim.inspect({ "2: (~1) M" }),
				"unopened unstaged file must list, got: " .. vim.inspect(texts_for(work .. "/y.txt"))
			)
			local z = by_file[work .. "/z.txt"] or {}
			assert(#z == 1, "untracked file must contribute exactly one stop, got " .. #z)
			assert(z[1].lnum == 1 and z[1].text == "1: (+1) ??", "untracked stop must sit at line 1")

			-- A gitsigns worktree hunk for y.txt at the same line
			-- suppresses the duplicate; everything else still appends.
			local y_lnum = by_file[work .. "/y.txt"][1].lnum
			vim.fn.setqflist({}, "r")
			vim.fn.setqflist({ { filename = work .. "/y.txt", lnum = y_lnum, text = "worktree" } })
			local added = files.append_missing(entries)
			assert(added == #entries - 1, "must skip only the covered hunk, got " .. added)

			local names = {}
			for _, item in ipairs(vim.fn.getqflist()) do
				local name = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or item.filename
				names[name] = (names[name] or 0) + 1
			end
			assert(names[work .. "/y.txt"] == 1, "covered hunk must not duplicate")
			assert(names[work .. "/z.txt"] == 1, "untracked file must append unopened")

			vim.fn.setqflist({}, "r")
			vim.fn.delete(root, "rf")
		end)

		it("git theme groups cover neogit and gitsigns", function()
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
				"GitSignsAddLn",
				"GitSignsChangeLn",
				"GitSignsDeleteLn",
				"GitSignsAddPreview",
				"GitSignsDeletePreview",
				"GitSignsChangePreview",
				"GitSignsAddInline",
				"GitSignsDeleteInline",
				"GitSignsChangeInline",

				"NeogitHunkHeader",
				"NeogitDiffAdd",
				"NeogitBranch",
				"NeogitSectionHeader",
				"NeogitSectionHeaderCount",
				"NeogitFilePath",
				"NeogitChangeModified",
				"NeogitChangeAdded",
				"NeogitChangeNewFile",
				"NeogitChangeDeleted",
				"NeogitChangeRenamed",
				"NeogitChangeCopied",
				"NeogitChangeUpdated",
				"NeogitChangeUnmerged",
				"NeogitChangeUntracked",
				"NeogitDiffHeader",
				"NeogitDiffHeaderHighlight",
				"NeogitHunkHeaderCursor",
				"GitReviewCursor",
				"GitReviewHeader",
				"GitReviewAdded",
				"GitReviewChanged",
				"GitReviewDeleted",
				"GitReviewUntracked",
				"GitReviewCursorAdded",
				"GitReviewCursorChanged",
				"GitReviewCursorDeleted",
				"GitReviewCursorUntracked",
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

			-- Bg-only hunks: 3 distinct line backgrounds, no text recolor.
			local seen_bg = {}
			for _, name in ipairs({ "GitSignsAddLn", "GitSignsChangeLn", "GitSignsDeleteLn" }) do
				local hl = groups[name]
				assert(hl.bg ~= nil, name .. " must set a background")
				assert(hl.fg == nil, name .. " must not recolor code text")
				assert(seen_bg[hl.bg] == nil, name .. " bg must differ from other hunk kinds")
				seen_bg[hl.bg] = name
			end
			for _, name in ipairs({ "GitSignsAddInline", "GitSignsChangeInline", "GitSignsDeleteInline" }) do
				assert(groups[name].fg == nil, name .. " must not recolor code text")
			end

			package.loaded["config.theme.groups.init"] = nil
			local all = require("config.theme.groups").get()
			assert(all["NeogitHunkHeader"] ~= nil, "theme init must include git groups")
			assert(all["GitSignsAdd"] ~= nil, "theme init must include git groups")
		end)
	end)
end
