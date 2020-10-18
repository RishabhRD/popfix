local api = vim.api
local floating_win = require'popfix.floating_win'

local list = {}
list.buffer = nil
list.window = nil

local function popup_split(height, title)
	height = height or 12
	api.nvim_command('bot new')
	local oldWindow = api.nvim_get_current_win()
	local win = api.nvim_get_current_win()
	local buf = api.nvim_get_current_buf()
	title = title or ''
	api.nvim_buf_set_name(buf, 'PopList #'..buf..title)
	api.nvim_win_set_height(win, height)
	list.buffer = buf
	list.window = win
	api.nvim_set_current_win(oldWindow)
end

local function popup_cursor(height, title, border, width)
	if not width then
		--TODO: better width strategy
		width = width or 40
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
	list.buffer = buf_win.buf
	list.window = buf_win.win
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
	list.buffer = buf_win.buf
	list.window = buf_win.win
end

function list.new(opts)
	opts.title = opts.title or ''
	if opts.border == nil then opts.border = false end
	if opts.mode == nil then
		opts.mode = 'split'
	end
	if opts.mode == 'split' then
		popup_split(opts.height, opts.title)
	elseif opts.mode == 'editor' then
		popup_editor(opts.title, opts.border, opts.height)
	elseif opts.mode == 'cursor' then
		popup_cursor(opts.height, opts.title, opts.border, opts.width)
	else
		print('Unknown mode')
		return false
	end
	if opts.numbering == nil then
		opts.numbering = false
	end
	api.nvim_win_set_option(list.window, 'number', opts.numbering)
	api.nvim_win_set_option(list.window, 'relativenumber', false)
	if opts.coloring == nil or opts.coloring == false then
		api.nvim_win_set_option(list.window, 'winhl', 'Normal:ListNormal')
	end
	api.nvim_win_set_option(list.window, 'wrap', false)
	api.nvim_win_set_option(list.window, 'cursorline', true)
	api.nvim_buf_set_option(list.buffer, 'modifiable', false)
	api.nvim_buf_set_option(list.buffer, 'bufhidden', 'wipe')
	return true
end

function list.setData(data, starting, ending)
	api.nvim_buf_set_option(list.buffer, 'modifiable', true)
	api.nvim_buf_set_lines(list.buffer, starting, ending, false, data)
	api.nvim_buf_set_option(list.buffer, 'modifiable', false)
end

function list.close()
	api.nvim_win_close(list.window, true)
	list.buffer = nil
	list.window = nil
end

function list.getCurrentLineNumber()
	return api.nvim_win_get_cursor(list.window)[1]
end

function list.getCurrentLine()
	local lineNumber = list.getCurrentLineNumber()
	return api.nvim_buf_get_lines(list.buffer, lineNumber - 1, lineNumber, false)[1]
end

return list
