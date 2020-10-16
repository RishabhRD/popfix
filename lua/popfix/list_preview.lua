local Previewer = require'popfix.previewer'
local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local api = vim.api

local M = {}
local splitBuffer = {}


local function putData(buf, data, starting, ending)
	api.nvim_buf_set_option(buf, 'modifiable', true)
	api.nvim_buf_set_lines(buf, starting, ending, false, data)
	api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close_selected(buf)
	local win = action.getAssociatedWindow(buf)
	if win == nil then return end
	local line = action.getCurrentLine(buf)
	local index = action.getCurrentIndex(buf)
	action.close(buf, index, line, true)
	mappings.free(buf)
	autocmd.free(buf)
	Previewer:close()
	api.nvim_win_close(win, true)
	if splitBuffer[buf] then
		api.nvim_win_close(splitBuffer[buf], true)
	end
	splitBuffer[buf] = nil
end

local function close_cancelled(buf)
	local win = action.getAssociatedWindow(buf)
	if win == nil then return end
	local line = action.getCurrentLine(buf)
	local index = action.getCurrentIndex(buf)
	action.close(buf, index, line, false)
	mappings.free(buf)
	autocmd.free(buf)
	Previewer:close()
	api.nvim_win_close(win, true)
	if splitBuffer[buf] then
		api.nvim_win_close(splitBuffer[buf], true)
	end
	splitBuffer[buf] = nil
end

local function selectionHandler(buf)
	local win = action.getAssociatedWindow(buf)
	local oldLine = action.getCurrentLine(buf)
	local line = api.nvim_win_get_cursor(win)[1]
	if oldLine ~= line then
		local data = action.select(buf, line, line)
		Previewer:writePreview(data)
	end
end

local function popup_split(title, border, height, type)
	height = height or 12
	api.nvim_command('bot new')
	local win = api.nvim_get_current_win()
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_set_name(buf, string.format('PopPreview #%s %s', buf, title.list))
	api.nvim_win_set_height(win, height)
	local width = math.floor(api.nvim_win_get_width(win) / 2)
	local pos = api.nvim_win_get_position(win)
	local x = pos[1]
	vim.cmd('vsplit')
	local tmpBuffer = api.nvim_create_buf(false, true)
	api.nvim_win_set_buf(api.nvim_get_current_win(), tmpBuffer)
	splitBuffer[buf] = api.nvim_get_current_win()
	-- local y = pos[2]
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = x,
		col = math.floor(width),
		border = border.previewer,
		title = title.previewer
	}
	Previewer:newPreviewer(opts, type, 'split')
	return  {
		buf = buf,
		win = win,
	}
end

local function popup_editor(title, border, height_hint, type)
	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	local win_height = height_hint or math.ceil(height * 0.8 - 4)
	local win_width = math.ceil(width * 0.8 / 2)

	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - 2 * win_width) / 2)

	local opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		title = title.list,
		border = border.list
	}
	local win_buf = floating_win.create_win(opts)

	local preview_opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row ,
		col = col + win_width,
		title = title.previewer,
		border = border.previewer
	}
	if border.list then
		preview_opts.col = preview_opts.col + 1
		if not border.previewer then
			preview_opts.height = preview_opts.height + 2
			preview_opts.row = preview_opts.row - 1
		end
	end
	if border.previewer then
		preview_opts.col = preview_opts.col + 1
		if not border.list then
			preview_opts.height = preview_opts.height - 2
			preview_opts.row = preview_opts.row + 1
		end
	end
	Previewer:newPreviewer(preview_opts, type)
	return {
		buf = win_buf.buf,
		win = win_buf.win,
	}
end

local function setWindowProperty(win)
	api.nvim_win_set_option(win, 'wrap', true)
	api.nvim_win_set_option(win, 'cursorline', true)
end


local function setBufferProperty(buf)
	api.nvim_buf_set_option(buf, 'modifiable', false)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	local nested_autocmds = {
		['BufWipeout'] = close_cancelled,
		['BufDelete'] = close_cancelled,
	}
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(buf, nested_autocmds, true)
	autocmd.addCommand(buf, non_nested_autocmds, false)
end

function M.popup(mode, height, title, border, numbering, data, type)
	if data == nil then
		print "nil data"
		return
	end
	if numbering == nil then
		numbering = {
			previewer = false,
			list = true
		}
	end
	if numbering.previewer == nil then
		numbering.previewer = false
	end
	if numbering.list == nil then
		numbering.list = true
	end
	if border == nil then
		border = {
			previewer = true,
			list = true
		}
	end
	if border.previewer == nil then
		border.previewer = false
	end
	if border.list == nil then
		border.list = true
	end
	if title == nil then
		title = {
			previewer = '',
			list = ''
		}
	end
	if title.previewer == nil then
		title.previewer = ''
	end
	if title.list == nil then
		title.list = ''
	end
	local win_buf
	if mode == 'split' then
		win_buf = popup_split(title, border, height, type)
	elseif mode == 'editor' then
		win_buf = popup_editor(title, border, height, type)
	elseif mode == 'cursor' then
		print 'Cursor mode not supported for preview (yet)!'
	else
		print 'Unknown mode'
	end
	local buf = win_buf.buf
	local win = win_buf.win
	api.nvim_win_set_option(Previewer.win, 'number', numbering.previewer)
	api.nvim_win_set_option(win, 'number', numbering.list)
	api.nvim_set_current_win(win)
	setWindowProperty(win)
	setBufferProperty(buf)
	putData(buf, data, 0, -1)
	mappings.addDefaultFunction(buf, 'close_selected', close_selected)
	mappings.addDefaultFunction(buf, 'close_cancelled', close_cancelled)
	action.registerBuffer(buf, win)
	return buf
end

function M.transferControl(buf, callbacks, info, keymaps)
	if callbacks == nil then return end
	local default_keymaps = {
		n = {
			-- ['q'] = close_cancelled,
			['<Esc>'] = close_cancelled,
			['<CR>'] = close_selected
		}
	}
	keymaps = keymaps or default_keymaps
	mappings.add_keymap(buf, keymaps)
	action.registerCallbacks(buf, callbacks, info)
	local data = action.select(buf, 1, 1)
	if data ~= nil then
		Previewer:writePreview(data)
	end
end

return M
