local floating_win = require'popfix.floating_win'
local api = vim.api

local M = {}

local selfNamespace = api.nvim_create_namespace('self')

local function isCurrentJobRunning(self)
	if self.currentTerminalJob == nil then return false end
	return vim.fn.jobwait({self.currentTerminalJob}, 0)[1] == -1
end

local function stopCurrentJob(self)
	if self.currentTerminalJob ~= nil then
		if isCurrentJobRunning(self) then
			vim.fn.jobstop(self.currentTerminalJob)
		end
		self.currentTerminalJob = nil
	end
end

function M:newPreviewer(opts, type, tp)
	self:close()
	local win_buf = floating_win.create_win(opts, tp)
	self.currentTerminalJob = nil
	self.type = type
	self.win = win_buf.win
	self.buf = win_buf.buf
	api.nvim_buf_set_option(self.buf, 'bufhidden', 'hide')
	api.nvim_win_set_option(self.win, 'wrap', false)
end

function M:writePreview(data)
	if self.type == 'terminal' then
		-- TODO: terminal windows are waiting to close. Close them buddy ;)
		-- Memory leak here.
		local cwd = data.cwd
		local opts = {
			cwd = cwd or vim.fn.getcwd()
		}
		local cur_win = api.nvim_get_current_win()
		api.nvim_set_current_win(self.win)
		vim.cmd('set nomod')
		stopCurrentJob(self)
		self.currentTerminalJob = vim.fn.termopen(data.cmd, opts)
		api.nvim_set_current_win(cur_win)
	elseif self.type == 'buffer' then
		api.nvim_buf_set_lines(self.buf, 0, -1, false, data.lines or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(self.buf, selfNamespace,
			"Visual", data.line, 0, -1)
		end
	else
		print('Invalid preview type')
		return
	end
end

function M:close()
	if self.buf ~= nil then
		api.nvim_command(string.format('bwipeout! %s', self.buf))
	end
	self.buf = nil
	self.win = nil
	self.type = nil
	stopCurrentJob(self)
end

function M:isNil()
	return self.buf == nil
end

return M
