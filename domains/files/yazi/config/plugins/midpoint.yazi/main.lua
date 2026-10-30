--- @sync entry
return {
	entry = function()
		local folder = cx.active.current
		local total = #folder.files
		if total == 0 then
			return
		end

		local target = math.floor((total - 1) / 2)
		local delta = target - folder.cursor
		if delta ~= 0 then
			ya.emit("arrow", { delta })
		end
	end,
}
