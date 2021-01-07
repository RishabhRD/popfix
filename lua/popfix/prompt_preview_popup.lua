local M = {}
M.__index = M

local util = require'popfix.util'
local sorter = require'popfix.sorter'
local manager = require'popfix.list_manager'
local FuzzyEngine = require'popfix.fuzzy_engine'
local api = vim.api
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local prompt = require'popfix.prompt'
local list = require'popfix.list'
local preview = require'popfix.preview'

function M:close(callback)
    if self.closed then return end
    self.closed = true
    if self.fuzzyEngine then
	self.fuzzyEngine:close()
	self.fuzzyEngine = nil
    end
    local line = self.action:getCurrentLine()
    local index = self.action:getCurrentIndex()
    mappings.free(self.list.buffer)
    self.manager = nil
    vim.schedule(function()
	self.list:close()
	self.prompt:close()
	self.preview:close()
	if self.splitWindow then
	    api.nvim_win_close(self.splitWindow, true)
	    self.splitWindow = nil
	end
	if api.nvim_win_is_valid(self.originalWindow) then
	    api.nvim_set_current_win(self.originalWindow)
	end
	vim.cmd('stopinsert')
	self.action:close(index, line, callback)
    end)
end

function M:select_next(callback)
    self.manager:select_next(callback)
end

function M:select_prev(callback)
    self.manager:select_prev(callback)
end

local function popup_editor(self, opts)
    local editorWidth = api.nvim_get_option('columns')
    local editorHeight = api.nvim_get_option("lines")
    opts.list.height = opts.height or math.ceil((editorHeight * 0.9 - 4)) - 1
    opts.height = opts.list.height
    opts.preview.height = opts.list.height + 1
    if 2 * editorHeight > editorWidth then
	opts.list.height = opts.height or math.ceil((editorHeight * 0.9 - 4) / 2)
    end
    if opts.height >= api.nvim_get_option('lines') - 4 then
	print('no enough space to draw popup')
	return
    end
    if opts.width then
	opts.list.width = math.floor(opts.width / 2)
    else
	opts.list.width = math.ceil(editorWidth * 0.85 / 2)
	opts.width = math.ceil(editorWidth * 0.85) + 1
    end
    if opts.width >= api.nvim_get_option('columns') - 4 then
	print('no enough space to draw popup')
	return
    end
    opts.prompt.list_border = opts.list.border
    opts.list.row = math.ceil((editorHeight - opts.list.height) / 2 + 1)
    opts.list.col = math.ceil((editorWidth - 2 * opts.list.width) / 2)
    opts.prompt.width = opts.list.width
    opts.prompt.row = opts.list.row - 1
    opts.prompt.col = opts.list.col

    if opts.prompt.border then
	opts.list.height = opts.list.height - 2
	opts.list.row = opts.list.row + 1
    end
    if opts.list.border then
	opts.list.height = opts.list.height - 2
	opts.list.row = opts.list.row + 1
    end
    opts.preview.col = opts.prompt.col + opts.prompt.width
    opts.preview.row = opts.prompt.row
    opts.preview.width = opts.list.width
    if opts.list.border and not opts.prompt.border then
	opts.preview.row = opts.preview.row + 1
    end
    if opts.list.border or opts.prompt.border then
	opts.preview.col = opts.preview.col + 1
	opts.preview.row = opts.preview.row - 1
    end
    if opts.preview.border then
	opts.preview.col = opts.preview.col + 1
    end
    self.list = list:new(opts.list)
    if not self.list then
	return false
    end
    self.prompt = prompt:new(opts.prompt)
    if not self.prompt then
	self.list:close()
	return false
    end
    self.preview = preview:new(opts.preview)
    if not self.preview then
	self.list:close()
	self.prompt:close()
	return false
    end
    return true
end

local function popup_split(self, opts)
    opts.height = opts.height or 12
    if opts.height >= api.nvim_get_option('lines') - 4 then
	print('no enough space to draw popup')
	return
    end
    opts.list.height = opts.height
    self.list = list:newSplit(opts.list)
    if not self.list then
	return false
    end
    api.nvim_set_current_win(self.list.window)
    vim.cmd('vnew')
    if not api.nvim_get_option('splitright') then
	vim.cmd('wincmd r')
    end
    self.splitWindow = api.nvim_get_current_win()
    local splitBuffer = api.nvim_get_current_buf()
    api.nvim_buf_set_option(splitBuffer, 'bufhidden', 'wipe')
    api.nvim_set_current_win(self.originalWindow)
    opts.preview.width = api.nvim_win_get_width(self.list.window)
    opts.preview.height = api.nvim_win_get_height(self.list.window)
    opts.preview.row = api.nvim_win_get_position(self.list.window)[1]
    opts.preview.col = opts.preview.width
    self.preview = preview:new(opts.preview)
    if not self.preview then
	self.list:close()
	api.nvim_win_close(self.splitWindow)
	return false
    end
    local editorHeight = api.nvim_get_option("lines")
    opts.prompt.row = editorHeight - opts.height - 5
    opts.prompt.col = 1
    opts.prompt.width = math.floor(api.nvim_win_get_width(self.list.window))
    self.prompt = prompt:new(opts.prompt)
    if not self.prompt then
	self.list:close()
	api.nvim_win_close(self.splitWindow, true)
	self.preview:close()
	return false
    end
    return true
end

function M:new(opts)
    local obj = {}
    setmetatable(obj, self)
    if opts.data == nil then
	print 'nil data'
	return false
    end
    obj.close_on_error = opts.close_on_error
    opts.list = opts.list or {}
    opts.prompt.search_type = opts.prompt.search_type or 'plain'
    obj.originalWindow = api.nvim_get_current_win()
    if opts.mode == 'split' then
	if not popup_split(obj, opts) then
	    obj.originalWindow = nil
	    return false
	end
    elseif opts.mode == 'editor' then
	if not popup_editor(obj, opts) then
	    obj.originalWindow = nil
	    return false
	end
    end
    obj.action = action:new(opts.callbacks)
    local nested_autocmds
    if opts.close_on_bufleave then
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
    autocmd.addCommand(obj.prompt.buffer, nested_autocmds, obj)
    if opts.sorter then
	obj.sorter = opts.sorter
    else
	obj.sorter = sorter:new_fzy_sorter(false)
    end
    -- free the resource on error
    local error_handler = function(err, line)
	if err then
	    if obj.close_on_error then
		vim.schedule(function()
		    obj:close(function()
			util.printError(line)
		    end)
		end)
	    end
	elseif line then
	    if obj.close_on_error then
		vim.schedule(function()
		    obj:close(function()
			util.printError(line)
		    end)
		end)
	    end
	end
    end
    obj.manager = manager:new({
	preview = obj.preview,
	list = obj.list,
	action = obj.action,
	renderLimit = opts.list.height,
	highlightingFunction = obj.sorter.highlightingFunction,
	caseSensitive = obj.sorter.caseSensitive
    })
    if opts.fuzzyEngine then
	obj.fuzzyEngine = opts.fuzzyEngine
    else
	obj.fuzzyEngine = FuzzyEngine:new_SingleExecutionEngine()
    end
    local textChanged, setData = obj.fuzzyEngine:run({
	data = opts.data,
	sorter = obj.sorter,
	manager = obj.manager,
	currentPromptText = obj.prompt:getCurrentPromptText(),
	error_handler = error_handler,
	on_job_complete = opts.callbacks.on_job_complete
    })
    obj._set_data = setData
    obj.prompt:registerTextChanged(textChanged)
    api.nvim_set_current_win(obj.prompt.window)
    if opts.keymaps then
	mappings.add_keymap(obj.prompt.buffer, opts.keymaps, obj)
    end
    return obj
end

function M:set_data(data)
    self._set_data(data)
end

function M:get_current_selection()
    return self.action:getCurrentIndex(), self.action:getCurrentLine()
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
