local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'

local api = vim.api

local M = {}
M.__index = M

local function createObject(self)
	return setmetatable({}, self)
end

local function initOpts(opts)
	if opts.border == nil then
		opts.border = false
	end
	opts.title = opts.title or ''
	opts.height = 1
	opts.prompt_text = opts.prompt_text or ''
	opts.init_text = opts.init_text or ''
end

local function initObjectState(self, opts)
	self.prefix = opts.prompt_text .. '> '
	self.currentPromptText = opts.init_text
end

local function createFloatingWindow(opts)
	return floating_win.create_win(opts)
end

local function setWindowOpt(window, property, value)
	api.nvim_win_set_option(window, property, value)
end

local function setPromptWindowProperty(self, opts)
	setWindowOpt(self.window, 'wrap', false)
	setWindowOpt(self.window, 'number', opts.numbering)
	setWindowOpt(self.window, 'relativenumber', opts.numbering)
	if not opts.coloring then
		setWindowOpt(self.window, 'winhl', 'Normal:PromptNormal')
	end
end

local function setBufferOpt(buffer, property, value)
	api.nvim_buf_set_option(buffer, property, value)
end

local function setPromptBufferProperty(self)
	setBufferOpt(self.buffer, 'bufhidden', 'hide')
	setBufferOpt(self.buffer, 'buftype', 'prompt')
end

local function setPrompt(buffer, prefix)
	vim.fn.prompt_setprompt(buffer, prefix)
end

local function setLines(buffer, line)
	api.nvim_buf_set_lines(buffer, 0, -1, line)
end

local function setCursor(window, cell)
	api.nvim_win_set_cursor(window, cell)
end

local function isClosed(self)
	if self.buffer == nil then
		return true
	end
	return false
end

function M:setPromptText(line)
	if isClosed(self) then return end
	line = self.prefix..line
	setLines(self.buffer, {line})
	vim.cmd('startinsert')
	setCursor(self.window, {1, #line})
	self.currentPromptText = line
end

local function setupStartInsertOnEnter(self)
	self.insertStarted = true
	local function startInsert()
		if not self.insertStarted then
			vim.cmd('startinsert')
			self.insertStarted = true
		end
	end
    autocmd.addCommand(self.buffer, {['BufEnter,WinEnter'] = startInsert})
end

function M:new(opts)
	local obj = createObject(self)
	initOpts(opts)
	initObjectState(obj, opts)
	obj.window, obj.buffer = createFloatingWindow(opts)
	setPromptWindowProperty(obj, opts)
	setPromptBufferProperty(obj)
	setPrompt(obj.buffer, obj.prefix)
	obj:setPromptText(opts.init_text)
	setupStartInsertOnEnter(obj)
	return obj
end

function M:getCurrentPromptText()
	if isClosed(self) then return end
	return self.currentPromptText
end

function M:registerTextChanged(func)
    self.textChanged = func
	local function on_lines(_, _, _, first, last)
	    local promptText = vim.trim(vim.api.nvim_buf_get_lines(self.buffer,
	    first, last, false)[1]:sub(#self.prefix))
		self.currentPromptText = promptText
	    self.textChanged(promptText)
	end
	vim.api.nvim_buf_attach(self.buffer, false, {
	    on_lines = on_lines,
	    -- on_changedtick = on_lines,
	})
end

local function _close(self)
	vim.cmd(string.format('bwipeout! %s', self.buffer))
	autocmd.free(self.buffer)
	self.buffer = nil
	self.window = nil
	self.prefix = nil
	self.textChagned = nil
end

function M:close()
	vim.schedule(function()
		_close(self)
	end)
end

return M
