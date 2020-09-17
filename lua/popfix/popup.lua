local action = require'popfix.action'
local mappings = require'popfix.mappings'

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

local function setBufferProperties(buf,data)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	local key_maps = {
		n = {
			['<CR>'] = action.close_selected,
			['<ESC>'] = action.close_cancelled,
			['<C-n>'] = action.next_select,
			['<C-p>'] = action.prev_select,
			['<C-j>'] = action.next_select,
			['<C-k>'] = action.prev_select,
			['<DOWN>'] = action.next_select,
			['<UP>'] = action.prev_select,
		}
	}
	local autocmds = {}
	autocmds['CursorMoved'] = action.update_selection
	mappings.add_keymap(buf,key_maps)
	vim.api.nvim_buf_set_lines(buf,0,-1,false,data)
	vim.api.nvim_buf_set_option(buf, 'modifiable',false)
end

local function setWindowProperties(win)
	vim.api.nvim_win_set_option(win,'number',true)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

local function popup_window(data,callback)
	local newWindow = open_window(data)
	action.init(newWindow[1],newWindow[2])
	setBufferProperties(newWindow[1],data)
	setWindowProperties(newWindow[2])
	action.register(newWindow[1],'close_selected' ,callback)
	action.register(newWindow[1],'close_cancelled' ,callback)
	return newWindow[1]
end

return{
	popup_window = popup_window
}
