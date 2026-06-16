---@class Spec
local Spec = {}

---@param value any
---@return boolean
function Spec.is_plugin_spec(value)
	return type(value) == "table" and (type(value[1]) == "string" or type(value.dir) == "string")
end

---@param source any
---@param target? table
---@return table
function Spec.collect(source, target)
	target = target or {}

	if type(source) ~= "table" then
		return target
	end

	if Spec.is_plugin_spec(source) then
		table.insert(target, source)
		return target
	end

	if type(source.spec) == "table" then
		Spec.collect(source.spec, target)
	end

	for _, spec in ipairs(source) do
		Spec.collect(spec, target)
	end

	return target
end

---@param sources table[]
---@return table
function Spec.merge(sources)
	local target = {}

	for _, source in ipairs(sources) do
		Spec.collect(source, target)
	end

	return target
end

return Spec
