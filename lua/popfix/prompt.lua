local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'

local api = vim.api

local prompt = {}

function prompt:getCurrentPromptText()
    local current_prompt = vim.api.nvim_buf_get_lines(self.buffer, 0, 1, false)[1]
    return string.sub(current_prompt, #self.prefix + 1)
end

function prompt:new(opts)
    self.__index = self
    local obj = {}
    setmetatable(obj, self)
    if opts.border == nil then
	opts.border = false
    end
    opts.title = opts.title or ''
    opts.height = 1
    opts.prompt_text = opts.prompt_text or ''
    obj.prefix = opts.prompt_text .. '> '
    local win_buf = floating_win.create_win(opts)
    obj.buffer = win_buf.buf
    obj.window = win_buf.win
    if opts.coloring == nil or opts.coloring == false then
	api.nvim_win_set_option(obj.window, 'winhl', 'Normal:PromptNormal')
    end
    api.nvim_buf_set_option(obj.buffer, 'bufhidden', 'hide')
    api.nvim_win_set_option(obj.window, 'wrap', false)
    api.nvim_win_set_option(obj.window, 'number', false)
    api.nvim_win_set_option(obj.window, 'relativenumber', false)
    api.nvim_buf_set_option(obj.buffer, 'buftype', 'prompt')
    vim.fn.prompt_setprompt(obj.buffer, obj.prefix)
    if opts.init_text then
	obj:setPromptText(opts.init_text)
	obj.insertStarted = true
    end
    local function startInsert()
	if not obj.insertStarted then
	    vim.cmd('startinsert')
	    obj.insertStarted = true
	end
    end
    autocmd.addCommand(obj.buffer, {['BufEnter,WinEnter'] = startInsert})
    return obj
end

function prompt:close()
    vim.cmd(string.format('bwipeout! %s', self.buffer))
    autocmd.free(self.buffer)
    self.buffer = nil
    self.window = nil
    self.prefix = nil
    self.textChanged = nil
end

function prompt:registerTextChanged(func)
    self.textChanged = func
    if not self.attached then
	local function on_lines(_, _, _, first, last)
	    local promptText = vim.trim(vim.api.nvim_buf_get_lines(self.buffer,
	    first, last, false)[1]:sub(#self.prefix))
	    self.textChanged(promptText)
	end
	vim.api.nvim_buf_attach(self.buffer, false, {
	    on_lines = on_lines,
	    on_changedtick = on_lines,
	})
	self.attached = true
    end
end

function prompt:setPromptText(line)
    local setLine = self.prefix..line
    api.nvim_buf_set_lines(self.buffer, 0, -1, false, {setLine})
    vim.cmd('startinsert')
    api.nvim_win_set_cursor(self.window, {1, #setLine})
end

return prompt
