local LspTool = require("backend.shared.LspTool")

local root_markers = { "deps.edn", "project.clj", "shadow-cljs.edn", ".git" }

---@type Adapter
return {
	filetypes = { "clojure" },
	lsp = "clojure_lsp",
	lsp_cmd = { "clojure-lsp" },
	lsp_root_markers = root_markers,
	lsp_root_dir = LspTool.make_root_dir_finder(root_markers),
	formatter = "cljfmt",
	linter = "clj-kondo",
	linter_cmd = { "clj-kondo" },
	treesitter = "clojure",
	compiler = "clojure",
	compiler_cmd = { "clojure", "-M", "$FILE" },
}
