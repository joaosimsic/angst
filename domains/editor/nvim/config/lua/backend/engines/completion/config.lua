local logger = require("common.Logger")
local AdapterScanner = require("backend.shared.AdapterScanner")

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
		enabled = function()
			return vim.bo.buftype == "" and AdapterScanner:supports_filetype("lsp", vim.bo.filetype)
		end,

		keymap = {
			preset = "none",
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["Q"] = { "hide" },
			["<CR>"] = { "accept", "fallback" },

			["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },

			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
			["<Right>"] = { "accept", "fallback" },
			["<Left>"] = { "hide", "fallback" },

			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
		},

		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},

		sources = {
			default = { "lazydev", "lsp", "path", "snippets", "buffer" },
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
				},
			},
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
