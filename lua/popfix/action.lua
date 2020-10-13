local api = vim.api
local action = {}
local selection = {}
local callbackList = {}
local bufferProperty = {}

function action.registerCallbacks(buf, callbacks, info, metadata)
	callbackList[buf] = callbacks
	bufferProperty[buf] = {
		['info'] = info,
		['metadata'] = metadata,
	}
	selection[buf] = 0
end

function action.registerBuffer(buf, win)
	bufferProperty[buf]['win'] = win
end

local function unregisterBuffer(buf)
	bufferProperty[buf] = nil
	callbackList[buf] = nil
	selection[buf] = nil
end

function action.select(buf, index, line)
	selection[buf] = index
	if callbackList[buf] == nil then
		return
	end
	if callbackList[buf]['select'] == nil then
		return
	end
	if bufferProperty[buf]['method'] == 'line' then
		local data = api.nvim_buf_get_lines(buf, line - 1, line, false)
		callbackList['select'](buf, data)
	elseif bufferProperty[buf]['method'] == 'index' then
		callbackList['select'](buf, index)
	elseif bufferProperty['method'] == 'metadata' then
		callbackList['select'](buf, bufferProperty['metadata'][index])
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
		callbackList['close'](buf, data, selected)
	elseif bufferProperty[buf]['method'] == 'index' then
		callbackList['close'](buf, index, selected)
	elseif bufferProperty['method'] == 'metadata' then
		callbackList['close'](buf, bufferProperty['metadata'][index], selected)
	end
	unregisterBuffer(buf)
end


return action
