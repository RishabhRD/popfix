local M = {}


local sorter = require'popfix.sorter'
local api = vim.api
local manager = require'popfix.list_manager'
local FuzzyEngine = require'popfix.fuzzy_engine'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'

local prompt = require'popfix.prompt'
local list = require'popfix.list'
local util = require'popfix.util'

function M:close(callback)
	if self.closed then return end
	self.closed = true
	if self.fuzzyEngine then
		self.fuzzyEngine:close()
	end
	local line = self.action:getCurrentLine()
	local index = self.action:getCurrentIndex()
	mappings.free(self.prompt.buffer)
	vim.schedule(function()
		self.list:close()
		self.prompt:close()
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

local function popup_cursor(self, opts)
	local curWinHeight = api.nvim_win_get_height(self.originalWindow)
	local currentScreenLine = vim.fn.line('.') - vim.fn.line('w0') + 1
	local heightDiff = curWinHeight - currentScreenLine
	local popupHeight = opts.height + 1
	if curWinHeight <= popupHeight then
		print('Not enough space to draw popup')
		return false
	end
	opts.width = opts.width or 40
	if opts.width >= api.nvim_get_option('columns') - 4 then
		print('no enough space to draw popup')
		return false
	end
	if opts.list.border then
		popupHeight = popupHeight + 2
	end
	if opts.prompt.border then
		popupHeight = popupHeight + 2
	end
	if popupHeight >= heightDiff then
		opts.list.row = -popupHeight
		opts.prompt.row = -1
		if opts.prompt.border then
			opts.prompt.row = opts.prompt.row - 1
		end
		if opts.list.border then
			opts.list.row = opts.list.row + 1
		end
	else
		opts.list.row = 2
		opts.prompt.row = 1
		if opts.list.border then
			opts.list.row = opts.list.row + 1
		end
		if opts.prompt.border then
			opts.list.row = opts.list.row + 2
			opts.prompt.row = opts.prompt.row + 1
		end
	end
	opts.list.col = 0
	opts.list.relative = 'cursor'
	opts.list.height = opts.height
	opts.prompt.col = 0
	opts.prompt.relative = 'cursor'
	opts.prompt.width = opts.width
	opts.list.width = opts.width
	self.list = list:new(opts.list)
	if not self.list then
		return false
	end
	self.prompt = prompt:new(opts.prompt)
	if not self.prompt then
		self.list:close()
		return false
	end
	return true
end

local function popup_editor(self, opts)
	local editorWidth = api.nvim_get_option('columns')
	local editorHeight = api.nvim_get_option("lines")
	opts.list.height = opts.height or math.ceil(editorHeight * 0.8 - 4)
	if opts.list.height >= api.nvim_get_option('lines') - 4 then
		print('no enough space to draw popup')
		return
	end
	opts.list.width = opts.width or math.ceil(editorWidth * 0.8)
	if opts.list.width >= api.nvim_get_option('columns') - 4 then
		print('no enough space to draw popup')
		return
	end
	opts.list.row = math.ceil((editorHeight - opts.list.height) /2 - 1)
	opts.list.col = math.ceil((editorWidth - opts.list.width) /2) + 2
	self.list = list:new(opts.list)
	if not self.list then
		return false
	end
	if opts.list.border then
		opts.prompt.list_border = true
	end
	opts.prompt.width = opts.list.width
	opts.prompt.row = opts.list.row - 1
	if opts.list.border then
		opts.prompt.row = opts.prompt.row - 1
	end
	opts.prompt.col = opts.list.col
	if opts.prompt.border then
		opts.prompt.row = opts.prompt.row - 1
		if not opts.list.border then
			opts.prompt.width = opts.prompt.width - 2
			opts.prompt.col = opts.prompt.col + 1
		end
	end
	self.prompt = prompt:new(opts.prompt)
	if not self.prompt then
		self.list:close()
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
	local editorHeight = api.nvim_get_option("lines")
	local maximumHeight = editorHeight - 5
	if opts.height > maximumHeight then
		opts.height = maximumHeight
	end
	opts.list.height = opts.height
	self.list = list:newSplit(opts.list)
	if not self.list then
		return false
	end
	opts.prompt.row = editorHeight - opts.height - 5
	opts.prompt.col = 1
	opts.prompt.width = math.floor(api.nvim_win_get_width(self.list.window) / 2)
	self.prompt = prompt:new(opts.prompt)
	if not self.prompt then
		self.list:close()
		return false
	end
	return true
end

function M:new(opts)
	self.__index = self
	local obj = {}
	setmetatable(obj, self)
	if opts.data == nil then
		print 'nil data'
		return false
	end
	opts.list = opts.list or {}
	opts.prompt.search_type = opts.prompt.search_type or 'plain'
	opts.prompt.handlerInstance = obj
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
	elseif opts.mode == 'cursor' then
		if not popup_cursor(obj, opts) then
			obj.originalWindow = nil
			return false
		end
	end
	obj.action = action:new(opts.callbacks)
	local nested_autocmds
	if opts.close_on_bufleave then
		nested_autocmds = {
			['BufUnload,BufLeave'] = obj.close,
			['once'] = true,
			['nested'] = true
		}
	else
		nested_autocmds = {
			['BufUnload'] = obj.close,
			['once'] = true,
			['nested'] = true
		}
	end
	if opts.sorter then
		self.sorter = opts.sorter
	else
		self.sorter = sorter:new_fzy_sorter(false)
	end
	autocmd.addCommand(obj.prompt.buffer, nested_autocmds, obj)
	obj.manager = manager:new({
		list = obj.list,
		action = obj.action,
		renderLimit = opts.list.height,
		highlightingFunction = self.sorter.highlightingFunction,
		caseSensitive = self.sorter.caseSensitive
	})
	obj:set_data(opts.data)
	api.nvim_set_current_win(obj.prompt.window)
	if opts.keymaps then
		mappings.add_keymap(obj.prompt.buffer, opts.keymaps, obj)
	end
	obj.closed = false
	return obj
end

function M:set_data(data)
	if self.fuzzyEngine then
		self.fuzzyEngine:close()
		self.fuzzyEngine = nil
	end
	self.manager:clear()
	if data.cmd then
		local cmd, args = util.getArgs(data.cmd)
		self.fuzzyEngine = FuzzyEngine:new({
			cmd = cmd,
			args = args,
			scoringFunction = self.sorter.scoringFunction,
			filterFunction = self.sorter.filterFunction,
			currentPromptText = self.prompt:getCurrentPromptText(),
			manager = self.manager,
		})
	else
		self.fuzzyEngine = FuzzyEngine:new({
			luaTable = data,
			scoringFunction = self.scoringFunction,
			filterFunction = self.filterFunction,
			currentPromptText = self.prompt:getCurrentPromptText(),
			manager = self.manager,
		})
	end
	self.manager.sortedList = self.fuzzyEngine.sortedList
	self.manager.originalList = self.fuzzyEngine.list
	local textChanged = self.fuzzyEngine:run()
	self.prompt:registerTextChanged(textChanged)
end

function M:get_current_selection()
	return self.action:getCurrentIndex(), self.action:getCurrentLine()
end

function M:set_prompt_text(text)
	vim.schedule(function()
		self.prompt:setPromptText(text)
	end)
end

return M
