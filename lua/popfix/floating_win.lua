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
	-- keymaps = {},
	-- autocmds = {}
}

local function create_win(row, col, width, height, relative)
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	local options = {
		style = "minimal",
		relative = relative,
		width = width,
		height = height,
		row = row,
		col = col
	}
	local win = api.nvim_open_win(buf, true, options)
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

	if opts.border then
		local border_win_buf_pair = create_win(opts.row - 1, opts.col - 1,
		opts.width + 2, opts.height + 2, opts.relative
		)
		border_buf = border_win_buf_pair.buf
		fill_border_data(border_buf, opts.width , opts.height, opts.title )
	end

	local win_buf_pair = create_win(opts.row, opts.col, opts.width, opts.height, opts.relative)
	local buf = win_buf_pair.buf
	local win = win_buf_pair.win

	if border_buf then
		api.nvim_command('au Bufwipeout <buffer> exe "silent bwipeout! "'..border_buf)
	end
	return {
		buf = buf,
		win = win
	}
end


function M.default_win()
	local opts = {
		relative = "editor",
		width = 20,
		height = 20,
		row = 5,
		col = 5,
		title = "Testing",
		border = true
	}
	M.create_win(opts)
end

return M
