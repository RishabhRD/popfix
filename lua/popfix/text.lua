local M = {}
local api = vim.api
local prompt = require'popfix.prompt'
local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'


function M:close_cancelled()
	if self.closed then return end
	self.closed = true
	local line = self.prompt:getCurrentPromptText()
	mappings.free(self.prompt.buffer)
	autocmd.free(self.prompt.buffer)
	api.nvim_set_current_win(self.originalWindow)
	self.prompt:close()
	self.originalWindow = nil
	self.action:close(0, line, false)
	self.prompt = nil
	self.action = nil
end

function M:close_selected()
	if self.closed then return end
	self.closed = true
	local line = self.prompt:getCurrentPromptText()
	mappings.free(self.prompt.buffer)
	autocmd.free(self.prompt.buffer)
	api.nvim_set_current_win(self.originalWindow)
	self.prompt:close()
	self.originalWindow = nil
	self.action:close(0, line, true)
	self.prompt = nil
	self.action = nil
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

function M.new(self, opts)
	self.__index = self
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
	obj.closed = false
	obj.action = action:register(opts.callbacks)
	local default_keymaps = {
		n = {
			['q'] = obj.close_cancelled,
			['<Esc>'] = obj.close_cancelled,
			['<CR>'] = obj.close_selected
		},
		i = {
			['<C-c>'] = obj.close_cancelled,
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
	local nested_autocmds = {
		['BufLeave'] = obj.close_cancelled,
	}
	autocmd.addCommand(obj.prompt.buffer, nested_autocmds, true, obj)
	mappings.add_keymap(obj.prompt.buffer, opts.keymaps, obj)
	api.nvim_set_current_win(obj.prompt.window)
	return true
end

return M
