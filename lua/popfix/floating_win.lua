local api = vim.api

local M = {}

local default_opts = {
	relative = "editor",
	width = 80,
	height = 40,
	row = 0,
	col = 0,
	title = "",
	options = {},
	border = false
}

local function create_win(row, col, width, height, relative)
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	print(relative)
	local options = {
		style = "minimal",
		relative = relative,
		width = width,
		height = height,
		row = row,
		col = col
	}
	local win = api.nvim_open_win(buf, false, options)
	return {
		buf = buf,
		win = win
	}
end

local function fill_border_data(buf, width, height, title)
	local border_lines = { '╔' .. title .. string.rep('═', width - #title) .. '╗' }
	local middle_line = '║' .. string.rep(' ', width) .. '║'
	for i=1, height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, '╚' .. string.rep('═', width) .. '╝')

	api.nvim_buf_set_lines(buf, 0, -1, false, border_lines)
end

function M.create_win(opts)
	opts.relative = opts.relative or default_opts.relative
	opts.width = opts.width or default_opts.width
	opts.height = opts.height or default_opts.height
	opts.title = opts.title or default_opts.title
	opts.row = opts.row or default_opts.row
	opts.col = opts.col or default_opts.col
	opts.border = opts.border or default_opts.border

	local border_buf = nil

	local win_buf_pair = create_win(opts.row, opts.col, opts.width, opts.height, opts.relative)

	if opts.border then
		local border_win_buf_pair = create_win(opts.row - 1, opts.col - 1,
		opts.width + 2, opts.height + 2, opts.relative
		)
		border_buf = border_win_buf_pair.buf
		fill_border_data(border_buf, opts.width , opts.height, opts.title )
	end


	if border_buf then
		api.nvim_command(string.format('au Bufwipeout <buffer=%s> exe "silent\
		bwipeout! %s"',win_buf_pair.buf, border_buf))
	end
	return win_buf_pair
end

return M
