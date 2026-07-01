--- @sync entry
--- @since 25.2.13
return {
	entry = function(_, job)
		local h = cx.active.current.hovered
		if not h then
			return
		end

		local f = io.open(job.args[1], "w")
		if f then
			f:write(tostring(h.url))
			f:close()
		end
	end,
}
