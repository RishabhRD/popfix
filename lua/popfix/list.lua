local floating_win = require'popfix.floating_win'
local action = require'popfix.action'
local api = vim.api
local M = {}

local function popup_split(height, title)
	height = height or 12
	api.nvim_command('bot new')
	local win = api.nvim_get_current_win()
	local buf = api.nvim_get_current_buf()
	title = title or ''
	api.nvim_buf_set_name(buf, 'PopList #'..buf..title)
	api.nvim_win_set_height(win, height)
	return {buf = buf, win = win}
end

local function popup_cursor(height, title, border, data)
	border = border or false
	local width = 40
	title = title or ''
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
	local buf_win = floating_win.open_win(opts)
	return buf_win
end

local function popup_win(title, border)
	title = title or ''
	border = border or ''
	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")

	local win_height = math.ceil(height * 0.8 - 4)
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
	floating_win.open_win(opts)
end

local function setWindowProperty(win)
	vim.api.nvim_win_set_option(win,'number',true)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

local function setBufferProperty(buf)
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

function M.popupList(mode, height, title, border, data)
	if data == nil then
		print "nil data"
		return
	end
	local win_buf
	if mode == 'split' then
		win_buf = popup_split(height)
	elseif mode == 'cursor' then
		win_buf = popup_cursor(height, title, border, data)
	elseif mode == 'win' then
		win_buf = popup_win(title, border)
	else
		print 'Unknown mode'
		return
	end
	local buf = win_buf.buf
	local win = win_buf.win
	setWindowProperty(win)
	setBufferProperty(buf)
	action.registerBuffer(buf, win)
	return buf
end

function M.transferControl(buf, callbacks, info, metadata)
	if callbacks == nil then return end
	action.registerCallbacks(buf, callbacks, info, metadata)
	action.select(buf, 1, 1)
end

return M
