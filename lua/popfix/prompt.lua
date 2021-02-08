local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'

local api = vim.api

local prompt = {}

local promptHighlightNamespace = api.nvim_create_namespace('popfix.prompt_highlight')

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
    opts.highlight = opts.highlight or 'Normal'
    api.nvim_win_set_option(obj.window, 'winhl', 'Normal:'..opts.highlight)
    api.nvim_buf_set_option(obj.buffer, 'bufhidden', 'hide')
    api.nvim_win_set_option(obj.window, 'wrap', false)
    api.nvim_win_set_option(obj.window, 'number', false)
    api.nvim_win_set_option(obj.window, 'relativenumber', false)
    api.nvim_buf_set_option(obj.buffer, 'buftype', 'prompt')
    vim.fn.prompt_setprompt(obj.buffer, obj.prefix)
    opts.prompt_highlight = opts.prompt_highlight or 'Normal'
    obj.prompt_highlight = opts.prompt_highlight
    api.nvim_buf_add_highlight(obj.buffer, promptHighlightNamespace,
    obj.prompt_highlight, 0, 0, #obj.prefix)
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
  if vim.fn.pumvisible() ~= 0 then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-y>", true, true, true), 'n', true)
  end
    local buf = self.buffer
    vim.schedule(function()
    vim.cmd(string.format('bwipeout! %s', buf))
    end)
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
	local promptText = vim.api.nvim_buf_get_lines(self.buffer,
	first, last, false)[1]:sub(#self.prefix + 1)
	api.nvim_buf_add_highlight(self.buffer, promptHighlightNamespace,
	self.prompt_highlight, 0, 0, #self.prefix)
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
    local lineCount = api.nvim_buf_line_count(self.buffer)
    api.nvim_buf_set_lines(self.buffer, lineCount - 1, -1, false, {setLine})
    vim.cmd('startinsert')
    api.nvim_win_set_cursor(self.window, {1, #setLine})
end

return prompt
