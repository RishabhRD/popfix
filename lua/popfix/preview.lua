local floating_win = require'popfix.floating_win'
local api = vim.api

local preview = {}

local previewNamespace = api.nvim_create_namespace('popfix.preview')

local function fileExists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

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
	local win_buf = floating_win.create_win(opts)
	local initial = {}
	initial.currentTerminalJob = nil
	initial.type = opts.type
	if opts.type == 'buffer' then
		initial.buffers = {}
	end
	initial.window = win_buf.win
	initial.buffer = win_buf.buf
	if opts.numbering == nil then opts.numbering = false end
	if opts.coloring == nil or opts.coloring == false then
		api.nvim_win_set_option(initial.window, 'winhl', 'Normal:PreviewNormal')
	end
	api.nvim_buf_set_option(initial.buffer, 'bufhidden', 'hide')
	api.nvim_win_set_option(initial.window, 'wrap', false)
	api.nvim_win_set_option(initial.window, 'number', opts.numbering)
	initial.numbering = opts.numbering
	api.nvim_win_set_option(initial.window, 'relativenumber', false)
	return setmetatable(initial, self)
end

function preview:writePreview(data)
	if self.type == 'terminal' then
		data.cmd = data.cmd or {}
		local opts = {
			cwd = data.cwd or vim.fn.getcwd()
		}
		local cur_win = api.nvim_get_current_win()
		local jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', self.window)
		vim.cmd(jumpString)
		vim.cmd('set nomod')
		stopCurrentJob(self)
		self.currentTerminalJob = vim.fn.termopen(data.cmd, opts)
		jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', cur_win)
		vim.cmd(jumpString)
	elseif self.type == 'text' then
		api.nvim_buf_set_lines(self.buffer, 0, -1, false, data.data or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(self.buffer, previewNamespace,
			"Visual", data.line - 1, 0, -1)
		end
	elseif self.type == 'buffer' then
		local cur_win = api.nvim_get_current_win()
		local jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', self.window)
		vim.cmd(jumpString)
		if self.buffers[data.filename] then
			api.nvim_win_set_buf(self.window, self.buffers[data.filename].bufnr)
			api.nvim_buf_add_highlight(self.buffers[data.filename].bufnr, previewNamespace,
			"Visual", data.line - 1, 0, -1)
			api.nvim_win_set_option(self.window, 'number', self.numbering)
		else
			if fileExists(data.filename) then
				local buf
				if vim.fn.bufloaded(data.filename) == 1 then
					buf = vim.fn.bufadd(data.filename)
					self.buffers[data.filename] = {
						bufnr = buf,
						loaded = true
					}
				else
					buf = vim.fn.bufadd(data.filename)
					self.buffers[data.filename] = {
						bufnr = buf,
						loaded = false
					}
				end
				api.nvim_win_set_buf(self.window, buf)
				api.nvim_buf_add_highlight(buf, previewNamespace,
				"Visual", data.line - 1, 0, -1)
				api.nvim_win_set_option(self.window, 'number', self.numbering)
			else
				api.nvim_win_set_buf(self.window, self.buffer)
			end
		end
		if data.line ~= nil then
			vim.cmd(string.format('norm %sGzt2k', data.line))
		end
		jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', cur_win)
		vim.cmd(jumpString)
		--TODO: fileself.type is not working
		-- vim.cmd([[doautocmd fileself.typedetect BufRead ]] .. data.filename)
	end
end


function preview:close()
	if self.buffer ~= nil then
		local buf = self.buffer
		vim.cmd(string.format('bwipeout! %s', buf))
	end
	self.buffer = nil
	self.window = nil
	self.type = nil
	if self.buffers then
		for _, buffer in pairs(self.buffers) do
			if not buffer.loaded then
				vim.cmd(string.format('bdelete! %s', buffer.bufnr))
			end
		end
		self.buffers = nil
	end
	stopCurrentJob(self)
end

return preview
