local Keybinder = {}
Keybinder.__index = Keybinder

-- @param bufnr number|nil
-- @param signature string|nil
function Keybinder.new(bufnr, signature)
	local self = setmetatable({}, Keybinder)
	self.bufnr = bufnr
	self.signature = signature
	return self
end

function Keybinder:_bind(mode, lhs, rhs, desc)
	local opts = {
		remap = false,
		silent = true,
	}

	if desc and self.signature then
		opts.desc = string.format("[%s] %s", self.signature:upper(), desc)
	end

	if self.bufnr then
		opts.buffer = self.bufnr
	end

	if type(mode) == "table" then
		for _, m in ipairs(mode) do
			vim.keymap.set(m, lhs, rhs, opts)
		end
		return
	end

	vim.keymap.set(mode, lhs, rhs, opts)
end

function Keybinder:map(mode, lhs, rhs, desc)
	self:_bind(mode, lhs, rhs, desc)
end

function Keybinder:nmap(lhs, rhs, desc)
	self:_bind("n", lhs, rhs, desc)
end

function Keybinder:imap(lhs, rhs, desc)
	self:_bind("i", lhs, rhs, desc)
end

function Keybinder:vmap(lhs, rhs, desc)
	self:_bind("v", lhs, rhs, desc)
end

function Keybinder:tmap(lhs, rhs, desc)
	self:_bind("t", lhs, rhs, desc)
end
