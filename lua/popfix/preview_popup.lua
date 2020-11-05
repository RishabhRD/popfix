local preview = require'popfix.preview'
local list = require'popfix.list'
local action = require'popfix.action'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local api = vim.api

local M = {}

local splitWindow = nil
local originalWindow = nil
local listNamespace = api.nvim_create_namespace('popfix.preview_popup')
M.closed = true

function M.close_selected()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	list.close()
	preview.close()
	if splitWindow then
		api.nvim_win_close(splitWindow, true)
		splitWindow = nil
	end
	api.nvim_set_current_win(originalWindow)
	originalWindow = nil
	action.close(index, line, true)
	M.closed = true
end

function M.close_cancelled()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	list.close()
	preview.close()
	if splitWindow then
		api.nvim_win_close(splitWindow, true)
		splitWindow = nil
	end
	api.nvim_set_current_win(originalWindow)
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
		local data = action.select(line, list.getCurrentLine())
		if data ~= nil then
			preview.writePreview(data)
		end
	end
end

local function popup_editor(opts)
	local editorWidth = api.nvim_get_option('columns')
	local editorHeight = api.nvim_get_option("lines")
	opts.list.height = opts.height or math.ceil((editorHeight * 0.8 - 4) )
	--TODO: better resize strategy
	if 2 * editorHeight > editorWidth then
		opts.list.height = opts.height or math.ceil((editorHeight * 0.8 - 4) / 2)
	end
	if opts.width then
		opts.list.width = math.floor(opts.width / 2)
	else
		opts.list.width = math.ceil(editorWidth * 0.8 / 2)
	end
	opts.list.row = math.ceil((editorHeight - opts.list.height) / 2 - 1)
	opts.list.col = math.ceil((editorWidth - 2 * opts.list.width) / 2)
	if not list.new(opts.list) then
		return false
	end
	opts.preview.width = opts.list.width
	opts.preview.height = opts.list.height
	opts.preview.row = opts.list.row
	opts.preview.col = opts.list.col + opts.list.width
	if not preview.new(opts.preview) then
		list.close()
		return false
	end
	return true
end

local function popup_split(opts)
	opts.list.height = opts.height or 12
	if opts.height >= api.nvim_get_option('lines') - 4 then
		print('no enough space to draw popup')
		return
	end
	if not list.newSplit(opts.list) then
		return false
	end
	api.nvim_set_current_win(list.window)
	vim.cmd('vnew')
	splitWindow = api.nvim_get_current_win()
	local splitBuffer = api.nvim_get_current_buf()
	api.nvim_buf_set_option(splitBuffer, 'bufhidden', 'wipe')
	api.nvim_set_current_win(originalWindow)
	opts.preview.width = api.nvim_win_get_width(list.window)
	opts.preview.height = api.nvim_win_get_height(list.window)
	opts.preview.row = api.nvim_win_get_position(list.window)[1]
	opts.preview.col = opts.preview.width
	if not preview.new(opts.preview) then
		list.close()
		api.nvim_win_close(splitWindow)
		return false
	end
	return true
end

function M.popup(opts)
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
	originalWindow = api.nvim_get_current_win()
	if opts.mode == 'split' then
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
		['BufWipeout'] = M.close_cancelled,
		['BufDelete'] = M.close_cancelled,
		['BufLeave'] = M.close_cancelled
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
