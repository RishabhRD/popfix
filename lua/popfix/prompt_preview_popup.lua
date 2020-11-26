local M = {}

local fzy = require'popfix.fzy'
local manager = require'popfix.list_manager'
local FuzzyEngine = require'popfix.fuzzy_engine'
local api = vim.api
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local prompt = require'popfix.prompt'
local list = require'popfix.list'
local preview = require'popfix.preview'
local util = require'popfix.util'

local function close(self, bool)
	if self.closed then return end
	self.closed = true
	if self.job then
		self.job:shutdown()
		self.job = nil
	end
	local line = self.action:getCurrentLine()
	local index = self.action:getCurrentIndex()
	mappings.free(self.list.buffer)
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
		self.action:close(index, line, bool)
	end)
end

function M:close_selected()
	close(self, true)
end

function M:close_cancelled()
	close(self, false)
end

function M:select_next()
	self.manager:select_next()
end

function M:select_prev()
	self.manager:select_prev()
end

local function popup_editor(self, opts)
	local editorWidth = api.nvim_get_option('columns')
	local editorHeight = api.nvim_get_option("lines")
	opts.list.height = opts.height or math.ceil((editorHeight * 0.8 - 4)) - 1
	opts.height = opts.list.height
	opts.preview.height = opts.list.height + 1
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
	opts.prompt.list_border = opts.list.border
	opts.list.row = math.ceil((editorHeight - opts.list.height) / 2 - 1)
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
	self.__index = self
	local obj = {}
	setmetatable(obj, self)
	if opts.data == nil or #opts.data == 0 then
		print 'nil data'
		return false
	end
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
	obj.action = action:register(opts.callbacks)
	local nested_autocmds = {
		['BufLeave'] = obj.close_cancelled,
		['nested'] = true,
		['once'] = true
	}
	autocmd.addCommand(obj.prompt.buffer, nested_autocmds, obj)
	if type(opts.data) == 'string' then
		local cmd, args = util.getArgs(opts.data)
		obj.manager = manager:new({
			preview = obj.preview,
			list = obj.list,
			action = obj.action,
			renderLimit = 45,
			highlightingFunction = fzy.positions,
		})
		obj.fuzzyEngine = FuzzyEngine:new({
			cmd = cmd,
			args = args,
			scoringFunction = fzy.score,
			filterFunction = fzy.has_match,
			prompt = obj.prompt,
			manager = obj.manager,
		})
		obj.manager.sortedList = obj.fuzzyEngine.sortedList
		obj.manager.originalList = obj.fuzzyEngine.list
		obj.fuzzyEngine:run()
	else
		obj.manager = manager:new({
			preview = obj.preview,
			list = obj.list,
			action = obj.action,
			renderLimit = 45,
			highlightingFunction = fzy.positions,
		})
		obj.fuzzyEngine = FuzzyEngine:new({
			luaTable = opts.data,
			scoringFunction = fzy.score,
			filterFunction = fzy.has_match,
			prompt = obj.prompt,
			manager = obj.manager,
		})
		obj.manager.sortedList = obj.fuzzyEngine.sortedList
		obj.manager.originalList = obj.fuzzyEngine.list
		obj.fuzzyEngine:run()
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
