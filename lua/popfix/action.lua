local action = {}

local function free(self)
	self.callbackList = nil
	self.selection = nil
end

function action:register(callbacks)
	local obj = {
		callbackList = callbacks,
		selection = {}
	}
	self.__index = self
	setmetatable(obj, self)
	return obj
end

function action:select(index, line)
	self.selection.index = index
	self.selection.line = line

	if self.callbackList == nil then
		return
	end
	if self.callbackList.select == nil then
		return
	end
	return self.callbackList.select(index, line)
end

function action:close(index, line, selected)
	if self.callbackList == nil then
		free(self)
		return
	end
	if self.callbackList.close == nil then
		free(self)
		return
	end
	self.callbackList.close(index, line, selected)
	free(self)
end

function action:getCurrentLine()
	return self.selection.line
end

function action:getCurrentIndex()
	return self.selection.index
end

function action:freed()
	return self.selection == nil
end

return action
