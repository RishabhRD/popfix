local action = {}

local function free(self)
	self.method = nil
	self.callbackList = nil
	self.selection = nil
end

function action:register(callbacks, method)
	free(self)
	self.callbackList = callbacks
	self.method = method
	self.selection = {}
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
	if self.method == 'line' then
		return self.callbackList.select(line)
	elseif self.method == 'index' then
		return self.callbackList.select(index)
	end
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
	if self.method == 'line' then
		self.callbackList.close(line, selected)
	elseif self.method == 'index' then
		self.callbackList.close(index, selected)
	end
	free(self)
end

function action:getCurrentLine()
	if self.method == nil then return nil end
	return self.selection.line
end

function action:getCurrentIndex()
	if self.method == nil then return nil end
	return self.selection.index
end

function action:freed()
	return self.method == nil
end

return action
