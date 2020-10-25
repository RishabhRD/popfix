local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'

local api = vim.api

local prompt = {}
prompt.buffer = nil
prompt.window = nil
local prefix = nil
local textChanged = nil

local function getCurrentPromptText()
    local current_prompt = vim.api.nvim_buf_get_lines(prompt.buffer, 0, 1, false)[1]
	return string.sub(current_prompt, #prefix + 1)
end

local function triggerTextChanged()
	textChanged(getCurrentPromptText())
end


function prompt.new(opts)
	if opts.border == nil then
		opts.border = false
	end
	opts.title = opts.title or ''
	opts.height = 1
	opts.prompt_text = opts.prompt_text or ''
	prefix = opts.prompt_text .. '> '
	local win_buf = floating_win.create_win(opts, opts.mode)
	prompt.buffer = win_buf.buf
	prompt.window = win_buf.win
	if opts.coloring == nil or opts.coloring == false then
		api.nvim_win_set_option(prompt.window, 'winhl', 'Normal:PromptNormal')
	end
	api.nvim_buf_set_option(prompt.buffer, 'bufhidden', 'hide')
	api.nvim_win_set_option(prompt.window, 'wrap', false)
	api.nvim_win_set_option(prompt.window, 'number', false)
	api.nvim_win_set_option(prompt.window, 'relativenumber', false)
	api.nvim_buf_set_option(prompt.buffer, 'buftype', 'prompt')
	vim.fn.prompt_setprompt(prompt.buffer, opts.prompt_text..'> ')
	local nested_autocmds = {
		['TextChangedI,TextChangedP,TextChanged'] = triggerTextChanged
	}
	if opts.callback then
		autocmd.addCommand(prompt.buffer, nested_autocmds, true)
		textChanged = opts.callback
	end
	vim.cmd(string.format('autocmd BufEnter,WinEnter <buffer=%s>  startinsert', prompt.buffer))
return true
end

function prompt.close()
	if prompt.buffer ~= nil then
		if api.nvim_buf_is_loaded(prompt.buffer) then
			local buf = prompt.buffer
			vim.schedule(function()
				vim.cmd(string.format('bwipeout! %s', buf))
			end)
		end
	end
	autocmd.free(prompt.buffer)
	prompt.buffer = nil
	prompt.window = nil
	prefix = nil
	textChanged = nil
end


function prompt.setPromptText(text)
	vim.fn.prompt_setprompt(prompt.buffer, text..'> ')
	prefix = text..'> '
end

return prompt
