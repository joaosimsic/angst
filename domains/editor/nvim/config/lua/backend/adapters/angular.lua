---@type Adapter
return {
	filetypes = { "htmlangular", "angular" },
	lsp = "angularls",
	lsp_cmd = function()
		local ngserver = vim.fn.exepath("ngserver")
		if ngserver == "" then
			return {}
		end
		local probe_locations = vim.fs.dirname(ngserver)
		return {
			"ngserver",
			"--stdio",
			"--tsProbeLocations",
			probe_locations,
			"--ngProbeLocations",
			probe_locations,
		}
	end,
	lsp_settings = {
		angular = {
			inlayHints = {
				arrowFunctionParameterTypes = true,
				arrowFunctionReturnTypes = true,
				deferTriggerTypes = true,
				eventParameterTypes = true,
				forLoopVariableTypes = true,
				hostListenerArgumentTypes = true,
				ifAliasTypes = true,
				letDeclarationTypes = true,
				parameterNameHints = "all",
				pipeOutputTypes = true,
				propertyBindingTypes = true,
				referenceVariableTypes = true,
				requiredInputIndicator = "asterisk",
				suppressWhenArgumentMatchesName = false,
				suppressWhenTypeMatchesName = false,
				switchExpressionTypes = true,
				twoWayBindingSignalTypes = true,
			},
		},
	},
}
