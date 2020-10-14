local api = vim.api
local action = {}
local selection = {}
local callbackList = {}
local bufferProperty = {}

function action.registerCallbacks(buf, callbacks, info)
	callbackList[buf] = callbacks
	bufferProperty[buf]['method'] = info.method
end

function action.registerBuffer(buf, win)
	bufferProperty[buf] = {}
	selection[buf] = {}
	callbackList[buf] = {}
	bufferProperty[buf]['win'] = win
end

local function unregisterBuffer(buf)
	bufferProperty[buf] = nil
	callbackList[buf] = nil
	selection[buf] = nil
end

function action.select(buf, index, line)
	selection[buf]['index'] = index
	selection[buf]['line'] = line
	if callbackList[buf] == nil then
		return
	end
	if callbackList[buf]['select'] == nil then
		return
	end
	if bufferProperty[buf]['method'] == 'line' then
		local data = api.nvim_buf_get_lines(buf, line - 1, line , false)
		callbackList[buf]['select'](buf, data[1])
	elseif bufferProperty[buf]['method'] == 'index' then
		callbackList[buf]['select'](buf, index)
	end
end

function action.close(buf, index, line, selected)
	if callbackList[buf] == nil then
		unregisterBuffer(buf)
		return
	end
	if callbackList[buf]['close'] == nil then
		unregisterBuffer(buf)
		return
	end
	if bufferProperty[buf]['method'] == 'line' then
		local data = api.nvim_buf_get_lines(buf, line - 1, line, false)
		callbackList[buf]['close'](buf, data[1], selected)
	elseif bufferProperty[buf]['method'] == 'index' then
		callbackList[buf]['close'](buf, index, selected)
	end
	unregisterBuffer(buf)
end

function action.getCurrentLine(buf)
	if bufferProperty[buf] == nil then return nil end
	return selection[buf]['line']
end

function action.getCurrentIndex(buf)
	if bufferProperty[buf] == nil then return nil end
	return selection[buf]['index']
end

function action.getAssociatedWindow(buf)
	if bufferProperty[buf] == nil then return nil end
	return bufferProperty[buf]['win']
end

return action
