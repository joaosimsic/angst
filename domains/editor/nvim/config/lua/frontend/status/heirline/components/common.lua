local M = {}

---@type HeirlineComponent
M.Align = { provider = "%=" }

---@type HeirlineComponent
M.Space = { provider = " " }

---@type HeirlineComponent
M.Ruler = {
	provider = " %l:%c | %P ",
	hl = "HeirlinePosition",
}

return M
