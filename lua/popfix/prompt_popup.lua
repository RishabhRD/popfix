local M = {}


local api = vim.api
local fzy = require'popfix.fzy'
local manager = require'popfix.list_manager'
local ListStore = require'popfix.list_store'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'

local prompt = require'popfix.prompt'
local list = require'popfix.list'
local util = require'popfix.util'
local listNamespace = api.nvim_create_namespace('popfix.prompt_popup')

local function close(self, bool)
	self.listStore:close()
	local line = self.action:getCurrentLine()
	local index = self.action:getCurrentIndex()
	mappings.free(self.list.buffer)
	self.list:close()
	self.prompt:close()
	if api.nvim_win_is_valid(self.originalWindow) then
		api.nvim_set_current_win(self.originalWindow)
	end
	self.originalWindow = nil
	self.action:close(index, line, bool)
	self.list = nil
	self.listStore = nil
	self.prompt = nil
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
		self.action:select(line, self.list:getCurrentLine())
	end
end

function M:select_next()
	self.list:select_next()
	selectionHandler(self)
end

function M:select_prev()
	self.list:select_prev()
	selectionHandler(self)
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
	if opts.data == nil or #opts.data == 0 then
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
	obj.action = action:register(opts.callbacks)
	local nested_autocmds = {
		['BufLeave'] = obj.close_cancelled,
		['once'] = true,
		['nested'] = true
	}
	autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
	if type(opts.data) == 'string' then
		local cmd, args = util.getArgs(opts.data)
		obj.manager = manager:new({
			list = obj.list,
			action = obj.action,
			renderLimit = 100
		})
		obj.listStore = ListStore:new({
			cmd = cmd,
			args = args,
			scoringFunction = fzy.score,
			filterFunction = fzy.has_match,
			highlightingFunction = fzy.positions,
			prompt = obj.prompt,
			manager = obj.manager,
		})
		obj.listStore:run()
	else
		-- for _, str in pairs(opts.data) do
		-- 	obj.promptHandler:addEntry(str)
		-- end
		-- obj.list:setData(opts.data, 0, -1)
		-- autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
		-- autocmd.addCommand(obj.list.buffer, non_nested_autocmd, obj)
	end
	local default_keymaps = {
		n = {
			['q'] = obj.close_cancelled,
			['<Esc>'] = obj.close_cancelled,
			['j'] = obj.select_next,
			['k'] = obj.select_prev,
			['<CR>'] = obj.close_selected
		},
		i = {
			['<C-c>'] = obj.close_cancelled,
			['<C-n>'] = obj.select_next,
			['<C-p>'] = obj.select_prev,
			['<CR>'] = obj.close_selected,
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
	api.nvim_set_current_win(obj.prompt.window)
	mappings.add_keymap(obj.prompt.buffer, opts.keymaps, obj)
	obj.closed = false
	return obj
end

return M
