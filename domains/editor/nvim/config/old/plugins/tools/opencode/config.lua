vim.g.opencode_opts = {
	default_global_keymaps = false,
	provider = {
		enabled = "snacks",
		snacks = {
			win = {
				position = "right",
				size = 0.3,
				border = "rounded",
			},
			args = {
				"--port",
				"auto",
			},
		},
	},
	events = {
		enabled = true,
		reload = false,
		permissions = {
			enabled = true,
			idle_delay_ms = 1500,
		},
	},
	ask = {
		prompt = "󰚩 Ask OpenCode: ",
		blink_cmp_sources = { "opencode", "buffer" },
		snacks = {
			icon = "󰚩 ",
			win = {
				title = " OpenCode ",
				title_pos = "center",
				relative = "cursor",
				row = -3,
				col = 0,
				border = "rounded",
				width = 80,
			},
			style = {
				backdrop = 60,
			},
		},
	},
}
