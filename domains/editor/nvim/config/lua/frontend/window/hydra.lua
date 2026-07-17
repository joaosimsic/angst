---@type Hydra
local Hydra = require("common.Hydra")
---@type Logger
local Logger = require("common.Logger")
---@type table
local Resize = require("frontend.window.resize")

local palette = require("config.theme.palette")
local p, a = palette.p, palette.a

local M = {}

function M.setup()
	local logger = Logger.new("WINDOW:HYDRA")

	Hydra.new({
		name = "Window",
		fg_color = p.surface.base,
		bg_color = p.background.base,
		enter = "<leader>w",
		logger = logger,
		heads = {
			{
				"v",
				function()
					vim.cmd("vsplit")
				end,
				"Split vertical",
			},
			{
				"s",
				function()
					vim.cmd("split")
				end,
				"Split horizontal",
			},
			{
				"q",
				function()
					vim.cmd("close")
				end,
				"Close window",
			},
			{
				"h",
				function()
					Resize.resize(0, 5, "left")
				end,
				"Stretch left",
			},
			{
				"j",
				function()
					Resize.resize(0, 5, "down")
				end,
				"Stretch down",
			},
			{
				"k",
				function()
					Resize.resize(0, 5, "up")
				end,
				"Stretch up",
			},
			{
				"l",
				function()
					Resize.resize(0, 5, "right")
				end,
				"Stretch right",
			},
			{
				"=",
				function()
					vim.cmd("wincmd =")
				end,
				"Equalize",
			},
			{
				"H",
				function()
					vim.cmd("wincmd H")
				end,
				"Move far left",
			},
			{
				"J",
				function()
					vim.cmd("wincmd J")
				end,
				"Move far bottom",
			},
			{
				"K",
				function()
					vim.cmd("wincmd K")
				end,
				"Move far top",
			},
			{
				"L",
				function()
					vim.cmd("wincmd L")
				end,
				"Move far right",
			},
			{
				"o",
				function()
					vim.cmd("wincmd r")
				end,
				"Rotate windows",
			},
			{
				"x",
				function()
					vim.cmd("wincmd x")
				end,
				"Swap windows",
			},
		},
		exit_keys = { "<Esc>", "<C-c>" },
	})
end

return M
