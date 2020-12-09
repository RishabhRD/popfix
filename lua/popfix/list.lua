local api = vim.api
local floatingWindow = require'popfix.floating_win'
local M = {}
M.__index = M

local function setLines(buffer, first, last, data)
	api.nvim_buf_set_lines(buffer, first, last, false, data)
end

local function createObject(self)
	return setmetatable({}, self)
end

local function initializeNilOptsValues(opts)
	opts.title = opts.title or ''
	if opts.border == nil then
		opts.border = false
	end
	if opts.numbering == nil then
		opts.numbering = false
	end
end

local function createFloatingWindowOpts(opts)
	return {
		relative = opts.relative,
		width = opts.width,
		height = opts.height,
		row = opts.row,
		col = opts.col,
		title = opts.col,
		border = opts.border,
		border_chars = opts.border_chars
	}
end

local function createFloatingWindow(obj, opts)
	local floatingOpts = createFloatingWindowOpts(opts)
	obj.window, obj.buffer = floatingWindow.create_win(floatingOpts)
end

local function setWindowOpt(window, property, value)
	api.nvim_win_set_option(window, property, value)
end

local function setBufferOpt(buffer, property, value)
	api.nvim_buf_set_option(buffer, property, value)
end

local function setWindowOptions(window, opts)
	setWindowOpt(window, 'relativenumber', false)
	setWindowOpt(window, 'wrap', false)
	setWindowOpt(window, 'cursorline', false)
	setWindowOpt(window, 'modifiable', false)
	setWindowOpt(window, 'bufhidden', 'hide')
	setWindowOpt(window, 'bufhidden', 'hide')
	if not opts.coloring then
		setWindowOpt(window, 'winhl', 'Normal:ListNormal')
	end
	setWindowOpt(window, 'number', opts.numbering)
end

local function setBufferOptions(buffer)
	setBufferOpt(buffer, 'modifiable', false)
	setBufferOpt(buffer, 'bufhidden', 'hide')
end

local function getCurrentWindow()
	return api.nvim_get_current_win()
end

local function getCurrentBuffer()
	return api.nvim_get_current_buf()
end

local function setCurrentWindow(window)
	api.nvim_set_current_win(window)
end

local function createNewSplit()
	-- This function also jumps to new split
	local oldWindow = getCurrentWindow()
	vim.cmd('bot new')
	local window = getCurrentWindow()
	local buffer = getCurrentBuffer()
	setCurrentWindow(oldWindow)
	return window, buffer
end

local function getSplitBufferName(buffer, title)
	return string.format('Popfix #%s %s', buffer, title)
end

local function setBufferName(buffer, name)
	api.nvim_buf_set_name(buffer, name)
end

local function setWindowHeight(window, height)
	api.nvim_win_set_height(window, height)
end

local function createSplitWindow(obj, opts)
	obj.window, obj.buffer = createNewSplit()
	local name = getSplitBufferName(obj.buffer, opts.title)
	setBufferName(obj.buffer, name)
	setWindowHeight(obj.window, opts.height)
end

function M:new(opts)
	local obj = createObject(self)
	initializeNilOptsValues(opts)
	createFloatingWindow(obj, opts)
	setWindowOptions(obj.window, opts)
	setBufferOptions(obj.buffer)
	return obj
end

function M:newSplit(opts)
	local obj = createObject(self)
	initializeNilOptsValues(opts)
	createSplitWindow(obj.window, opts)
	setWindowOptions(obj.window, opts)
	setWindowOptions(obj.buffer)
end

function M:getSize()
	return api.nvim_buf_line_count(self.buffer)
end

local function checkRealElementEntered(self)
	if self.realElementEntered then
		return true
	end
	return false
end

local function replaceFirstElement(self, ele)
	setLines(self.buffer, 0, 1, {ele})
end

local function setRealElementEntered(self, flag)
	self.realElementEntered = flag
end

local function addNextElement(self, ele)
	api.nvim_buf_set_lines(self.buffer, self.numData, self.numData, false,
	{ele})
	self.numData = self.numData	+ 1
end

local function _add(self, ele)
	if not self.numData then return end
	local isRealElementEntered = checkRealElementEntered(self)
	if not isRealElementEntered then
		replaceFirstElement(self, ele)
		setRealElementEntered(self, true)
	else
		addNextElement(self, ele)
	end
end

function M:add(ele)
	vim.schedule(function()
		_add(self, ele)
	end)
end

local function _close(self)
	vim.cmd('bwipeout! ', self.buffer)
	self.buffer = nil
	self.window = nil
	self.numData = nil
	self.realElementEntered = nil
end

function M:close()
	vim.schedule(function()
		_close(self)
	end)
end

local function _clear(self)
	if self.numData == nil then return end
	setLines(self.buffer, 0, -1, {})
	self.numData = 1
	setRealElementEntered(self, nil)
end

function M:clear()
	vim.schedule(function()
		_clear(self)
	end)
end

return M
