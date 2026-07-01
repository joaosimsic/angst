---@type Logger
local Logger = require("common.Logger")

---@type Plugin
return {
	"anchor",
	virtual = true,
	lazy = false,
	config = function()
		local group = vim.api.nvim_create_augroup("AnchorPlugin", { clear = true })
		local logger = Logger.new("ANCHOR", "debug")

		local function set_window_title(name)
			local win = vim.fn.bufwinid(vim.fn.bufnr())
			if win and win ~= -1 then
				pcall(vim.api.nvim_win_set_config, win, { title = "yazi [⚓] " .. name })
			end
		end

		local function do_anchor()
			local yazi_id = vim.g.yazi_process_id
			if not yazi_id then
				logger:warn("yazi.nvim not ready")
				return
			end

			local tmpfile = vim.fn.stdpath("data") .. "/yazi-hover-tmp"
			logger:debug("emitting anchor command to yazi")

			vim.system({ "ya", "emit-to", yazi_id, "plugin", "anchor", tmpfile })

			vim.defer_fn(function()
				local f = io.open(tmpfile, "r")
				if not f then
					logger:warn("yazi plugin did not write hovered path (timeout)")
					return
				end

				local raw = f:read("*l")
				f:close()
				os.remove(tmpfile)
				if not raw or raw == "" then
					logger:warn("yazi plugin returned empty path")
					return
				end

				local path = raw
				if vim.fn.isdirectory(path) ~= 1 then
					path = vim.fs.dirname(path)
				end

				vim.fn.chdir(path)

				local name = vim.fn.fnamemodify(path, ":t")
				vim.g.anchor_path = { path = path, name = name }

				set_window_title(name)
				logger:warn('⚓ Anchored to "' .. name .. '"')

				require("heirline").statusline:broadcast(function(c)
					c._win_cache = nil
				end)
				vim.cmd("redrawstatus!")
			end, 50)
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "yazi",
			callback = function()
				if vim.g.anchor_path then
					set_window_title(vim.g.anchor_path.name)
				end

				local bufnr = vim.fn.bufnr()
				local keymaps = vim.api.nvim_buf_get_keymap(bufnr, "t")
				local existing
				for _, km in ipairs(keymaps) do
					if km.lhs == "<C-b>" then
						existing = km
						break
					end
				end

				if not existing then
					vim.keymap.set("t", "<C-b>", do_anchor, {
						buffer = bufnr,
						desc = "Anchor hovered yazi directory",
					})
				end
			end,
		})

		vim.api.nvim_create_user_command("Anchor", function(opts)
			local args = vim.split(opts.args or "", "%s+")
			local subcmd = args[1] or ""

			if subcmd == "clear" then
				vim.g.anchor_path = nil
				logger:warn("⚓ Anchor cleared")
				local win = vim.fn.bufwinid(vim.fn.bufnr())
				if win and win ~= -1 and vim.bo.filetype == "yazi" then
					pcall(vim.api.nvim_win_set_config, win, { title = "yazi" })
				end
				vim.cmd("redrawstatus!")
			elseif subcmd == "show" then
				if vim.g.anchor_path then
					logger:warn('⚓ Anchored to "' .. vim.g.anchor_path.path .. '"')
				else
					logger:warn("No anchor set")
				end
			end
		end, {
			nargs = "?",
			complete = function()
				return { "clear", "show" }
			end,
			desc = "Manage anchor: no args to toggle, clear to remove, show to display path",
		})
	end,
}
