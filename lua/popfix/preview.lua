local floating_win = require'popfix.floating_win'
local api = vim.api

local preview = {}
preview.buffer = nil
preview.window = nil
local numbering = nil

local previewNamespace = api.nvim_create_namespace('popfix.preview')
local type = nil
local currentTerminalJob = nil
local buffers = nil

local function fileExists(name)
	local f=io.open(name,"r")
	if f~=nil then io.close(f) return true else return false end
end

local function isCurrentJobRunning()
	if currentTerminalJob == nil then return false end
	return vim.fn.jobwait({currentTerminalJob}, 0)[1] == -1
end

local function stopCurrentJob()
	if currentTerminalJob ~= nil then
		if isCurrentJobRunning() then
			vim.fn.chanclose(currentTerminalJob)
			vim.fn.jobstop(currentTerminalJob)
		end
		currentTerminalJob = nil
	end
end

function preview.new(opts)
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
	local win_buf = floating_win.create_win(opts, opts.mode)
	currentTerminalJob = nil
	type = opts.type
	if opts.type == 'buffer' then
		buffers = {}
	end
	preview.window = win_buf.win
	preview.buffer = win_buf.buf
	if opts.numbering == nil then opts.numbering = false end
	if opts.coloring == nil or opts.coloring == false then
		api.nvim_win_set_option(preview.window, 'winhl', 'Normal:PreviewNormal')
	end
	api.nvim_buf_set_option(preview.buffer, 'bufhidden', 'hide')
	api.nvim_win_set_option(preview.window, 'wrap', false)
	api.nvim_win_set_option(preview.window, 'number', opts.numbering)
	numbering = opts.numbering
	api.nvim_win_set_option(preview.window, 'relativenumber', false)
	return true
end

function preview.writePreview(data)
	if type == 'terminal' then
		-- TODO. terminal windows are waiting to close. Close them buddy ;)
		-- memory leak here.
		data.cmd = data.cmd or {}
		local opts = {
			cwd = data.cwd or vim.fn.getcwd()
		}
		local cur_win = api.nvim_get_current_win()
		local jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', preview.window)
		vim.cmd(jumpString)
		vim.cmd('set nomod')
		stopCurrentJob()
		currentTerminalJob = vim.fn.termopen(data.cmd, opts)
		jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', cur_win)
		vim.cmd(jumpString)
	elseif type == 'text' then
		api.nvim_buf_set_lines(preview.buffer, 0, -1, false, data.data or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(preview.buffer, previewNamespace,
			"Visual", data.line - 1, 0, -1)
		end
	elseif type == 'buffer' then
		local cur_win = api.nvim_get_current_win()
		local jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', preview.window)
		vim.cmd(jumpString)
		if buffers[data.filename] then
			api.nvim_win_set_buf(preview.window, buffers[data.filename].bufnr)
			api.nvim_buf_add_highlight(buffers[data.filename].bufnr, previewNamespace,
			"Visual", data.line - 1, 0, -1)
			api.nvim_win_set_option(preview.window, 'number', numbering)
		else
			if fileExists(data.filename) then
				local buf
				if vim.fn.bufloaded(data.filename) == 1 then
					buf = vim.fn.bufadd(data.filename)
					buffers[data.filename] = {
						bufnr = buf,
						loaded = true
					}
				else
					buf = vim.fn.bufadd(data.filename)
					buffers[data.filename] = {
						bufnr = buf,
						loaded = false
					}
				end
				api.nvim_win_set_buf(preview.window, buf)
				api.nvim_buf_add_highlight(buf, previewNamespace,
				"Visual", data.line - 1, 0, -1)
				api.nvim_win_set_option(preview.window, 'number', numbering)
			else
				api.nvim_win_set_buf(preview.window, preview.buffer)
			end
		end
		if data.line ~= nil then
			vim.cmd(string.format('norm %sGzt2k', data.line))
		end
		jumpString = string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', cur_win)
		vim.cmd(jumpString)
		--TODO: filetype is not working
		-- vim.cmd([[doautocmd filetypedetect BufRead ]] .. data.filename)
	end
end


function preview.close()
	if preview.buffer ~= nil then
		vim.cmd(string.format('bwipeout! %s', preview.buffer))
	end
	preview.buffer = nil
	preview.window = nil
	type = nil
	if buffers then
		for _, buffer in pairs(buffers) do
			if not buffer.loaded then
				vim.cmd(string.format('bdelete! %s', buffer.bufnr))
			end
		end
		buffers = nil
	end
	stopCurrentJob()
	-- collectgarbage()
end

return preview
