local floating_win = require'popfix.floating_win'
local api = vim.api

local previewer = {}
local previewNamespace = api.nvim_create_namespace('popfix.previewer')

previewer.buffer = nil
previewer.window = nil
local type = nil
local currentTerminalJob = nil

local function isCurrentJobRunning()
	if currentTerminalJob == nil then return false end
	return vim.fn.jobwait({currentTerminalJob}, 0)[1] == -1
end

local function stopCurrentJob()
	if currentTerminalJob ~= nil then
		if isCurrentJobRunning() then
			vim.fn.jobstop(currentTerminalJob)
		end
		currentTerminalJob = nil
	end
end

function previewer.new(opts)
	if opts.type == nil then
		print 'unknown terminal type'
		return false
	end
	if opts.border == nil then
		opts.border = true
	end
	opts.title = opts.title or ''
	local win_buf
	win_buf = floating_win.create_win(opts, opts.tp)
	currentTerminalJob = nil
	type = opts.type
	previewer.window = win_buf.win
	previewer.buffer = win_buf.buf
	if opts.numbering then opts.numbering = false end
	if opts.coloring == nil or opts.coloring == false then
		api.nvim_win_set_option(previewer.window, 'winhl', 'Normal:ListNormal')
	end
	api.nvim_win_set_option(previewer.window, 'number', opts.numbering)
	api.nvim_buf_set_option(previewer.buffer, 'bufhidden', 'wipe')
	api.nvim_win_set_option(previewer.window, 'wrap', false)
	return true
end

function previewer.writePreview(data)
	if type == 'terminal' then
		-- TODO. terminal windows are waiting to close. Close them buddy ;)
		-- memory leak here.
		local cwd = data.cwd
		local opts = {
			cwd = cwd or vim.fn.getcwd()
		}
		local cur_win = api.nvim_get_current_win()
		api.nvim_set_current_win(previewer.window)
		vim.cmd('set nomod')
		stopCurrentJob()
		currentTerminalJob = vim.fn.termopen(data.cmd, opts)
		api.nvim_set_current_win(cur_win)
	elseif type == 'buffer' then
		api.nvim_buf_set_lines(previewer.buffer, 0, -1, false, data.lines or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(previewer.buffer, previewNamespace,
			"Visual", data.line, 0, -1)
		end
	else
		print('Invalid preview type')
		return
	end
end

function previewer.close()
	if previewer.buffer ~= nil then
		api.nvim_command(string.format('bwipeout! %s', previewer.buffer))
	end
	previewer.buffer = nil
	previewer.window = nil
	type = nil
	stopCurrentJob()
end

return previewer
