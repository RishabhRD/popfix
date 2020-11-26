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

local function close(self, bool)
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
		self.action:close(index, line, bool)
	end)
end

function M:close_selected()
	close(self, true)
end

function M:close_cancelled()
	close(self, false)
end

local function selectionHandler(self)
	local oldIndex = self.action:getCurrentIndex()
	local line = self.list:getCurrentLineNumber()
	if oldIndex ~= line then
		api.nvim_buf_clear_namespace(self.list.buffer, listNamespace, 0, -1)
		api.nvim_buf_add_highlight(self.list.buffer, listNamespace, "Visual", line - 1,
		0, -1)
		self.action:select(line, self.list:getCurrentLine())
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
	obj.action = action:register(opts.callbacks)
	local nested_autocmds = {
		['BufWipeout,BufDelete,BufLeave'] = self.close_cancelled,
		['nested'] = true,
		['once'] = true
	}
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	if type(opts.data) == 'string' then
		local cmd, args = util.getArgs(opts.data)
		obj.job = Job:new{
			command = cmd,
			args = args,
			cwd = vim.fn.getcwd(),
			on_stdout = vim.schedule_wrap(function(_, line)
				if obj.list then
					obj.list:addData({line}, listNamespace, obj.action)
					if not obj.first_added then
						obj.first_added = true
						autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
						autocmd.addCommand(obj.list.buffer, non_nested_autocmds, obj)
					end
				end
			end),
			on_exit = function()
				--TODO: is doing nil doesn't leak resources
				obj.job = nil
			end,
		}
		obj.job:start()
	else
		obj.list:setData(opts.data)
		autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
		autocmd.addCommand(obj.list.buffer, non_nested_autocmds, obj)
	end
	local default_keymaps = {
		n = {
			['q'] = self.close_cancelled,
			['<Esc>'] = self.close_cancelled,
			['<CR>'] = self.close_selected
		}
	}
	opts.keymaps = opts.keymaps or default_keymaps
	if opts.additional_keymaps then
		local i_maps = opts.additional_keymaps.i
		if i_maps then
			if not opts.keymaps.i then
				opts.keymaps.i = {}
			end
			for k, v in pairs(i_maps) do
				opts.keymaps.i[k] = v
			end
		end
		local n_maps = opts.additional_keymaps.n
		if n_maps then
			if not opts.keymaps.n then
				opts.keymaps.n = {}
			end
			for k, v in pairs(n_maps) do
				opts.keymaps.n[k] = v
			end
		end
	end
	mappings.add_keymap(obj.list.buffer, opts.keymaps, obj)
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

return M
