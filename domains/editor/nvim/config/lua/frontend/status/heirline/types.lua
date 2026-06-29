---@meta

---@class HeirlineHighlight
---@field fg? string|function
---@field bg? string|function
---@field sp? string|function
---@field bold? boolean|function
---@field italic? boolean|function
---@field underline? boolean|function
---@field undercurl? boolean|function
---@field strikethrough? boolean|function
---@field reverse? boolean|function

---@class HeirlineOnClickOpts
---@field callback string|function
---@field name string|function
---@field update? boolean
---@field minwid? number|function

---@class HeirlineComponent
---@field provider? string|function
---@field condition? function
---@field init? function
---@field hl? string|HeirlineHighlight|function
---@field on_click? HeirlineOnClickOpts
---@field update? string[]|function
---@field fallthrough? boolean
---@field flexible? number
---@field static? table
---@field [integer] HeirlineComponent
