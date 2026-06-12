local manifest = require("config.manifest")
local selected_ai = manifest.tools.ai

local ai_keymaps = {
	opencode = "config.keymaps.ai.opencode",
	copilot = "config.keymaps.ai.copilot",
	cursor = "config.keymaps.ai.cursor",
}

local keymap_path = ai_keymaps[selected_ai]

if keymap_path then
	return require(keymap_path)
end

return {}
