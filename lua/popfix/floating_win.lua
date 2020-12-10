local M = {}
local api = vim.api
local autocmd = require'popfix.autocmd'

local default_border_chars = {
	TOP_LEFT = '┌',
	TOP_RIGHT = '┐',
	MID_HORIZONTAL = '─',
	MID_VERTICAL = '│',
	BOTTOM_LEFT = '└',
	BOTTOM_RIGHT = '┘',
}

local function addDefaultWindowOpts(opts, focusable)
	opts.style = "minimal"
	focusable = focusable
end

local function createFloatingWindow(opts, focusable)
	local buffer = api.nvim_create_buf(false, true)
	addDefaultWindowOpts(opts, focusable)
	local window = api.nvim_open_win(buffer, false, opts)
	return window, buffer
end

local function createWindowOpts(opts)
	return {
		row = opts.row,
		column = opts.column,
		height = opts.height,
		width = opts.width,
		relative = opts.relative
	}
end

local function createBorderOpts(opts)
	return {
		row = opts.row - 1,
		col = opts.col - 1,
		width = opts.width + 2,
		height = opts.height + 2,
		relative = opts.relative
	}
end

local function setBorderHighlight(borderWindow)
	api.nvim_win_set_option(borderWindow, 'winhl', 'Normal:Normal')
end

local function redrawUI()
	vim.cmd('redraw')
end

local function createBorderTopLine(char, str, width)
	local len
	if str == nil then
		len = 2
	else
		len = #str + 2
	end
	local returnString = ''
	if len ~= 2 then
		returnString = returnString .. string.rep(char, math.floor(width/2 - len/2))
		.. ' ' .. str .. ' '
		local remaining = width - (len + math.floor(width / 2 - len / 2))
		returnString = returnString .. string.rep(char, remaining)
		return returnString
	else
		returnString = returnString .. string.rep(char, width)
		return returnString
	end
end

local function fillBorderData(borderBuffer, width, height, title, chars)
	local topLine = createBorderTopLine(chars.MID_HORIZONTAL, title, width)
	local border_lines = { chars.TOP_LEFT.. topLine ..
	chars.TOP_RIGHT}
	local middle_line = chars.MID_VERTICAL.. string.rep(' ', width)
	..chars.MID_VERTICAL
	for _=1, height do
		table.insert(border_lines, middle_line)
	end
	table.insert(border_lines, chars.BOTTOM_LEFT..
	string.rep(chars.MID_HORIZONTAL, width) ..chars.BOTTOM_RIGHT)

	api.nvim_buf_set_lines(borderBuffer, 0, -1, false, border_lines)
end

local function getBorderCharacters(border_chars)
	border_chars = border_chars or default_border_chars
	border_chars.TOP_LEFT = border_chars.TOP_LEFT or ' '
	border_chars.TOP_RIGHT = border_chars.TOP_RIGHT or ' '
	border_chars.MID_HORIZONTAL = border_chars.MID_HORIZONTAL or ' '
	border_chars.MID_VERTICAL = border_chars.MID_VERTICAL or ' '
	border_chars.BOTTOM_LEFT = border_chars.BOTTOM_LEFT or ' '
	border_chars.BOTTOM_RIGHT = border_chars.BOTTOM_RIGHT or ' '
	return border_chars
end

local function drawBorders(opts)
	local borderOpts = createBorderOpts(opts)
	local window, buffer = createFloatingWindow(borderOpts, false)
	setBorderHighlight(window)
	redrawUI()
	local borderCharacters = getBorderCharacters(opts.border_chars)
	fillBorderData(buffer, borderOpts.width, borderOpts.height,
	borderOpts.title, borderCharacters)
	return window, buffer
end

local function addAutocmdBorderCloseOnMainBufferClose(buffer, borderBuffer)
	local autocmds = {
		['BufDelete,BufWipeout'] = string.format('bwipeout! %s', borderBuffer),
		['nested'] = true,
		['once'] = true
	}
	autocmd.addCommand(buffer, autocmds)
end

function M.create_win(opts)
	local windowOpts = createWindowOpts(opts)
	local window, buffer = createFloatingWindow(windowOpts, true)
	if opts.border then
		local _, borderBuffer = drawBorders(opts)
		addAutocmdBorderCloseOnMainBufferClose(buffer, borderBuffer)
	end
	return window, buffer
end

return M
