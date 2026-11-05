local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local function press(lhs)
	local map = vim.fn.maparg(lhs, "n", false, true)
	assert(
		type(map) == "table" and next(map) ~= nil and type(map.callback) == "function",
		"expected a lua mapping for " .. lhs
	)
	map.callback()
end

local function make_buffer(name)
	local bufnr = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(bufnr, name)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two", "three", "four", "five" })
	return bufnr
end

local function badge_window(text)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok, config = pcall(vim.api.nvim_win_get_config, win)

		if ok and config.relative == "editor" and config.focusable == false then
			local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)

			if table.concat(lines, "\n"):find(text, 1, true) then
				return win
			end
		end
	end

	return nil
end

local function fresh()
	package.loaded["frontend.navigation.spring"] = nil
	package.loaded["frontend.navigation.spring.state"] = nil
	package.loaded["frontend.navigation.spring.actions"] = nil
	package.loaded["common.Badge"] = nil
	package.loaded["common.Keybinder"] = nil

	local state = require("frontend.navigation.spring.state")
	state.reset()

	require("frontend.navigation.spring").config()

	return state, require("frontend.navigation.spring.actions")
end

return function()
	describe("spring navigation", function()
		it("binds gs in normal mode", function()
			fresh()

			local map = vim.fn.maparg("gs", "n", false, true)
			assert(type(map) == "table" and type(map.callback) == "function", "gs must be mapped")
		end)

		it("pulls and releases back to the original buffer and cursor", function()
			local state = fresh()
			local original = vim.api.nvim_get_current_buf()
			local buf_a = make_buffer(vim.fn.tempname() .. "_spring_a.lua")
			local buf_b = make_buffer(vim.fn.tempname() .. "_spring_b.lua")

			vim.api.nvim_set_current_buf(buf_a)
			vim.api.nvim_win_set_cursor(0, { 3, 2 })
			press("gs")
			assert(state.is_active(), "gs must pull")

			vim.api.nvim_set_current_buf(buf_b)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			assert(state.is_active(), "spring must stay active while navigating")

			press("gs")
			assert(not state.is_active(), "gs must release")
			assert(vim.api.nvim_get_current_buf() == buf_a, "release must return to the origin buffer")
			assert(
				vim.inspect(vim.api.nvim_win_get_cursor(0)) == vim.inspect({ 3, 2 }),
				"release must restore the origin cursor"
			)

			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })

			if vim.api.nvim_buf_is_valid(original) then
				vim.api.nvim_set_current_buf(original)
			end
		end)

		it("tracks visited files in a left-aligned badge", function()
			local state = fresh()
			local original = vim.api.nvim_get_current_buf()
			local buf_a = make_buffer(vim.fn.tempname() .. "_spring_root.lua")
			local buf_b = make_buffer(vim.fn.tempname() .. "_spring_one.lua")
			local buf_c = make_buffer(vim.fn.tempname() .. "_spring_two.lua")

			vim.api.nvim_set_current_buf(buf_a)
			press("gs")
			vim.api.nvim_set_current_buf(buf_b)
			vim.api.nvim_set_current_buf(buf_c)

			local label_a = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_a), ":t")
			local label_b = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_b), ":t")
			local label_c = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_c), ":t")

			assert(
				vim.inspect(state.chain()) == vim.inspect({ label_a, label_b, label_c }),
				"chain must follow visited files"
			)

			local win = badge_window(label_a .. " > " .. label_b .. " > " .. label_c)
			assert(win ~= nil, "spring badge must show the visited chain")
			assert(vim.api.nvim_win_get_config(win).col == 0, "spring badge must be left-aligned")

			press("gs")
			assert(not state.is_active(), "release must clear spring")
			assert(badge_window(label_a) == nil, "release must hide the spring badge")

			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })
			vim.api.nvim_buf_delete(buf_c, { force = true })

			if vim.api.nvim_buf_is_valid(original) then
				vim.api.nvim_set_current_buf(original)
			end
		end)

		it("does not add the same file twice", function()
			local state = fresh()
			local original = vim.api.nvim_get_current_buf()
			local buf_a = make_buffer(vim.fn.tempname() .. "_spring_same_a.lua")
			local buf_b = make_buffer(vim.fn.tempname() .. "_spring_same_b.lua")

			vim.api.nvim_set_current_buf(buf_a)
			press("gs")

			local label_a = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_a), ":t")
			local label_b = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_b), ":t")

			vim.api.nvim_set_current_buf(buf_b)
			vim.api.nvim_set_current_buf(buf_a)

			assert(
				vim.inspect(state.chain()) == vim.inspect({ label_a, label_b }),
				"returning to a visited file must not add a duplicate badge segment"
			)

			press("gs")

			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })

			if vim.api.nvim_buf_is_valid(original) then
				vim.api.nvim_set_current_buf(original)
			end
		end)

		it("renders a single-file badge without a dangling separator", function()
			local state = fresh()
			local original = vim.api.nvim_get_current_buf()
			local buf_a = make_buffer(vim.fn.tempname() .. "_spring_single.lua")

			vim.api.nvim_set_current_buf(buf_a)
			press("gs")

			local label_a = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_a), ":t")

			assert(vim.inspect(state.chain()) == vim.inspect({ label_a }), "chain must start with one file")
			assert(badge_window(label_a) ~= nil, "single-file badge must be visible")
			assert(badge_window(label_a .. " >") == nil, "single-file badge must not show a dangling separator")

			press("gs")

			vim.api.nvim_buf_delete(buf_a, { force = true })

			if vim.api.nvim_buf_is_valid(original) then
				vim.api.nvim_set_current_buf(original)
			end
		end)

		it("resizes the badge when the chain grows", function()
			local state = fresh()
			local original = vim.api.nvim_get_current_buf()
			local buf_a = make_buffer(vim.fn.tempname() .. "_spring_resize_a.lua")
			local buf_b = make_buffer(vim.fn.tempname() .. "_spring_resize_b.lua")

			vim.api.nvim_set_current_buf(buf_a)
			press("gs")

			local label_a = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_a), ":t")
			local label_b = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf_b), ":t")

			vim.api.nvim_set_current_buf(buf_b)

			assert(vim.inspect(state.chain()) == vim.inspect({ label_a, label_b }), "chain must grow")

			local win = badge_window(label_a .. " > " .. label_b)
			assert(win ~= nil, "badge must show the full chain")

			local content = table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
			local width = vim.api.nvim_win_get_config(win).width

			assert(width >= vim.fn.strdisplaywidth(content), "badge window must resize to fit the full chain")

			press("gs")

			vim.api.nvim_buf_delete(buf_a, { force = true })
			vim.api.nvim_buf_delete(buf_b, { force = true })

			if vim.api.nvim_buf_is_valid(original) then
				vim.api.nvim_set_current_buf(original)
			end
		end)
	end)
end
