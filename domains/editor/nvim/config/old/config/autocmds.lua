vim.api.nvim_create_autocmd("FileType", {
	pattern = "blade",
	callback = function()
		vim.cmd("syntax include @php syntax/php.vim")
		vim.cmd('syntax region phpCode start="@php" end="@endphp" contains=@php')
	end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = "*.java",
	callback = function()
		vim.fn.jobstart("./mvnw compile", { detach = true })
	end,
})

vim.o.autoread = true

vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
	callback = function()
		if vim.bo.buftype == "terminal" then
			return
		end
		if vim.fn.mode() ~= "c" then
			vim.cmd("checktime")
		end
	end,
	pattern = { "*" },
})

vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		if vim.bo.buftype == "" then
			vim.cmd("normal! zz")
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		vim.opt_local.conceallevel = 2
		vim.opt_local.concealcursor = "nc"
	end,
})


