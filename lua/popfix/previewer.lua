local floating_win = require'popfix.floating_win'
local api = vim.api

local M = {}
M.__index = M

local previewNamespace = api.nvim_create_namespace('popfix.preview')

local function createObject(self)
	return setmetatable({}, self)
end

local function isOptsValid(opts)
	if opts.type == nil then
		print 'provide a preview type'
		return false
	end
	if opts.type ~= 'text' or opts.type ~= 'buffer' and opts.type ~= 'terminal'
		then
		print 'Preview: bad type'
		return false
	end
end

local function initUninitializedOpts(opts)
	opts.title = opts.title or ''
	if opts.numbering == nil then opts.numbering = false end
	if opts.coloring == nil then opts.coloring = false end
end

local function initObjectState(self, opts)
	self.numbering = opts.numbering
	self.coloring = opts.coloring
	self.type = opts.type
end

local function createFloatingWindow(opts)
	return floating_win.create_win(opts)
end

local function colorBackground(self)
	if not self.coloring then
		api.nvim_win_set_option(self.window, 'winhl', 'Normal:PreviewNormal')
	end
end

local function setNumber(self)
	api.nvim_win_set_option(self.window, 'number', self.numbering)
end

function M:new(opts)
	local obj = createObject(self)
	if not isOptsValid(opts) then
		return false
	end
	initUninitializedOpts(opts)
	initObjectState(obj, opts)
	obj.window, obj.buffer = createFloatingWindow(opts)
	colorBackground(obj)
	setNumber(obj)
	return obj
end

local function isClosed(self)
	if self.buffer then
		return true
	end
	return false
end

local function clearPreviewHighlighting(buffer)
	api.nvim_buf_clear_namespace(buffer, previewNamespace, 0, -1)
end

local function getCwd(cwd)
	return cwd or vim.fn.getcwd()
end

local function jumpToWindowWithoutAutocmd(window)
	local jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', window)
	vim.cmd(jumpString)
end

local function getCurrentWindow()
	return api.nvim_get_current_win()
end

local function isTerminalPreviewJobRunnign(self)
	if self.currentTerminalJob == nil then return false end
	return vim.fn.jobwait({self.currentTerminalJob}, 0)[1] == -1
end

local function stopCurrentTerminalPreviewJob(self)
	if self.currentTerminalJob ~= nil then
		if isTerminalPreviewJobRunnign(self) then
			vim.fn.chanclose(self.currentTerminalJob)
			vim.fn.jobstop(self.currentTerminalJob)
		end
		self.currentTerminalJob = nil
	end
end

local function writeDataToTerminalPreviewWindow(self, data)
	stopCurrentTerminalPreviewJob(self)
	self.currentTerminalJob = vim.fn.termopen(data.cmd, {cwd = data.cwd})
end

local function writeTerminalPreview(self, data)
	if not data then return end
	if not data.cmd then return end
	data.cwd = getCwd(data.cwd)
	local currentWindow = getCurrentWindow()
	jumpToWindowWithoutAutocmd(self.window)
	writeDataToTerminalPreviewWindow(self, data)
	jumpToWindowWithoutAutocmd(currentWindow)
end

local function setLines(buffer, data)
	api.nvim_win_set_lines(buffer, 0, -1, false, data)
end

local function highlightPreviewLine(buffer, line)
	if line == nil then return end
	api.nvim_buf_add_highlight(buffer, previewNamespace, "Visual", line - 1, 0
	, -1)
end

local function writeTextPreview(self, data)
	if data == nil then return end
	setLines(self.buffer, data.data or {})
	if data.line then
		highlightPreviewLine(self.buffer, data.line)
	end
end

local function setWindowBuffer(window, buffer)
	api.nvim_win_set_buf(window, buffer)
end

local function writeBufferPreview(self, data)
	if data.bufnr then
		data.bufnr = self.buffer
	end
	setWindowBuffer(self.window, data.bufnr)
	if data.line then
		highlightPreviewLine(data.bufnr, data.line)
	end
end

local function _writePreview(self, data)
	if isClosed(self) then return end
	clearPreviewHighlighting(self.buffer)
	if self.type == 'terminal' then
		writeTerminalPreview(self, data)
	elseif self.type == 'text' then
		writeTextPreview(self, data)
	else
		writeBufferPreview(self, data)
	end
	setNumber(self)
	colorBackground(self)
end

function M:writePreview(data)
	vim.schedule(function()
		_writePreview(self, data)
	end)
end

local function getWindowBuffer(window)
	return api.nvim_win_get_buf(window)
end

local function _close(self)
	local currentBuffer = getWindowBuffer(self.window)
	clearPreviewHighlighting(currentBuffer)
	setWindowBuffer(self.window, self.buffer)
	vim.cmd(string.format('bwipeout! %s', self.buffer))
	self.buffer = nil
	self.window = nil
	self.type = nil
end

function M:close()
	stopCurrentTerminalPreviewJob(self)
	vim.schedule(function()
		_close(self)
	end)
end
