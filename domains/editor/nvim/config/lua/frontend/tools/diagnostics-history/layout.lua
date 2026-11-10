local M = {}

local function basename(path)
	return vim.fn.fnamemodify(path, ":t")
end

local function dirname(path)
	return vim.fn.fnamemodify(path, ":h")
end

local function relpath(abs, root)
	if root == nil or root == "" then
		return abs
	end
	if abs == root then
		return basename(abs)
	end
	if abs:sub(1, #root) == root and abs:sub(#root + 1, #root + 1) == "/" then
		return abs:sub(#root + 2)
	end
	return abs
end

local function item_less(a, b)
	if a.lnum ~= b.lnum then
		return a.lnum < b.lnum
	end
	if a.col ~= b.col then
		return a.col < b.col
	end
	if a.severity ~= b.severity then
		return a.severity < b.severity
	end
	return (a.message or "") < (b.message or "")
end

local function file_less(a, b)
	if a.rel == b.rel then
		return a.filename < b.filename
	end
	return a.rel < b.rel
end

---@param items table[]
---@param current_bufnr? integer
---@param cwd? string
---@return table[]
function M.build(items, current_bufnr, cwd)
	cwd = cwd or vim.fn.getcwd()

	local files = {}
	local file_order = {}
	for _, item in ipairs(items or {}) do
		local file = files[item.bufnr]
		if file == nil then
			local filename = vim.api.nvim_buf_get_name(item.bufnr)
			local abs = filename == "" and "" or vim.fn.fnamemodify(filename, ":p")
			file = { bufnr = item.bufnr, filename = abs, rel = relpath(abs, cwd), items = {} }
			files[item.bufnr] = file
			file_order[#file_order + 1] = file
		end
		file.items[#file.items + 1] = item
	end
	for _, file in ipairs(file_order) do
		table.sort(file.items, item_less)
	end

	local function append_file(rows, file, indent, group)
		rows[#rows + 1] = {
			kind = "file",
			bufnr = file.bufnr,
			filename = file.filename,
			label = file.label or basename(file.rel),
			indent = indent,
			group = group,
		}
		local current_line = nil
		for _, item in ipairs(file.items) do
			if item.lnum ~= current_line then
				current_line = item.lnum
				rows[#rows + 1] = {
					kind = "line",
					lnum = item.lnum,
					label = tostring(item.lnum + 1),
					indent = indent + 1,
					group = group,
				}
			end
			rows[#rows + 1] = {
				kind = "diagnostic",
				item = item,
				indent = indent + 2,
				group = group,
			}
		end
	end

	local rows = {}
	local current_file = files[current_bufnr]
	if current_file ~= nil then
		current_file.label = current_file.rel
		rows[#rows + 1] = { kind = "separator", label = "CURRENT" }
		append_file(rows, current_file, 0, nil)
		if #file_order > 1 then
			rows[#rows + 1] = { kind = "blank" }
		end
	end

	local root, loose, grouped, group_order = {}, {}, {}, {}
	for _, file in ipairs(file_order) do
		if file ~= current_file then
			local inside = file.rel ~= file.filename
			local dir = inside and dirname(file.rel) or nil
			if inside and dir == "." then
				root[#root + 1] = file
			elseif inside then
				local group = grouped[dir]
				if group == nil then
					group = { dir = dir, files = {} }
					grouped[dir] = group
					group_order[#group_order + 1] = dir
				end
				group.files[#group.files + 1] = file
			else
				loose[#loose + 1] = file
			end
		end
	end
	table.sort(root, file_less)

	local units = {}
	for _, dir in ipairs(group_order) do
		local group = grouped[dir]
		if #group.files >= 2 then
			table.sort(group.files, file_less)
			units[#units + 1] = { kind = "folder", dir = dir, files = group.files, key = dir }
		else
			local file = group.files[1]
			units[#units + 1] = { kind = "file", file = file, key = file.rel }
		end
	end
	for _, file in ipairs(loose) do
		units[#units + 1] = { kind = "file", file = file, key = file.rel }
	end
	table.sort(units, function(a, b)
		if a.key == b.key then
			return (a.kind or "") < (b.kind or "")
		end
		return a.key < b.key
	end)

	for _, file in ipairs(root) do
		file.label = basename(file.rel)
		append_file(rows, file, 0, nil)
	end
	for _, unit in ipairs(units) do
		if unit.kind == "folder" then
			rows[#rows + 1] = { kind = "folder", name = basename(unit.dir), dir = unit.dir }
			for _, file in ipairs(unit.files) do
				file.label = basename(file.rel)
				append_file(rows, file, 1, unit.dir)
			end
		else
			local file = unit.file
			file.label = file.rel
			append_file(rows, file, 0, nil)
		end
	end

	return rows
end

return M
