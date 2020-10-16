local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local api = vim.api

local M = {}


local function putData(buf, data, starting, ending)
	api.nvim_buf_set_option(buf, 'modifiable', true)
	api.nvim_buf_set_lines(buf, starting, ending, false, data)
	api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close_selected(self)
	if self.action:freed() then return end
	local line = self.action:getCurrentLine()
	local index = self.action:getCurrentIndex()
	self.action:close(index, line, true)
	self.Previewer:close()
	api.nvim_win_close(self.win, true)
	if self.splitWindow then
		api.nvim_win_close(self.splitWindow, true)
	end
	self.splitWindow = nil
	mappings.free(self.buf)
	autocmd.free(self.buf)
end

local function close_cancelled(self)
	if self.action:freed() then return end
	local line = self.action:getCurrentLine()
	local index = self.action:getCurrentIndex()
	self.action:close(index, line, false)
	self.Previewer:close()
	api.nvim_win_close(self.win, true)
	if self.splitWindow then
		api.nvim_win_close(self.splitWindow, true)
	end
	self.splitWindow = nil
	mappings.free(self.buf)
	autocmd.free(self.buf)
end

local function selectionHandler(self)
	local oldIndex = self.action:getCurrentIndex()
	local line = api.nvim_win_get_cursor(self.win)[1]
	if oldIndex ~= line then
		print(line)
		local data = self.action:select(line, api.nvim_buf_get_lines(self.buf, line - 1, line, false)[1])
		self.Previewer:writePreview(data)
	end
end

local function popup_split(self, title, border, height, type)
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
	self.splitWindow = api.nvim_get_current_win()
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
	self.Previewer:newPreviewer(opts, type, 'split')
	self.buf = buf
	self.win = win
end

local function popup_editor(self, title, border, height_hint, type)
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
	self.Previewer:newPreviewer(preview_opts, type)
	self.buf = win_buf.buf
	self.win = win_buf.win
end

local function setWindowProperty(win)
	api.nvim_win_set_option(win, 'wrap', true)
	api.nvim_win_set_option(win, 'cursorline', true)
end


local function setBufferProperty(buf)
	api.nvim_buf_set_option(buf, 'modifiable', false)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
end

function M:popup(mode, height, title, border, numbering, data, type)
	if data == nil then
		print "nil data"
		return
	end
	self.Previewer = require'popfix.previewer'
	self.action = require'popfix.action'
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
	if mode == 'split' then
		popup_split(self, title, border, height, type)
	elseif mode == 'editor' then
		popup_editor(self, title, border, height, type)
	elseif mode == 'cursor' then
		print 'Cursor mode not supported for preview (yet)!'
	else
		print 'Unknown mode'
	end
	api.nvim_win_set_option(self.Previewer.win, 'number', numbering.previewer)
	api.nvim_win_set_option(self.win, 'number', numbering.list)
	api.nvim_set_current_win(self.win)
	setWindowProperty(self.win)
	setBufferProperty(self.buf)
	putData(self.buf, data, 0, -1)
	self.exported_func = {
		close_selected = close_selected,
		close_cancelled = close_cancelled
	}
end

function M:transferControl(callbacks, method, keymaps)
	if callbacks == nil then return end
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
	autocmd.addCommand(self.buf, nested_autocmds, true, self)
	autocmd.addCommand(self.buf, non_nested_autocmds, false, self)
	keymaps = keymaps or default_keymaps
	mappings.add_keymap(self.buf, keymaps, self)
	self.action:register(callbacks, method)
end

function M:getFunction(name)
	return self.exported_func[name]
end

return M
