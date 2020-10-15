local Previewer = require'popfix.previewer'
local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local api = vim.api

local M = {}
local previewBuffer = {}

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
	local preview = previewBuffer[buf]
	api.nvim_win_close(preview.win, true)
	api.nvim_win_close(win, true)
end

local function close_cancelled(buf)
	local win = action.getAssociatedWindow(buf)
	if win == nil then return end
	local line = action.getCurrentLine(buf)
	local index = action.getCurrentIndex(buf)
	action.close(buf, index, line, false)
	local preview = previewBuffer[buf]
	api.nvim_win_close(preview.win, true)
	api.nvim_win_close(win, true)
end

local function selectionHandler(buf)
	local win = action.getAssociatedWindow(buf)
	local oldLine = action.getCurrentLine(buf)
	local line = api.nvim_win_get_cursor(win)[1]
	local previewer = previewBuffer[buf]
	if oldLine ~= line then
		local data = action.select(buf, line, line)
		Previewer.writePreview(previewer, data)
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
	local preview = Previewer.getPreviewer(opts, type)
	return  {
		buf = buf,
		win = win,
		preview = preview
	}
end

local function popup_editor(title, border, height_hint, type)
	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	local win_height = height_hint or math.ceil(height * 0.8 - 4)
	local win_width = math.ceil(width * 0.8) / 2

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
		row = row + win_width,
		col = col,
		title = title.previewer,
		border = border.previewer
	}
	if border.list then
		preview_opts.col = preview_opts.col + 2
	end
	if border.previewer then
		preview_opts.col = preview_opts.col + 2
	end
	local preview = Previewer.getPreviewer(preview_opts, type)
	return {
		buf = win_buf.buf,
		win = win_buf.win,
		preview = preview
	}
end

local function setWindowProperty(win)
	api.nvim_win_set_option(win, 'wrap', true)
	api.nvim_win_set_option(win, 'cursorline', true)
end


local function setBufferProperty(buf)
	api.nvim_buf_set_option(buf, 'modifiable', false)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	api.nvim_buf_set_option(buf, 'modifiable', false)
	local autocmds = {
		['CursorMoved'] = selectionHandler,
		['BufWipeout'] = close_cancelled,
	}
	autocmd.addCommand(buf, autocmds)
end

function M.popupListPreview(mode, height, title, border, numbering, data, type)
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
	local preview_win = win_buf.preview.win
	api.nvim_win_set_option(preview_win, 'number', numbering.previewer)
	api.nvim_win_set_option(win, 'number', numbering.list)
	api.nvim_buf_set_option(win_buf.preview.buf, 'bufhidden', 'wipe')
	api.nvim_set_current_win(win)
	setWindowProperty(win)
	setBufferProperty(buf)
	previewBuffer[buf] = win_buf.preview
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
			['q'] = close_cancelled,
			['<Esc>'] = close_cancelled,
			['<CR>'] = close_selected
		}
	}
	keymaps = keymaps or default_keymaps
	mappings.add_keymap(buf, keymaps)
	action.registerCallbacks(buf, callbacks, info)
	local data = action.select(buf, 1, 1)
	local previewer = previewBuffer[buf]
	if data ~= nil then
		Previewer.writePreview(previewer, data)
	end
end

return M
