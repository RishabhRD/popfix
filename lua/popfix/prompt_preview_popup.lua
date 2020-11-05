local M = {}

local api = vim.api
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'

local prompt = require'popfix.prompt'
local list = require'popfix.list'
local preview = require'popfix.preview'
M.closed = true
local originalWindow = nil
local listNamespace = api.nvim_create_namespace('popfix.prompt_preview_popup')
local splitWindow = nil

local function plainSearchHandler(str)
	print(str)
end

function M.close_selected()
	if M.closed then return end
	M.closed = true
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	mappings.free(list.buffer)
	list.close()
	prompt.close()
	preview.close()
	if splitWindow then
		api.nvim_win_close(splitWindow, true)
		splitWindow = nil
	end
	api.nvim_set_current_win(originalWindow)
	originalWindow = nil
	action.close(index, line, true)
end

function M.close_cancelled()
	if M.closed then return end
	M.closed = true
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	mappings.free(prompt.buffer)
	autocmd.free(prompt.buffer)
	api.nvim_set_current_win(originalWindow)
	list.close()
	prompt.close()
	preview.close()
	if splitWindow then
		api.nvim_win_close(splitWindow, true)
		splitWindow = nil
	end
	originalWindow = nil
	action.close(index, line, false)
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = list.getCurrentLineNumber()
	if oldIndex ~= line then
		api.nvim_buf_clear_namespace(list.buffer, listNamespace, 0, -1)
		api.nvim_buf_add_highlight(list.buffer, listNamespace, "Visual", line -
		1, 0, -1)
		local data = action.select(line, list.getCurrentLine())
		if data ~= nil then
			preview.writePreview(data)
		end
	end
end

function M.select_next()
	list.select_next()
	selectionHandler()
end

function M.select_prev()
	list.select_prev()
	selectionHandler()
end
local function popup_editor(opts)
	--TODO: handle edge cases
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
	if not list.new(opts.list) then
		return false
	end
	if not prompt.new(opts.prompt) then
		list.close()
		return false
	end
	if not preview.new(opts.preview) then
		list.close()
		prompt.close()
		return false
	end
	return true
end

local function popup_split(opts)
	opts.height = opts.height or 12
	if opts.height >= api.nvim_get_option('lines') - 4 then
		print('no enough space to draw popup')
		return
	end
	opts.list.height = opts.height
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
	local editorHeight = api.nvim_get_option("lines")
	opts.prompt.row = editorHeight - opts.height - 5
	opts.prompt.col = 1
	opts.prompt.width = math.floor(api.nvim_win_get_width(list.window))
	if not prompt.new(opts.prompt) then
		list.close()
		api.nvim_win_close(splitWindow, true)
		preview.close()
		return false
	end
	return true
end

function M.popup(opts)
	if opts.data == nil or #opts.data == 0 then
		print 'nil data'
		return false
	end
	opts.list = opts.list or {}
	opts.prompt.search_type = opts.prompt.search_type or 'plain'
	if opts.prompt.search_type == 'plain' then
		opts.prompt.callback = plainSearchHandler
	end
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
			['j'] = M.select_next,
			['k'] = M.select_prev,
			['<CR>'] = M.close_selected
		},
		i = {
			['<C-c>'] = M.close_cancelled,
			['<C-n>'] = M.select_next,
			['<C-p>'] = M.select_prev,
			['<CR>'] = M.close_selected,
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
		['BufLeave'] = M.close_cancelled,
	}
	local non_nested_autocmd = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(prompt.buffer, nested_autocmds, true)
	autocmd.addCommand(prompt.buffer, non_nested_autocmd, false)
	api.nvim_set_current_win(prompt.window)
	mappings.add_keymap(prompt.buffer, opts.keymaps)
	M.closed = false
	return true
end

return M
