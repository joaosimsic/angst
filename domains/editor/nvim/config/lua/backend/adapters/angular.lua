---@type Adapter
return {
	filetypes = { "htmlangular", "angular" },
	lsp = "angularls",
	lsp_cmd = function()
		local ngserver = vim.fn.exepath("ngserver")
		if ngserver == "" then
			return nil
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
}
