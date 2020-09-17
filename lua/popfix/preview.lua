local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'

local preview_map = {}


local function preview(buf, preview_data)
	vim.api.nvim_buf_set_lines(preview_map[buf].buf, 0, -1, false,
		preview_data.data)
	if preview_data.line ~= nil then
		-- TODO highlighting
		vim.api.nvim_buf_add_highlight(preview_map[buf].buf, -1, "Visual",
			preview_data.line, 0, -1)
	end
end

local function getWindow()
	local buf, win
	vim.api.nvim_command('bot new')
	win = vim.api.nvim_get_current_win()
	buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf,'Preview #' .. buf)
	vim.api.nvim_win_set_height(win,12)
	return { buf = buf, win = win}
end

local function getPreview(win)
	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)

	local win_height =  height
	local win_width = math.ceil(width*0.5)

	local row = 0
	local col = win_width

	local opts = {
		style = "minimal",
		relative = "win",
		width = win_width,
		height = win_height,
		row  = row,
		col = col
	}

	local buf = vim.api.nvim_create_buf(false,true)
	local win_newWin = vim.api.nvim_open_win(buf,false,opts)
	return { buf = buf, win = win_newWin}
end

local function setBufferProperty(buf, key_maps)
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	local autocmds = {
		['CursorMoved'] = action.update_selection,
		['BufWipeout'] = action.close_cancelled
	}
	mappings.add_keymap(buf,key_maps)
	autocmd.addCommand(buf,autocmds)
end

local function setWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
	vim.api.nvim_win_set_option(win, 'number', false)
	vim.api.nvim_win_set_option(win, 'relativenumber', false)
end

local function setPreviewBufferProperty(buf)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
end

local function setPreviewWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', false)
	vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')
	vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
	vim.api.nvim_win_set_option(win, 'foldlevel', 100)
end

local function init(buf)
	local func = preview_map[buf].init_handler
	if func == nil then
		return
	end
	local preview_data = func(buf)
	if preview_data ~= nil then
		if preview_data.data == nil or vim.tbl_isempty(preview_data.data) then
			return
		end
		preview(buf, preview_data)
	end
end

local function select(buf, index)
	local func = preview_map[buf].selection_handler
	if func == nil then
		return
	end
	local preview_data = func(buf,index)
	if preview_data ~= nil then
		if preview_data.data == nil or vim.tbl_isempty(preview_data.data) then
			return
		end
		preview(buf, preview_data)
	end
end

local function close(buf, selected, line)
	if preview_map[buf] == nil then
		return
	end
	local func = preview_map[buf].close_handler
	if func ~= nil then
		func(buf,selected,line)
	end
	local preview_win = preview_map[buf].win
	if preview_win == nil then
		preview_map[buf] = nil
		return
	end
	vim.api.nvim_win_close(preview_win,true)
	preview_map[buf] = nil
end


local function popup_preview(data, key_maps, init_handler, selection_handler,
		close_handler)
	local newWindow = getWindow()
	local popup_buf = newWindow.buf
	local popup_win = newWindow.win
	local previewWindow = getPreview(popup_win)
	local preview_win = previewWindow.win
	local preview_buf = previewWindow.buf
	preview_map[popup_buf] = {}
	preview_map[popup_buf].win = preview_win
	preview_map[popup_buf].buf = preview_buf
	preview_map[popup_buf].init_handler = init_handler
	preview_map[popup_buf].selection_handler = selection_handler
	preview_map[popup_buf].close_handler = close_handler
	action.register(popup_buf, 'init', init)
	action.register(popup_buf, 'selection', select)
	action.register(popup_buf, 'close', close)
	action.init(popup_buf, popup_win, data)
	setBufferProperty(popup_buf, key_maps)
	setWindowProperty(popup_win)
	setPreviewWindowProperty(preview_win)
	setPreviewBufferProperty(preview_buf)
	return popup_buf
end

return{
	popup_preview = popup_preview
}
