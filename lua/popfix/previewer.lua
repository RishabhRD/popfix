local floating_win = require'popfix.floating_win'
local api = vim.api

local previewer = {}
local previewNamespace = api.nvim_create_namespace('popfix.previewer')

local buf = nil
local win = nil
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

function previewer.new(opts, typeHint, tp)
	previewer.close()
	local win_buf = floating_win.create_win(opts, tp)
	currentTerminalJob = nil
	type = typeHint
	win = win_buf.win
	buf = win_buf.buf
	api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
	api.nvim_win_set_option(win, 'wrap', false)
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
		api.nvim_set_current_win(win)
		vim.cmd('set nomod')
		stopCurrentJob()
		currentTerminalJob = vim.fn.termopen(data.cmd, opts)
		api.nvim_set_current_win(cur_win)
	elseif type == 'buffer' then
		api.nvim_buf_set_lines(buf, 0, -1, false, data.lines or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(buf, previewNamespace,
			"Visual", data.line, 0, -1)
		end
	else
		print('Invalid preview type')
		return
	end
end

function previewer.close()
	if buf ~= nil then
		api.nvim_command(string.format('bwipeout! %s', buf))
	end
	buf = nil
	win = nil
	type = nil
	stopCurrentJob()
end

return previewer
