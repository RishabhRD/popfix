local api = vim.api
local autocmd = require'popfix.autocmd'

local M = {}

local default_opts = {
	relative = "editor",
	width = 80,
	height = 40,
	row = 0,
	col = 0,
	title = "",
	options = {},
	border = false,
}

local default_border_chars = {
	TOP_LEFT = '┌',
	TOP_RIGHT = '┐',
	MID_HORIZONTAL = '─',
	MID_VERTICAL = '│',
	BOTTOM_LEFT = '└',
	BOTTOM_RIGHT = '┘',
}

local function create_win(row, col, width, height, relative, focusable)
	local buf = api.nvim_create_buf(false, true)
	local options = {
		style = "minimal",
		relative = relative,
		width = width,
		height = height,
		row = row,
		col = col,
		focusable = focusable
	}
	local win = api.nvim_open_win(buf, false, options)
	return {
		buf = buf,
		win = win
	}
end

local function fill_border_data(buf, width, height, title, border_chars)
	border_chars = border_chars or default_border_chars
	if title ~= '' then
		title = '  '..title..'  '
	end
	border_chars.TOP_LEFT = border_chars.TOP_LEFT or ' '
	border_chars.TOP_RIGHT = border_chars.TOP_RIGHT or ' '
	border_chars.MID_HORIZONTAL = border_chars.MID_HORIZONTAL or ' '
	border_chars.MID_VERTICAL = border_chars.MID_VERTICAL or ' '
	border_chars.BOTTOM_LEFT = border_chars.BOTTOM_LEFT or ' '
	border_chars.BOTTOM_RIGHT = border_chars.BOTTOM_RIGHT or ' '
	local border_lines = { border_chars.TOP_LEFT.. title ..
	string.rep(border_chars.MID_HORIZONTAL, width - #title) ..
	border_chars.TOP_RIGHT}
	local middle_line = border_chars.MID_VERTICAL.. string.rep(' ', width)
	..border_chars.MID_VERTICAL
	for i=1, height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, border_chars.BOTTOM_LEFT..
	string.rep(border_chars.MID_HORIZONTAL, width) ..border_chars.BOTTOM_RIGHT)

	api.nvim_buf_set_lines(buf, 0, -1, false, border_lines)
end

function M.create_win(opts)
	opts.width = opts.width or default_opts.width
	opts.height = opts.height or default_opts.height
	opts.title = opts.title or default_opts.title
	opts.row = opts.row or default_opts.row
	opts.col = opts.col or default_opts.col
	opts.relative = opts.relative or "editor"
	if opts.border == nil then
		opts.border = default_opts.border
	end

	local border_buf = nil


	local win_buf_pair = create_win(opts.row, opts.col, opts.width, opts.height, opts.relative, true)
	if opts.border then
		local border_win_buf_pair = create_win(opts.row - 1, opts.col - 1,
		opts.width + 2, opts.height + 2, opts.relative, false)
		api.nvim_win_set_option(border_win_buf_pair.win, 'winhl', 'Normal:Normal'
		)
		vim.cmd('redraw')
		api.nvim_buf_set_option(border_win_buf_pair.buf, 'bufhidden', 'hide')
		border_buf = border_win_buf_pair.buf
		fill_border_data(border_buf, opts.width , opts.height, opts.title , opts.border_chars)
	end

	if opts.border then
		local autocmds = {
			['BufDelete,BufWipeout'] = string.format('bwipeout! %s', border_buf),
		}
		autocmd.addCommand(win_buf_pair.buf, autocmds, true)
	end
	return win_buf_pair
end

return M
