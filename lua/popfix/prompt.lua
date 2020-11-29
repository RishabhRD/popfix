local floating_win = require'popfix.floating_win'
local autocmd = require'popfix.autocmd'

local api = vim.api

local prompt = {}

function prompt:getCurrentPromptText()
    local current_prompt = vim.api.nvim_buf_get_lines(self.buffer, 0, 1, false)[1]
    return string.sub(current_prompt, #self.prefix + 1)
end

local function triggerTextChanged(self)
    self.textChanged(self:getCurrentPromptText())
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
    self.returningPrefix = opts.prompt_text
    vim.fn.prompt_setprompt(obj.buffer, opts.prompt_text..'> ')
    if opts.callback then
	local nested_autocmds = {
	    ['TextChangedI,TextChangedP,TextChanged'] = triggerTextChanged,
	    ['nested'] = true
	}
	autocmd.addCommand(obj.buffer, nested_autocmds, obj)
	obj.textChanged = opts.callback
    end
    vim.cmd(string.format('autocmd BufEnter,WinEnter <buffer=%s>  startinsert', obj.buffer))
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
    autocmd.remove(self.buffer, 'TextChangedI,TextChangedP,TextChanged', {
	nested = true,
    })
    local nested_autocmds = {
	['TextChangedI,TextChangedP,TextChanged'] = triggerTextChanged,
	['nested'] = true
    }
    autocmd.addCommand(self.buffer, nested_autocmds, self)
    self.textChanged = func
end

function prompt:setPrompt(text)
    -- TODO: I guess there is a bug in neovim here.
    -- Prompt text is being updated here but neovim
    -- nvim_buf_get_line is not giving updated response.
    self.returningPrefix = text
    vim.fn.prompt_setprompt(self.buffer, text..'> ')
end

function prompt:getPrompt()
    return self.returningPrefix
end

return prompt
