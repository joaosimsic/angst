local LspTool = require("backend.shared.LspTool")

local root_markers = { "flake.nix", ".git" }

---@type Adapter
return {
	filetypes = { "nix" },
	lsp = { "nil_ls", "nixd" },
	lsp_cmd = {
		nil_ls = { "nil" },
		nixd = { "nixd" },
	},
	lsp_root_markers = {
		nil_ls = root_markers,
		nixd = root_markers,
	},
	lsp_root_dir = {
		nil_ls = LspTool.make_root_dir_finder(root_markers),
		nixd = LspTool.make_root_dir_finder(root_markers),
	},
	lsp_settings = {
		nil_ls = {
			["nil"] = {
				nix = {
					flake = {
						autoEvalInputs = false,
					},
				},
			},
		},
		nixd = {
			nixd = {
				nixpkgs = {
					expr = "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }",
				},
				formatting = { command = { "nixfmt" } },
				options = {
					nixos = {
						expr = "(builtins.getFlake (toString ./.)).nixosConfigurations.nixos.options",
					},
					["home-manager"] = {
						expr = "(builtins.getFlake (toString ./.)).homeConfigurations.nixos.options",
					},
				},
			},
		},
	},
	formatter = "nixfmt",
	linter = { "statix", "deadnix" },
	treesitter = "nix",
	compiler = "nix",
	compiler_cmd = { "nix", "eval", "--file", "$FILE" },
}
