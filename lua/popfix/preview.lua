local floating_win = require'popfix.floating_win'
local list = require'popfix.list'
local api = vim.api

local preview = {}
preview.buffer = nil
preview.window = nil

local previewNamespace = api.nvim_create_namespace('popfix.preview')
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

function preview.new(opts)
	if opts.type == nil then
		print 'unknown terminal type'
		return false
	end
	if opts.border == nil then
		opts.border = false
	end
	opts.title = opts.title or ''
	opts.height = api.nvim_win_get_height(list.window)
	opts.width = api.nvim_win_get_width(list.window)
	local width = api.nvim_get_option("columns")
	local height = api.nvim_get_option("lines")
	if opts.mode == 'editor' then
		opts.row = math.ceil((height - opts.height) / 2 - 1)
		opts.col = math.ceil((width - 2 * opts.width) / 2)
	elseif opts.mode == 'split' then
		local position = api.nvim_win_get_position(list.window)
		opts.row = position[1]
		opts.col = opts.width
	end
	if opts.list_border then
		if opts.mode == 'editor' then
			opts.col = opts.col + 1
			if not opts.border then
				opts.height = opts.height + 2
				opts.row = opts.row - 1
			end
		end
	end
	if opts.border then
		opts.col = opts.col + 1
		if not opts.list_border then
			opts.height = opts.height - 2
			opts.row = opts.row + 1
		end
	end
	opts.col = opts.col + opts.width
	local win_buf = floating_win.create_win(opts, opts.mode)
	currentTerminalJob = nil
	type = opts.type
	preview.window = win_buf.win
	preview.buffer = win_buf.buf
	if opts.numbering then opts.numbering = false end
	if opts.coloring == nil or opts.coloring == false then
		api.nvim_win_set_option(preview.window, 'winhl', 'Normal:ListNormal')
	end
	api.nvim_win_set_option(preview.window, 'number', opts.numbering)
	api.nvim_buf_set_option(preview.buffer, 'bufhidden', 'wipe')
	api.nvim_win_set_option(preview.window, 'wrap', false)
	return true
end

function preview.writePreview(data)
	if type == 'terminal' then
		-- TODO. terminal windows are waiting to close. Close them buddy ;)
		-- memory leak here.
		local cwd = data.cwd
		local opts = {
			cwd = cwd or vim.fn.getcwd()
		}
		local cur_win = api.nvim_get_current_win()
		api.nvim_set_current_win(preview.window)
		vim.cmd('set nomod')
		stopCurrentJob()
		currentTerminalJob = vim.fn.termopen(data.cmd, opts)
		api.nvim_set_current_win(cur_win)
	elseif type == 'buffer' then
		api.nvim_buf_set_lines(preview.buffer, 0, -1, false, data.lines or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(preview.buffer, previewNamespace,
			"Visual", data.line, 0, -1)
		end
	else
		print('Invalid preview type')
		return
	end
end

function preview.close()
	if preview.buffer ~= nil then
		api.nvim_command(string.format('bwipeout! %s', preview.buffer))
	end
	preview.buffer = nil
	preview.window = nil
	type = nil
	stopCurrentJob()
end

return preview
