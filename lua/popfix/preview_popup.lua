local preview = require'popfix.preview'
local list = require'popfix.list'
local action = require'popfix.action'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local Job = require'popfix.job'
local util = require'popfix.util'
local api = vim.api

local M = {}

local listNamespace = api.nvim_create_namespace('popfix.preview_popup')

local function close(self, bool)
	if self.job then
		self.job:shutdown()
		self.job = nil
	end
	local line = self.action:getCurrentLine()
	local index = self.action:getCurrentIndex()
	mappings.free(self.list.buffer)
	autocmd.free(self.list.buffer)
	self.list:close()
	self.preview:close()
	if self.splitWindow then
		api.nvim_win_close(self.splitWindow, true)
		self.splitWindow = nil
	end
	if api.nvim_win_is_valid(self.originalWindow) then
		api.nvim_set_current_win(self.originalWindow)
	end
	self.originalWindow = nil
	self.action:close(index, line, bool)
	self.list = nil
	self.preview = nil
	self.action = nil
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
		local data = self.action:select(line, self.list:getCurrentLine())
		if data ~= nil then
			self.preview:writePreview(data)
		end
	end
end

local function popup_editor(self, opts)
	local editorWidth = api.nvim_get_option('columns')
	local editorHeight = api.nvim_get_option("lines")
	opts.list.height = opts.height or math.ceil((editorHeight * 0.8 - 4) )
	opts.height = opts.list.height
	--TODO: better resize strategy
	if 2 * editorHeight > editorWidth then
		opts.list.height = opts.height or math.ceil((editorHeight * 0.8 - 4) / 2)
	end
	if opts.height >= api.nvim_get_option('lines') - 4 then
		print('no enough space to draw popup')
		return
	end
	if opts.width then
		opts.list.width = math.floor(opts.width / 2)
	else
		opts.list.width = math.ceil(editorWidth * 0.8 / 2)
		opts.width = math.ceil(editorWidth * 0.8) + 1
	end
	if opts.width >= api.nvim_get_option('columns') - 4 then
		print('no enough space to draw popup')
		return
	end
	opts.list.row = math.ceil((editorHeight - opts.list.height) / 2 - 1)
	opts.list.col = math.ceil((editorWidth - 2 * opts.list.width) / 2)
	self.list = list:new(opts.list)
	if not self.list then
		return false
	end
	opts.preview.width = opts.list.width
	opts.preview.height = opts.list.height
	opts.preview.row = opts.list.row
	opts.preview.col = opts.list.col + opts.list.width
	self.preview = preview:new(opts.preview)
	if not self.preview then
		self.list:close()
		return false
	end
	return true
end

local function popup_split(self, opts)
	opts.list.height = opts.height or 12
	opts.height = opts.list.height
	if opts.height >= api.nvim_get_option('lines') - 4 then
		print('no enough space to draw popup')
		return
	end
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
	return true
end

function M:new(opts)
	self.__index = self
	local obj = {}
	setmetatable(obj, self)
	obj.action = action:register(opts.callbacks)
	if opts.data == nil then
		print "nil data"
		return false
	end
	if opts.mode == 'cursor' then
		print 'cursor mode is not supported for preview! (yet)'
	end
	if opts.list == nil or opts.preview == nil then
		print 'No attributes found'
		return false
	end
	opts.preview.mode = opts.mode
	opts.preview.list_border = opts.list.border
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
	local nested_autocmds = {
		['BufWipeout,BufDelete,BufLeave'] = obj.close_cancelled,
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
					obj.list:addData({line})
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
		obj.list:setData(opts.data, 0, -1)
		autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
		autocmd.addCommand(obj.list.buffer, non_nested_autocmds, obj)
	end
	local default_keymaps = {
		n = {
			['q'] = obj.close_cancelled,
			['<Esc>'] = obj.close_cancelled,
			['<CR>'] = obj.close_selected
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
	return true
end

function M:select_next()
	self.list:select_next()
end

function M:select_prev()
	self.list:select_prev()
end

return M
