local api = vim.api

local bufferCallbacks = {}

local map = function(buf,type, key, value)
	vim.fn.nvim_buf_set_keymap(buf,type,key,value,{noremap = true, silent = true});
end

local function close_event(buf,selected)
	if selected then
		local callback = bufferCallbacks[buf]
		callback(vim.api.nvim_win_get_cursor(0)[1])
	end
	bufferCallbacks[buf] = nil
	vim.api.nvim_win_close(0,true)
end

local function getPopupWindowDimensions(data)
	local minWidth = 30
	local maxHeight = 10
	local maxWidth = 60

	local winHeight = #data + 1
	if winHeight > maxHeight then
		winHeight = maxHeight
	end

	local winWidth = minWidth
	for _,cur in pairs(data) do
		local curWidth = string.len(cur)
		if curWidth > winWidth then
			winWidth = curWidth
		end
	end
	if winWidth > maxWidth then
		winWidth = maxWidth
	end

	local cursorPos = vim.api.nvim_win_get_cursor(0)
	local returnValue = {}
	returnValue[1] = winWidth
	returnValue[2] = winHeight
	-- TODO position should take care of window height and width
	returnValue[3] = cursorPos[1]
	returnValue[4] = cursorPos[2]
	return returnValue
end

local function open_window(data)
	local buf = api.nvim_create_buf(false, true)
	local dimensions = getPopupWindowDimensions(data)

	local opts = {
		style = "minimal",
		relative = "cursor",
		width = dimensions[1],
		height = dimensions[2],
		row = 0,
		col = 0
	}

	local win = api.nvim_open_win(buf, true, opts)
	local ret = {}
	ret[1] = buf;
	ret[2] = win;
	return ret
end

local function setBufferProperties(buf,data)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	map(buf,'n','<CR>','<cmd>lua require\'popfix\'.close_event(' .. buf ..',true)<CR>')
	map(buf,'n','<ESC>','<cmd>lua require\'popfix\'.close_event(' .. buf ..',false)<CR>')
	map(buf,'n','<C-n>','j')
	map(buf,'n','<C-p>','k')
	map(buf,'n','<C-j>','j')
	map(buf,'n','<C-k>','k')
	api.nvim_buf_set_lines(buf,0,-1,false,data)
	api.nvim_buf_set_option(buf, 'modifiable',false)
end

local function setWindowProperties(win)
	vim.api.nvim_win_set_option(win,'number',true)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

local function popup_window(data,callback)
	local newWindow = open_window(data)
	setBufferProperties(newWindow[1],data)
	setWindowProperties(newWindow[2])
	bufferCallbacks[newWindow[1]] = callback
end

return{
	popup_window = popup_window,
	close_event = close_event
}
