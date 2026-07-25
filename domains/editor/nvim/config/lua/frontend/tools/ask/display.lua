local M = {}

local ns_id = vim.api.nvim_create_namespace("ask")
M.ns_id = ns_id

function M.get_indent(bufnr, linenr)
	local line = vim.api.nvim_buf_get_lines(bufnr, linenr, linenr + 1, false)[1]
	if not line then return "" end
	return line:match("^(%s*)") or ""
end

local function wrap_text(bufnr, linenr, text)
	local virt_lines = {}
	local max_width = math.max(20, vim.fn.winwidth(0) - 2)
	local trimmed = vim.trim(text)
	if trimmed == "" then
		return virt_lines
	end
	while #trimmed > max_width do
		table.insert(virt_lines, { { M.get_indent(bufnr, linenr) .. trimmed:sub(1, max_width), "Comment" } })
		trimmed = trimmed:sub(max_width + 1)
	end
	table.insert(virt_lines, { { M.get_indent(bufnr, linenr) .. trimmed, "Comment" } })
	return virt_lines
end

function M.show_response(bufnr, extmark_id, extmark_line, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local ok = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, ns_id, extmark_id, {})
	if not ok then
		return
	end

	local lines = vim.split(answer, "\n")
	local virt_lines = {}
	for _, line in ipairs(lines) do
		local wrapped = wrap_text(bufnr, extmark_line, line)
		for _, wl in ipairs(wrapped) do
			table.insert(virt_lines, wl)
		end
	end


	vim.api.nvim_buf_set_extmark(bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

function M.show_incomplete_line(bufnr, extmark_id, extmark_line, text)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local virt_lines = wrap_text(bufnr, extmark_line, text or "")
	table.insert(virt_lines, { { M.get_indent(bufnr, extmark_line) .. "...", "NonText" } })

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

function M.place_line_ref(bufnr, linenr, text)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local virt_lines = wrap_text(bufnr, linenr, text)
	if #virt_lines == 0 then
		return
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, linenr, 0, {
		virt_lines = virt_lines,
	})
end

function M.show_tool_actions(bufnr, extmark_id, extmark_line, actions)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	local indent = M.get_indent(bufnr, extmark_line)
	local virt_lines = {
		{ { indent .. "Thinking", "Comment" } },
	}
	for _, a in ipairs(actions) do
		virt_lines[#virt_lines + 1] = { { indent .. "  " .. a, "NonText" } }
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, extmark_line, 0, {
		id = extmark_id,
		virt_lines = virt_lines,
	})
end

function M.distribute_response(bufnr, extmark_id, start_0idx, end_0idx, answer)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)

	local lines = vim.split(answer, "\n")
	local max_width = math.max(20, vim.fn.winwidth(0) - 2)

	local function wrap_and_add(list, text)
		local trimmed = vim.trim(text)
		if trimmed == "" then
			return
		end
		while #trimmed > max_width do
			table.insert(list, trimmed:sub(1, max_width))
			trimmed = trimmed:sub(max_width + 1)
		end
		if #trimmed > 0 then
			table.insert(list, trimmed)
		end
	end

	local line_entries = {}
	local seq_lines = {}
	local has_refs = false
	local current_ref = nil

	for _, line in ipairs(lines) do
		local ref, rest = line:match("^L(%d+):%s*(.*)$")
		if ref then
			current_ref = tonumber(ref) - 1
			has_refs = true
			if not line_entries[current_ref] then
				line_entries[current_ref] = {}
			end
			wrap_and_add(line_entries[current_ref], rest)
		elseif has_refs then
			if current_ref then
				wrap_and_add(line_entries[current_ref], line)
			end
		else
			wrap_and_add(seq_lines, line)
		end
	end

	if has_refs then
		local chunks = {}
		for linenr, entry in pairs(line_entries) do
			if linenr >= start_0idx and linenr <= end_0idx and #entry > 0 then
				local chunk = {}
				for _, item in ipairs(entry) do
					table.insert(chunk, { { M.get_indent(bufnr, linenr) .. item, "Comment" } })
				end
				chunks[linenr] = chunk
			end
		end

		for linenr, chunk in pairs(chunks) do
			if #chunk > 0 then
				vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, 0, {
					virt_lines = chunk,
				})
			end
		end
		return
	end

	if #seq_lines == 0 then
		return
	end

	local num_source_lines = end_0idx - start_0idx + 1
	local lines_per_source = math.max(1, math.ceil(#seq_lines / num_source_lines))

	local chunks = {}
	local idx = 1
	for linenr = start_0idx, end_0idx do
		local chunk = {}
		for _ = 1, lines_per_source do
			if idx > #seq_lines then
				break
			end
			table.insert(chunk, { { M.get_indent(bufnr, linenr) .. seq_lines[idx], "Comment" } })
			idx = idx + 1
		end
		chunks[linenr] = chunk
	end

	for linenr, chunk in pairs(chunks) do
		if #chunk > 0 then
			vim.api.nvim_buf_set_extmark(bufnr, ns_id, linenr, 0, {
				virt_lines = chunk,
			})
		end
	end
end

function M.clear()
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

return M
