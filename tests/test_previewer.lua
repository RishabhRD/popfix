local M = {}
M.__index = M

function M:new()
	return setmetatable({}, self)
end

function M:writePreview(data)
	if self.closed then return end
	self.data = data
end

function M:close()
	self.data = nil
	self.closed = true
end

return M
