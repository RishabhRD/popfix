local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'

-- get floating window dimensions according to data to be displayed
--
-- param(data): list of string to be displayed in popup
local function getPopupWindowDimensions(data)
	local minWidth = 30
	local maxHeight = 10
	local maxWidth = 100

	local winHeight = #data
	if winHeight > maxHeight then
		winHeight = maxHeight
	end

	local winWidth = minWidth + 5
	for _,cur in pairs(data) do
		local curWidth = string.len(cur) + 5
		if curWidth > winWidth then
			winWidth = curWidth
		end
	end
	if winWidth > maxWidth then
		winWidth = maxWidth
	end

	local returnValue = {}
	returnValue[1] = winWidth
	returnValue[2] = winHeight
	return returnValue
end

-- open popup window with dimensions according to data
local function open_window(data)
	local buf = vim.api.nvim_create_buf(false, true)
	local dimensions = getPopupWindowDimensions(data)

	local opts = {
		style = "minimal",
		relative = "cursor",
		width = dimensions[1],
		height = dimensions[2],
		row = 1,
		col = 0
	}

	local win = vim.api.nvim_open_win(buf, true, opts)
	local ret = {}
	ret[1] = buf;
	ret[2] = win;
	return ret
end

-- set popup buffer property and keymaps
local function setBufferProperties(buf, key_maps)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	local autocmds = {}
	autocmds['CursorMoved'] = action.update_selection
	autocmds['BufWipeout'] = action.close_cancelled
	mappings.add_keymap(buf,key_maps)
	autocmd.addCommand(buf,autocmds)
end

-- set popup window properties
local function setWindowProperties(win)
	vim.api.nvim_win_set_option(win,'number',true)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

-- action public function to popup window
--
-- param(data): string list, to be displayed in popup window
--
-- param(key_maps): key_maps to map with popup buffer
--
-- param(init_handler): handler to be called when popup window initializes
--		prototype for init_handler:
--		init_handler = func(buf)
--		param(buf): popup_window buffer id
--
-- param(selection_handler): handler to be called when selection(current line)
--	changes
--		prototype for selection_handler:
--		selection_handler = func(buf, line)
--		param(buf): popup buffer id
--		param(line): current selected line
--
-- param(close_handler): handler to be called when popup window is destroyed
--		prototype for close_handler:
--		close_handler = func(buf, selected, line)
--		param(buf): pouup buffer id
--		param(selected): flag that last selection was accepted or cancelled
--
--
--	returns the buffer id of popup window
local function popup_window(data, key_maps, init_callback, select_callback,
		close_callback)
	if data == nil then
		print "nil data"
		return
	end
	local newWindow = open_window(data)
	setBufferProperties(newWindow[1], key_maps)
	setWindowProperties(newWindow[2])
	if init_callback ~= nil then
		action.register(newWindow[1], 'init', init_callback)
	end
	if select_callback ~= nil then
		action.register(newWindow[1], 'selection', select_callback)
	end
	if close_callback ~= nil then
		action.register(newWindow[1],'close' , close_callback)
	end
	action.init(newWindow[1],newWindow[2],data)
	return newWindow[1]
end

return{
	popup_window = popup_window
}
