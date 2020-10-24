local action = {}

local callbackList = nil
local selection = nil


local function free()
	callbackList = nil
	selection = nil
end

function action.register(callbacks)
	free()
	callbackList = callbacks
	selection = {}
end


function action.select(index, line)
	selection.index = index
	selection.line = line

	if callbackList == nil then
		return
	end
	if callbackList.select == nil then
		return
	end
	return callbackList.select(index, line)
end

function action.close(index, line, selected)
	if callbackList == nil then
		free()
		return
	end
	if callbackList.close == nil then
		free()
		return
	end
	callbackList.close(index, line, selected)
	free()
end

function action.getCurrentLine()
	return selection.line
end

function action.getCurrentIndex()
	return selection.index
end

function action.freed()
	return selection == nil
end

return action
