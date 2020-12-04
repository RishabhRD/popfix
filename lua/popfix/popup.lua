local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local list = require'popfix.list'
local api = vim.api
local Job = require'popfix.job'
local util = require'popfix.util'

local M = {}
local listNamespace = api.nvim_create_namespace('popfix.popup')

--TODO: handle self.originalWindow in a more robust way.

function M:close(callback)
	if self.closed then return end
	self.closed = true
	if self.job then
		self.job:shutdown()
		self.job = nil
	end
	mappings.free(self.list.buffer)
	autocmd.free(self.list.buffer)
	vim.schedule(function()
		if api.nvim_win_is_valid(self.originalWindow) then
			api.nvim_set_current_win(self.originalWindow)
		end
		self.list:close()
		local line = self.action:getCurrentLine()
		local index = self.action:getCurrentIndex()
		self.action:close(index, line, callback)
	end)
end

local function selectionHandler(self, callback)
	local listSize = self.list:getSize()
	-- handle the situation where no element is there in list
	-- and the callback is triggered.
	if listSize == 0 then
		return
	end
	local oldIndex = self.action:getCurrentIndex()
	local line = self.list:getCurrentLineNumber()
	if oldIndex ~= line then
		api.nvim_buf_clear_namespace(self.list.buffer, listNamespace, 0, -1)
		api.nvim_buf_add_highlight(self.list.buffer, listNamespace, "Visual", line - 1,
		0, -1)
		self.action:select(line, self.list:getCurrentLine(), callback)
	end
end

local function popup_cursor(self, opts)
	local curWinHeight = api.nvim_win_get_height(0)
	local currentScreenLine = vim.fn.line('.') - vim.fn.line('w0') + 1
	local heightDiff = curWinHeight - currentScreenLine
	local listHeight = opts.list.height
	if opts.list.border then
		listHeight = listHeight + 2
	end
	if curWinHeight <= listHeight then
		print('Not enough space to draw popup')
		return false
	end
	--TODO: better width strategy
	opts.list.width = opts.list.width or 40
	if opts.list.width >= api.nvim_get_option('columns') - 4 then
		print('no enough space to draw popup')
		return
	end
	if listHeight >= heightDiff then
		opts.list.row = 0 - listHeight
	else
		opts.list.row = 1
	end
	opts.list.col = 0
	opts.list.relative = "cursor"
	if opts.list.border then
		opts.list.row = opts.list.row + 1
	end
	self.list = list:new(opts.list)
	if not self.list then
		return false
	end
	return true
end

local function popup_split(self, opts)
	opts.list.height = opts.list.height or 12
	if opts.list.height >= api.nvim_get_option('lines') - 4 then
		print('no enough space to draw popup')
		return
	end
	self.list = list:newSplit(opts.list)
	if not self.list then
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
		return false
	end
	opts.list.width = opts.width or math.ceil(editorWidth * 0.8)
	if opts.list.width >= api.nvim_get_option('columns') - 4 then
		print('no enough space to draw popup')
		return false
	end
	opts.list.row = math.ceil((editorHeight - opts.list.height) /2 - 1)
	opts.list.col = math.ceil((editorWidth - opts.list.width) /2)
	self.list = list:new(opts.list)
	if not self.list then
		return false
	end
	return true
end

function M:new(opts)
	self.__index = self
	local obj = {}
	setmetatable(obj, self)
	obj.close_on_error = opts.close_on_error
	if opts.data == nil then
		print "nil data"
		return false
	end
	if opts.mode == nil then opts.mode = 'split' end
	if opts.list == nil then
		opts.list = {}
	end
	obj.originalWindow = api.nvim_get_current_win()
	--TODO: better width strategy
	opts.list.width = opts.width or 40
	opts.list.height = opts.height
	if opts.mode == 'cursor' then
		if not popup_cursor(obj, opts) then
			obj.originalWindow = nil
			return false
		end
	elseif opts.mode == 'split' then
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
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
	autocmd.addCommand(obj.list.buffer, non_nested_autocmds, obj)
	obj:set_data(opts.data)
	if opts.keymaps then
		mappings.add_keymap(obj.list.buffer, opts.keymaps, obj)
	end
	api.nvim_set_current_win(obj.list.window)
	obj.closed = false
	return obj
end

function M:select_next()
	self.list:select_next()
end

function M:select_prev()
	self.list:select_prev()
end

function M:set_data(data)
	-- reset about any selection
	self.action.selection.index = nil
	self.action.selection.line = nil
	-- cancel any job running
	if self.job then
		self.job:shutdown()
		self.job = nil
	end
	if data.cmd then
		local cmd, args = util.getArgs(data.cmd)
		vim.schedule(function()
			self.list:clear()
		end)
		self.job = Job:new{
			command = cmd,
			args = args,
			cwd = data.cwd or vim.fn.getcwd(),
			on_stdout = vim.schedule_wrap(function(_, line)
				if self.list then
					self.list:addData({line}, listNamespace, self.action)
				end
			end),
			on_exit = function()
				--TODO: is doing nil doesn't leak resources
				self.job = nil
			end,
			on_stderr = function(err, line)
				if err then
					if self.close_on_error then
						vim.schedule(function()
							self:close(function()
								util.printError(line)
							end)
						end)
					end
				elseif line then
					if self.close_on_error then
						vim.schedule(function()
							self:close(function()
								util.printError(line)
							end)
						end)
					end
				end
			end
		}
		self.job:start()
	else
		vim.schedule(function()
			self.list:setData(data)
		end)
	end
end

function M:get_current_selection()
	return self.action:getCurrentIndex(), self.action:getCurrentLine()
end

return M
