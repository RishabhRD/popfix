local action = {}

local function free(self)
	self.selection = nil
end

function action:new()
	local obj = {
		selection = {}
	}
	setmetatable(obj, self)
	return obj
end

function action:select(index, line, callback)
	if not self.selection then return end
	self.selection.index = index
	self.selection.line = line
	if callback then
		return callback(index, line)
	end
end

function action:close(index, line, selected, callback)
	if callback then
		callback(index, line, selected)
	end
	free(self)
end

function action:getCurrentLine()
	return self.selection.line
end

function action:getCurrentIndex()
	return self.selection.index
end

return action
