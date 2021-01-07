local M = {}
M.__index = M
local api = vim.api
local prompt = require'popfix.prompt'
local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'


function M:close(callback)
    if self.closed then return end
    self.closed = true
    local line = self.prompt:getCurrentPromptText()
    mappings.free(self.prompt.buffer)
    autocmd.free(self.prompt.buffer)
    vim.schedule(function()
	if api.nvim_win_is_valid(self.originalWindow) then
	    api.nvim_set_current_win(self.originalWindow)
	end
	self.prompt:close()
	self.action:close(0, line, callback)
    end)
end

local function popup_editor(self, opts)
    local editorWidth = api.nvim_get_option('columns')
    local editorHeight = api.nvim_get_option("lines")
    opts.prompt.width = opts.width or math.ceil(editorWidth * 0.8)
    opts.prompt.row = math.ceil((editorHeight - 1) / 2 - 5)
    opts.prompt.col = math.ceil((editorWidth - opts.prompt.width) /2)
    self.prompt = prompt:new(opts.prompt)
    if not self.prompt then
	return false
    end
    return true
end

local function popup_cursor(self, opts)
    opts.prompt.row = 1
    opts.prompt.col = 0
    opts.prompt.relative = "cursor"
    if opts.prompt.border then
	opts.prompt.row = opts.prompt.row + 1
    end
    self.prompt = prompt:new(opts.prompt)
    if not self.prompt then
	return false
    end
    return true
end

function M:new(opts)
    local obj = {}
    setmetatable(obj, self)
    obj.originalWindow = api.nvim_get_current_win()
    if opts.mode == 'editor' then
	if not popup_editor(obj, opts) then
	    return false
	end
    elseif opts.mode == 'cursor' then
	if not popup_cursor(obj, opts) then
	    return false
	end
    end
    obj.action = action:new(opts.callbacks)
    local nested_autocmds
    if nested_autocmds then
	nested_autocmds = {
	    ['BufUnload,BufLeave'] = obj.close,
	    ['nested'] = true,
	    ['once'] = true
	}
    else
	nested_autocmds = {
	    ['BufUnload'] = obj.close,
	    ['nested'] = true,
	    ['once'] = true
	}
    end
    if opts.keymaps then
	mappings.add_keymap(obj.prompt.buffer, opts.keymaps, obj)
    end
    autocmd.addCommand(obj.prompt.buffer, nested_autocmds, obj)
    api.nvim_set_current_win(obj.prompt.window)
    return obj
end

function M:set_prompt_text(text)
    vim.schedule(function()
	self.prompt:setPromptText(text)
    end)
end

function M:get_prompt_text()
    return self.prompt:getCurrentPromptText()
end

return M
