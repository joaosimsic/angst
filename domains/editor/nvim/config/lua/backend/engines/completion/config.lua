local logger = require("common.Logger")

local M = {}

function M.capabilities()
	local ok, blink = pcall(require, "blink.cmp")
	if not ok then
		return vim.lsp.protocol.make_client_capabilities()
	end
	return blink.get_lsp_capabilities()
end

function M.setup()
	local ok, blink = pcall(require, "blink.cmp")

	if not ok then
		logger:error(function()
			return "Failed to require blink-cmp."
		end)
		return
	end

	blink.setup({
		keymap = {
			preset = "none",
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide" },
			["<CR>"] = { "accept", "fallback" },

			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
		},

		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},

		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
		},

		completion = {
			menu = { draw = { treesitter = { "lsp" } } },
			ghost_text = { enabled = true },
		},

		signature = { window = { border = "single" } },

		fuzzy = { implementation = "prefer_rust_with_warning" },
	})
end

return M
