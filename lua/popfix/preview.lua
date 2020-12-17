local floating_win = require'popfix.floating_win'
local api = vim.api

local preview = {}

local previewNamespace = api.nvim_create_namespace('popfix.preview')

local function isCurrentJobRunning(self)
    if self.currentTerminalJob == nil then return false end
    return vim.fn.jobwait({self.currentTerminalJob}, 0)[1] == -1
end

local function stopCurrentJob(self)
    if self.currentTerminalJob ~= nil then
	if isCurrentJobRunning(self) then
	    vim.fn.chanclose(self.currentTerminalJob)
	    vim.fn.jobstop(self.currentTerminalJob)
	end
	self.currentTerminalJob = nil
    end
end

function preview:new(opts)
    self.__index = self
    if opts.type == nil then
	print 'provide a preview type'
	return false
    end
    if opts.border == nil then
	opts.border = false
    end
    if opts.type ~= 'text' and opts.type ~= 'buffer' and opts.type ~= 'terminal' then
	print('not a valid preview type')
	return false
    end
    opts.title = opts.title or ''
    if opts.list_border then
	opts.col = opts.col + 1
	if not opts.border then
	    opts.height = opts.height + 2
	    opts.row = opts.row - 1
	end
    end
    if opts.border then
	opts.col = opts.col + 1
	if not opts.list_border then
	    opts.height = opts.height - 2
	    opts.row = opts.row + 1
	end
    end
    opts.preview_highlight = opts.preview_highlight or 'Visual'
    local win_buf = floating_win.create_win(opts)
    local initial = {}
    initial.preview_highlight = opts.preview_highlight
    initial.currentTerminalJob = nil
    initial.type = opts.type
    initial.window = win_buf.win
    initial.buffer = win_buf.buf
    if opts.numbering == nil then opts.numbering = false end
    opts.highlight = opts.highlight or 'Normal'
    initial.highlight = opts.highlight
    initial.numbering = opts.numbering
    api.nvim_win_set_option(initial.window, 'winhl', 'Normal:'..opts.highlight)
    api.nvim_buf_set_option(initial.buffer, 'bufhidden', 'hide')
    api.nvim_win_set_option(initial.window, 'wrap', false)
    api.nvim_win_set_option(initial.window, 'number', opts.numbering)
    initial.numbering = opts.numbering
    api.nvim_win_set_option(initial.window, 'relativenumber', false)
    if opts.type == 'terminal' then
	initial.oldBuffers = {}
	initial.oldBuffersLen = 0
    end
    return setmetatable(initial, self)
end

function preview:writePreview(data)
    local currentBuffer = api.nvim_win_get_buf(self.window)
    api.nvim_buf_clear_namespace(currentBuffer, previewNamespace, 0, -1)
    if self.type == 'terminal' then
	data.cmd = data.cmd or {}
	local opts = {
	    cwd = data.cwd or vim.fn.getcwd()
	}
	local cur_win = api.nvim_get_current_win()
	local jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', self.window)
	vim.cmd(jumpString)
	stopCurrentJob(self)
	local newBuffer = api.nvim_create_buf(false, true)
	api.nvim_win_set_buf(self.window, newBuffer)
	self.currentTerminalJob = vim.fn.termopen(data.cmd, opts)
	self.oldBuffersLen = self.oldBuffersLen + 1
	self.oldBuffers[self.oldBuffersLen] = newBuffer
	jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', cur_win)
	vim.cmd(jumpString)
    elseif self.type == 'text' then
	api.nvim_buf_set_lines(self.buffer, 0, -1, false, data.data or {''})
	if data.line ~= nil then
	    api.nvim_buf_add_highlight(self.buffer, previewNamespace,
	    self.preview_highlight, data.line - 1, 0, -1)
	end
    elseif self.type == 'buffer' then
	if data.bufnr == nil then
	    data.bufnr = self.buffer
	end
	api.nvim_win_set_buf(self.window, data.bufnr)
	if data.line then
	    if data.line == 0 then data.line = 1 end
	    api.nvim_buf_add_highlight(data.bufnr, previewNamespace,
	    self.preview_highlight, data.line - 1, 0, -1)
	end
    end
    if self.numbering then
	api.nvim_win_set_option(self.window, 'number', true)
    end
    self.highlight = self.highlight or 'Normal'
    api.nvim_win_set_option(self.window, 'winhl', 'Normal:'..self.highlight)
    api.nvim_win_set_option(self.window, 'wrap', false)

end


function preview:close()
    stopCurrentJob(self)
    local buf = self.buffer
    local win = self.window
    -- TODO: I can't believe it but it is taking one more tick to close.
    local oldBuffers = self.oldBuffers
    vim.schedule(function()
	local currentBuffer = api.nvim_win_get_buf(win)
	api.nvim_buf_clear_namespace(currentBuffer, previewNamespace, 0, -1)
	api.nvim_win_set_buf(win,buf)
	vim.cmd(string.format('bwipeout! %s', buf))
	if oldBuffers then
	    for k,buffer in ipairs(oldBuffers) do
		vim.cmd(string.format('bwipeout! %s', buffer))
		oldBuffers[k] = nil
	    end
	end
    end)
    self.oldBuffers = nil
    self.buffer = nil
    self.window = nil
    self.type = nil
end

return preview
