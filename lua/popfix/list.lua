local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local api = vim.api

local localBuffer = nil
local localWindow = nil
local exportedFunction = nil

local M = {}

local function close_selected()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, true)
	api.nvim_win_close(localWindow, true)
	localBuffer = nil
	localWindow = nil
	exportedFunction = nil
end

local function close_cancelled()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, false)
	api.nvim_win_close(localWindow, true)
	localBuffer = nil
	localWindow = nil
	exportedFunction = nil
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = api.nvim_win_get_cursor(localWindow)[1]
	if oldIndex ~= line then
		action.select(line, api.nvim_buf_get_lines(localBuffer, line - 1, line, false)[1])
	end
end

local function popup_split(height, title)
	height = height or 12
	api.nvim_command('bot new')
	local win = api.nvim_get_current_win()
	local buf = api.nvim_get_current_buf()
	title = title or ''
	api.nvim_buf_set_name(buf, 'PopList #'..buf..title)
	api.nvim_win_set_height(win, height)
	localBuffer = buf
	localWindow = win
end

local function popup_cursor(height, title, border, data)
	local width = 40
	if not data then
		width = width or 40
		height = height or data
	else
		local maxWidth = 0
		for _,cur in pairs(data) do
			local curWidth = string.len(cur) + 5
			if curWidth > maxWidth then
				maxWidth = curWidth
			end
		end
		width = maxWidth
		if height == nil then
			height = height or #data
		end
	end
	local opts = {
		relative = "cursor",
		width = width,
		height = height,
		row = 1,
		col = 0,
		title = title,
		border = border
	}
	if border then
		opts.row = 2
	end
	local buf_win = floating_win.create_win(opts)
	localBuffer = buf_win.buf
	localWindow = buf_win.win
end

local function popup_editor(title, border, height_hint)
	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	local win_height = height_hint or math.ceil(height * 0.8 - 4)
	local win_width = math.ceil(width * 0.8)

	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - win_width) / 2)

	local opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		title = title,
		border = border
	}
	local buf_win = floating_win.create_win(opts)
	localBuffer = buf_win.buf
	localWindow = buf_win.win
end

local function setWindowProperty(win)
	api.nvim_win_set_option(win, 'wrap', true)
	api.nvim_win_set_option(win, 'cursorline', true)
end

local function setBufferProperty(buf)
	api.nvim_buf_set_option(buf, 'modifiable', false)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function putData(buf, data, starting, ending)
	api.nvim_buf_set_option(buf, 'modifiable', true)
	api.nvim_buf_set_lines(buf, starting, ending, false, data)
	api.nvim_buf_set_option(buf, 'modifiable', false)
end

function M.popup(mode, height, title, border, numbering, data)
	if data == nil then
		print "nil data"
		return
	end
	close_cancelled()
	if numbering == nil then
		numbering = {
			list = 'true',
		}
	end
	if numbering.list == nil then
		numbering.list = true
	end
	if border == nil then
		border = {
			list = 'true',
		}
	end
	if border.list == nil then
		border.list = true
	end
	if title == nil then
		title = {
			list = '',
		}
	end
	if title.list == nil then
		title.list = ''
	end
	if mode == 'split' then
		popup_split(height)
	elseif mode == 'cursor' then
		popup_cursor(height, title.list, border.list, data)
	elseif mode == 'editor' then
		popup_editor(title.list, border.list, height)
	else
		print 'Unknown mode'
		return
	end
	if numbering.list then
		api.nvim_win_set_option(localWindow,'number',true)
	end
	setWindowProperty(localWindow)
	setBufferProperty(localBuffer)
	putData(localBuffer, data, 0, -1)
	exportedFunction = {
		close_cancelled = close_cancelled,
		close_selected = close_selected
	}
	api.nvim_set_current_win(localWindow)
end


function M.transferControl(callbacks, info, keymaps)
	if callbacks == nil then return end
	action.register(callbacks, info)
	local default_keymaps = {
		n = {
			-- ['q'] = close_cancelled,
			['<Esc>'] = close_cancelled,
			['<CR>'] = close_selected
		}
	}
	local nested_autocmds = {
		['BufWipeout'] = close_cancelled,
		['BufDelete'] = close_cancelled,
	}
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(localBuffer, nested_autocmds, true)
	autocmd.addCommand(localBuffer, non_nested_autocmds, false)
	keymaps = keymaps or default_keymaps
	mappings.add_keymap(localBuffer, keymaps)
	action.select(1, api.nvim_buf_get_lines(localBuffer, 0, 1, false)[1])
end

function M.getFunction(name)
	return exportedFunction[name]
end

return M
