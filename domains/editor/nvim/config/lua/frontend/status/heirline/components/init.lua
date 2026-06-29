local common = require("frontend.status.heirline.components.common")
local mode = require("frontend.status.heirline.components.mode")
local file = require("frontend.status.heirline.components.file")
local git = require("frontend.status.heirline.components.git")
local diagnostic = require("frontend.status.heirline.components.diagnostic")
local lsp = require("frontend.status.heirline.components.lsp")
local hydra = require("frontend.status.heirline.components.hydra")

---@type table<string, HeirlineComponent>
local M = vim.tbl_deep_extend("force", {}, common, mode, file, git, diagnostic, lsp, hydra)

return M
