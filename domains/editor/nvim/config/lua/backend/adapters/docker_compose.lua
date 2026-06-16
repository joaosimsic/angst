---@type Adapter
return {
	filetypes = { "yaml.docker-compose" },
	lsp = "docker_compose_language_service",
	lsp_cmd = { "docker-compose-langserver", "--stdio" },
}
