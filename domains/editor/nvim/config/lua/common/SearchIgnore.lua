local M = {}

M.ignored_dirs = {
	".git",
	".hg",
	".svn",
	".cache",
	".dart_tool",
	".gradle",
	".mypy_cache",
	".next",
	".nuxt",
	".pnpm-store",
	".pytest_cache",
	".svelte-kit",
	".tox",
	".turbo",
	".venv",
	".yarn",
	"Pods",
	"__pycache__",
	"_build",
	"build",
	"coverage",
	"deps",
	"dist",
	"node_modules",
	"out",
	"result",
	"target",
	"vendor",
	"venv",
}

M.ignored_file_patterns = {
	"%.lock$",
	"%.min%.js$",
	"%.min%.css$",
}

M.ignored_file_globs = {
	"**/*.lock",
	"**/*.min.js",
	"**/*.min.css",
}

function M.fzf_ignore_patterns()
	local patterns = {}

	for _, dir in ipairs(M.ignored_dirs) do
		patterns[#patterns + 1] = vim.pesc(dir) .. "/"
	end

	for _, pattern in ipairs(M.ignored_file_patterns) do
		patterns[#patterns + 1] = pattern
	end

	return patterns
end

function M.rg_ignore_globs()
	local globs = {}

	for _, dir in ipairs(M.ignored_dirs) do
		globs[#globs + 1] = "!**/" .. dir .. "/**"
	end

	for _, glob in ipairs(M.ignored_file_globs) do
		globs[#globs + 1] = "!" .. glob
	end

	return globs
end

function M.rg_args()
	local args = {}

	for _, glob in ipairs(M.rg_ignore_globs()) do
		args[#args + 1] = "--glob"
		args[#args + 1] = glob
	end

	return args
end

function M.rg_opts()
	local opts = {
		"--column",
		"--line-number",
		"--no-heading",
		"--color=always",
		"--smart-case",
		"--max-columns=4096",
		"--hidden",
	}

	for _, glob in ipairs(M.rg_ignore_globs()) do
		opts[#opts + 1] = "--glob=" .. glob
	end

	return table.concat(opts, " ")
end

function M.is_ignored(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local normalized = vim.fs.normalize(path)

	for _, dir in ipairs(M.ignored_dirs) do
		local escaped = vim.pesc(dir)
		if
			normalized:find("/" .. escaped .. "/")
			or normalized:find("/" .. escaped .. "$")
			or normalized:find("^" .. escaped .. "/")
		then
			return true
		end
	end

	for _, pattern in ipairs(M.ignored_file_patterns) do
		if normalized:match(pattern) then
			return true
		end
	end

	return false
end

return M
