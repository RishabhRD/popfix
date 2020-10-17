local action = {}

local method = nil
local callbackList = nil
local selection = nil


local function free()
	method = nil
	callbackList = nil
	selection = nil
end

function action.register(callbacks, functionMethod)
	free()
	callbackList = callbacks
	method = functionMethod
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
	if method == 'line' then
		local tmp =  callbackList.select(line)
		return tmp
	elseif method == 'index' then
		return callbackList.select(index)
	end
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
	if method == 'line' then
		callbackList.close(line, selected)
	elseif method == 'index' then
		callbackList.close(index, selected)
	end
	free()
end

function action.getCurrentLine()
	if method == nil then return nil end
	return selection.line
end

function action.getCurrentIndex()
	if method == nil then return nil end
	return selection.index
end

function action.freed()
	return method == nil
end

return action
