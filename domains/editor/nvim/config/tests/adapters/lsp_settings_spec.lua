local describe = rawget(_G, "describe")
local it = rawget(_G, "it")

local function bool_value(value, path, server_name)
	assert(
		type(value) == "boolean",
		string.format("LSP '%s' inlay hint setting '%s' must be boolean", server_name, path)
	)
end

local function enum_value(values)
	local allowed = {}
	for _, value in ipairs(values) do
		allowed[value] = true
	end

	return function(value, path, server_name)
		assert(
			allowed[value],
			string.format("LSP '%s' inlay hint setting '%s' must be one of %s", server_name, path, vim.inspect(values))
		)
	end
end

local function path_value(tbl, path)
	local value = tbl
	for segment in path:gmatch("[^.]+") do
		if type(value) ~= "table" then
			return nil
		end
		value = value[segment]
	end
	return value
end

local function is_inlay_hint_key(key)
	if type(key) ~= "string" then
		return false
	end

	return key == "hint"
		or key == "hints"
		or key == "inlayHint"
		or key == "inlayHints"
		or key == "inlay_hints"
		or key:find("inlay_hints", 1, true) ~= nil
end

local function collect_inlay_hint_leaves(value, prefix, inside_inlay_hint, leaves)
	if type(value) ~= "table" then
		return leaves
	end

	for key, child in pairs(value) do
		local path = prefix and (prefix .. "." .. key) or key
		local child_inside_inlay_hint = inside_inlay_hint or is_inlay_hint_key(key)

		if type(child) == "table" then
			collect_inlay_hint_leaves(child, path, child_inside_inlay_hint, leaves)
		elseif child_inside_inlay_hint then
			leaves[path] = child
		end
	end

	return leaves
end

local function inlay_hint_leaves(settings)
	return collect_inlay_hint_leaves(settings, nil, false, {})
end

local expected_inlay_hint_init_options = {
	phpactor = {
		["language_server_worse_reflection.inlay_hints.enable"] = bool_value,
		["language_server_worse_reflection.inlay_hints.params"] = bool_value,
		["language_server_worse_reflection.inlay_hints.types"] = bool_value,
	},
}

local expected_inlay_hint_settings = {
	angularls = {
		["angular.inlayHints.arrowFunctionParameterTypes"] = bool_value,
		["angular.inlayHints.arrowFunctionReturnTypes"] = bool_value,
		["angular.inlayHints.deferTriggerTypes"] = bool_value,
		["angular.inlayHints.eventParameterTypes"] = bool_value,
		["angular.inlayHints.forLoopVariableTypes"] = bool_value,
		["angular.inlayHints.hostListenerArgumentTypes"] = bool_value,
		["angular.inlayHints.ifAliasTypes"] = bool_value,
		["angular.inlayHints.letDeclarationTypes"] = bool_value,
		["angular.inlayHints.parameterNameHints"] = enum_value({ "none", "literals", "all" }),
		["angular.inlayHints.pipeOutputTypes"] = bool_value,
		["angular.inlayHints.propertyBindingTypes"] = bool_value,
		["angular.inlayHints.referenceVariableTypes"] = bool_value,
		["angular.inlayHints.requiredInputIndicator"] = enum_value({ "none", "asterisk", "exclamation" }),
		["angular.inlayHints.suppressWhenArgumentMatchesName"] = bool_value,
		["angular.inlayHints.suppressWhenTypeMatchesName"] = bool_value,
		["angular.inlayHints.switchExpressionTypes"] = bool_value,
		["angular.inlayHints.twoWayBindingSignalTypes"] = bool_value,
	},
	gopls = {
		["gopls.hints.assignVariableTypes"] = bool_value,
		["gopls.hints.compositeLiteralFields"] = bool_value,
		["gopls.hints.compositeLiteralTypes"] = bool_value,
		["gopls.hints.constantValues"] = bool_value,
		["gopls.hints.functionTypeParameters"] = bool_value,
		["gopls.hints.ignoredError"] = bool_value,
		["gopls.hints.parameterNames"] = bool_value,
		["gopls.hints.rangeVariableTypes"] = bool_value,
	},
	jdtls = {
		["java.inlayHints.parameterNames.enabled"] = enum_value({ "none", "literals", "all" }),
		["java.inlayHints.parameterTypes.enabled"] = bool_value,
		["java.inlayHints.variableTypes.enabled"] = bool_value,
	},
	lua_ls = {
		["Lua.hint.arrayIndex"] = enum_value({ "Auto", "Disable", "Enable" }),
		["Lua.hint.await"] = bool_value,
		["Lua.hint.enable"] = bool_value,
		["Lua.hint.paramName"] = enum_value({ "All", "Disable", "Literal" }),
		["Lua.hint.paramType"] = bool_value,
		["Lua.hint.semicolon"] = enum_value({ "All", "Disable", "SameLine" }),
		["Lua.hint.setType"] = bool_value,
	},
	rust_analyzer = {
		["rust-analyzer.inlayHints.chainingHints.enable"] = bool_value,
		["rust-analyzer.inlayHints.parameterHints.enable"] = bool_value,
		["rust-analyzer.inlayHints.typeHints.enable"] = bool_value,
	},
	ts_ls = {
		["javascript.inlayHints.includeInlayEnumMemberValueHints"] = bool_value,
		["javascript.inlayHints.includeInlayFunctionLikeReturnTypeHints"] = bool_value,
		["javascript.inlayHints.includeInlayFunctionParameterTypeHints"] = bool_value,
		["javascript.inlayHints.includeInlayParameterNameHints"] = enum_value({ "none", "literals", "all" }),
		["javascript.inlayHints.includeInlayParameterNameHintsWhenArgumentMatchesName"] = bool_value,
		["javascript.inlayHints.includeInlayPropertyDeclarationTypeHints"] = bool_value,
		["javascript.inlayHints.includeInlayVariableTypeHints"] = bool_value,
		["javascript.inlayHints.includeInlayVariableTypeHintsWhenTypeMatchesName"] = bool_value,
		["typescript.inlayHints.includeInlayEnumMemberValueHints"] = bool_value,
		["typescript.inlayHints.includeInlayFunctionLikeReturnTypeHints"] = bool_value,
		["typescript.inlayHints.includeInlayFunctionParameterTypeHints"] = bool_value,
		["typescript.inlayHints.includeInlayParameterNameHints"] = enum_value({ "none", "literals", "all" }),
		["typescript.inlayHints.includeInlayParameterNameHintsWhenArgumentMatchesName"] = bool_value,
		["typescript.inlayHints.includeInlayPropertyDeclarationTypeHints"] = bool_value,
		["typescript.inlayHints.includeInlayVariableTypeHints"] = bool_value,
		["typescript.inlayHints.includeInlayVariableTypeHintsWhenTypeMatchesName"] = bool_value,
	},
	volar = {
		["vue.inlayHints.destructuredProps"] = bool_value,
		["vue.inlayHints.inlineHandlerLeading"] = bool_value,
		["vue.inlayHints.missingProps"] = bool_value,
		["vue.inlayHints.optionsWrapper"] = bool_value,
		["vue.inlayHints.vBindShorthand"] = bool_value,
	},
}

return function(t)
	describe("LSP settings", function()
		it("should preserve exact settings for single-server adapters", function()
			local settings = {
				gopls = {
					hints = {
						parameterNames = true,
					},
				},
			}
			local adapter = {
				filetypes = { "go" },
				lsp = "gopls",
				lsp_settings = settings,
			}

			local info = t.AdapterTool.info(adapter, "lsp", "gopls")

			t.assert_same(settings, info.settings)
		end)

		it("should select per-server settings for multi-server adapters", function()
			local adapter = {
				filetypes = { "javascript", "typescript" },
				lsp = { "eslint", "ts_ls" },
				lsp_settings = {
					eslint = { workingDirectory = { mode = "auto" } },
					ts_ls = { typescript = { inlayHints = { includeInlayParameterNameHints = "all" } } },
				},
			}

			local eslint = t.AdapterTool.info(adapter, "lsp", "eslint")
			local ts_ls = t.AdapterTool.info(adapter, "lsp", "ts_ls")

			t.assert_same(adapter.lsp_settings.eslint, eslint.settings)
			t.assert_same(adapter.lsp_settings.ts_ls, ts_ls.settings)
		end)

		it("should pass exact inlay hint settings through adapter scanning", function()
			local lsp_servers = t.AdapterScanner:by_tool("lsp", { check_executable = false })

			t.assert_same(t.all_adapters.go.lsp_settings, lsp_servers.gopls.settings)
			t.assert_same(t.all_adapters.lua.lsp_settings, lsp_servers.lua_ls.settings)
		end)

		it("should only declare supported inlay hint settings", function()
			local lsp_servers = t.AdapterScanner:by_tool("lsp", { check_executable = false })

			for server_name, expected_settings in pairs(expected_inlay_hint_settings) do
				local server = lsp_servers[server_name]
				assert(server, string.format("LSP '%s' should be registered for inlay hints", server_name))
				assert(server.settings, string.format("LSP '%s' should declare inlay hint settings", server_name))

				for path, validate in pairs(expected_settings) do
					validate(path_value(server.settings, path), path, server_name)
				end
			end

			for server_name, expected_options in pairs(expected_inlay_hint_init_options) do
				local server = lsp_servers[server_name]
				assert(server, string.format("LSP '%s' should be registered for inlay hints", server_name))
				assert(
					server.init_options,
					string.format("LSP '%s' should declare inlay hint init_options", server_name)
				)

				for path, validate in pairs(expected_options) do
					validate(server.init_options[path], path, server_name)
				end
			end

			for server_name, server in pairs(lsp_servers) do
				local leaves =
					vim.tbl_extend("force", inlay_hint_leaves(server.settings), inlay_hint_leaves(server.init_options))
				local expected_settings = vim.tbl_extend(
					"force",
					expected_inlay_hint_settings[server_name] or {},
					expected_inlay_hint_init_options[server_name] or {}
				)

				for path, value in pairs(leaves) do
					assert(
						next(expected_settings) ~= nil,
						string.format("LSP '%s' declares unsupported inlay hint setting '%s'", server_name, path)
					)

					local validate = expected_settings[path]
					assert(
						validate,
						string.format("LSP '%s' declares unsupported inlay hint setting '%s'", server_name, path)
					)
					validate(value, path, server_name)
				end
			end
		end)
	end)
end
