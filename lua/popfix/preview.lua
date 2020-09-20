local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'

-- table to store information about currently displaying preview windows
local preview_map = {}

-- preview the given preview_data to preview buffer associated with buf
--
-- param(buf) - popup menu buffer
-- param(preview_data) - { data, line}
--
-- 	data - list of string
-- 	line - line number to highlight
-- 	(no highlight if line = nil)

local function preview(buf, preview_data)
	vim.api.nvim_buf_set_lines(preview_map[buf].buf, 0, -1, false,
		preview_data.data)
	if preview_data.line ~= nil then
		-- TODO highlighting
		vim.api.nvim_buf_add_highlight(preview_map[buf].buf, -1, "Visual",
			preview_data.line, 0, -1)
	end
end


-- creates a new window in down split
--
-- returns a (buf,win) pair
-- buf: buffer id of new window's buffer
-- win: window id of new window
local function getWindow()
	local buf, win
	vim.api.nvim_command('bot new')
	win = vim.api.nvim_get_current_win()
	buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf,'Preview #' .. buf)
	vim.api.nvim_win_set_height(win,12)
	return { buf = buf, win = win}
end

-- creates a new floating preview window
--
-- param(win): window id of popup window
--
-- returns (buf,win) pair
-- buf: buffer id of new preview window's buffer
-- win: window if of new preview window
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

-- sets some default property for popup buffer
-- and associate given keymap provided to buffer
--
-- param(buf): popup buffer id
-- param(key_maps): keymaps provided
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

-- sets some default property for popup window
--
-- param(win): popup window id
local function setWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
	vim.api.nvim_win_set_option(win, 'number', false)
	vim.api.nvim_win_set_option(win, 'relativenumber', false)
end

-- sets some default property for preview buffer
--
-- param(buf): preview buffer id
local function setPreviewBufferProperty(buf)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
end

-- sets some default property for preview window
--
-- param(win): preview window id
local function setPreviewWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', false)
	vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')
	vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
	vim.api.nvim_win_set_option(win, 'foldlevel', 100)
end

-- init callback for popup buffer
--
-- param(buf): buffer id of popup buffer
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

-- select callback for popup buffer
--
-- param(buf): buffer id of popup window
-- param(index): line number on which currently cursor is
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

-- close callback for popup buffer
--
-- param(buf): buffer id of popup window
-- param(selected): window was closed as selected or cancelled
-- param(line): line number on which cursor was
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


-- function that has public access to open preview window
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
--	Every handler should return a (data, line) pair
--	data: data to be shown in preview window (no preview if nil)
--	line: line number to be highlighted (no highlight if nil)
--
-- if any handler is passed null, it would be just simply ignored. So,
-- if you don't want to handle a specific event just pass null to it
--
--	returns the buffer id of popup window
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
