local M = {}

local api = vim.api
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'

local prompt = require'popfix.prompt'
local list = require'popfix.list'
M.closed = true
local originalWindow = nil
local listNamespace = api.nvim_create_namespace('popfix.prompt_popup')

local function plainSearchHandler(str)
	print(str)
end

function M.close_selected()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	mappings.free(list.buffer)
	list.close()
	prompt.close()
	api.nvim_set_current_win(originalWindow)
	originalWindow = nil
	action.close(index, line, true)
	M.closed = true
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
	originalWindow = nil
	action.close(index, line, false)
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

function M.select_next()
	list.select_next()
	selectionHandler()
end

function M.select_prev()
	list.select_prev()
	selectionHandler()
end

local function popup_cursor(opts)
	local curWinHeight = api.nvim_win_get_height(0)
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
	--TODO: better width strategy
	opts.prompt.width = opts.width or 40
	if not list.new(opts.list) then
		return false
	end
	if not prompt.new(opts.prompt) then
		list.close()
		return false
	end
	return true
end

local function popup_editor(opts)
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
	if not list.new(opts.list) then
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
	if not prompt.new(opts.prompt) then
		list.close()
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
	local editorHeight = api.nvim_get_option("lines")
	local maximumHeight = editorHeight - 5
	if opts.height > maximumHeight then
		opts.height = maximumHeight
	end
	opts.list.height = opts.height
	if not list.newSplit(opts.list) then
		return false
	end
	opts.prompt.row = editorHeight - opts.height - 5
	opts.prompt.col = 1
	opts.prompt.width = math.floor(api.nvim_win_get_width(list.window) / 2)
	if not prompt.new(opts.prompt) then
		list.close()
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
	elseif opts.mode == 'cursor' then
		if not popup_cursor(opts) then
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
