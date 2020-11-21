local M = {}
M.__index = M


-- @class ListManager manages list UI and selection on various
-- events
function M:new(opts)
	local obj = {
		list = opts.list
	}
	setmetatable(obj, self)
	return obj
end

function M:add(line, starting, ending)
	if ((not starting) or (not ending)) then
		self.list:appendLine(line)
		return
	end
	self.list:addLine(line, starting, ending)
end


return M
