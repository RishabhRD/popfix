local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local list = require'popfix.list'
local api = vim.api

local M = {}
M.closed = true
local listNamespace = api.nvim_create_namespace('popfix.popup')

local originalWindow = nil

function M.close_selected()
	if action.freed() then return end
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	api.nvim_set_current_win(originalWindow)
	list.close()
	originalWindow = nil
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, true)
	M.closed = true
end

function M.close_cancelled()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	api.nvim_set_current_win(originalWindow)
	list.close()
	originalWindow = nil
	action.close(index, line, false)
	M.closed = true
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = list.getCurrentLineNumber()
	if oldIndex ~= line then
		api.nvim_buf_clear_namespace(list.buffer, listNamespace, 0, -1)
		api.nvim_buf_add_highlight(list.buffer, listNamespace, "Visual", line - 1,
		0, -1)
		action.select(line, list.getCurrentLine())
	end
end

local function popup_cursor(opts)
	--TODO: handle edge cases
	opts.list.row = 1
	opts.list.col = 0
	opts.list.relative = "cursor"
	if opts.list.border then
		opts.list.row = opts.list.row + 1
	end
	if not list.new(opts.list) then
		return false
	end
	return true
end

local function popup_split(opts)
	if not list.newSplit(opts.list) then
		return false
	end
	return true
end

local function popup_editor(opts)
	local editorWidth = api.nvim_get_option('columns')
	local editorHeight = api.nvim_get_option("lines")
	opts.list.height = opts.height or math.ceil(editorHeight * 0.8 - 4)
	opts.list.width = opts.width or math.ceil(editorWidth * 0.8)
	opts.list.row = math.ceil((editorHeight - opts.list.height) /2 - 1)
	opts.list.col = math.ceil((editorWidth - opts.list.width) /2)
	if not list.new(opts.list) then
		return false
	end
	return true
end

function M.popup(opts)
	if opts.data == nil then
		print "nil data"
		return false
	end
	if opts.mode == nil then opts.mode = 'split' end
	if opts.list == nil then
		opts.list = {}
	end
	originalWindow = api.nvim_get_current_win()
	--TODO: better width strategy
	opts.list.width = opts.width or 40
	opts.list.height = opts.height
	if opts.mode == 'cursor' then
		if not popup_cursor(opts) then
			originalWindow = nil
			return false
		end
	elseif opts.mode == 'split' then
		if not popup_split(opts) then
			originalWindow = nil
			return false
		end
	elseif opts.mode == 'editor' then
		if not popup_editor(opts) then
			originalWindow = nil
			return false
		end
	end
	list.setData(opts.data, 0, -1)
	action.register(opts.callbacks)
	local default_keymaps = {
		n = {
			['q'] = M.close_cancelled,
			['<Esc>'] = M.close_cancelled,
			['<CR>'] = M.close_selected
		}
	}
	local nested_autocmds = {
		['BufWipeout,BufDelete,BufLeave'] = M.close_cancelled,
	}
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(list.buffer, nested_autocmds, true)
	autocmd.addCommand(list.buffer, non_nested_autocmds, false)
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
	mappings.add_keymap(list.buffer, opts.keymaps)
	api.nvim_set_current_win(list.window)
	M.closed = false
	return true
end

function M.select_next()
	list.select_next()
end

function M.select_prev()
	list.select_prev()
end

return M
