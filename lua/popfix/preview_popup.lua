local preview = require'popfix.preview'
local list = require'popfix.list'
local action = require'popfix.action'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local api = vim.api

local M = {}

local splitWindow = nil
local originalWindow = nil

local function close_selected()
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
end

local function close_cancelled()
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
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = list.getCurrentLineNumber()
	if oldIndex ~= line then
		local data = action.select(line, list.getCurrentLine())
		if data ~= nil then
			preview.writePreview(data)
		end
	end
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
	opts.list.height = opts.height
	opts.list.mode = opts.mode
	opts.list.preview = true
	opts.preview.mode = opts.mode
	opts.preview.list_border = opts.list.border
	opts.mode = nil
	originalWindow = api.nvim_get_current_win()
	if not list.new(opts.list) then
		originalWindow = nil
		return false
	end
	if opts.preview.mode == 'split' then
		vim.cmd('vsplit')
		local tmpBuffer = api.nvim_create_buf(false, true)
		api.nvim_buf_set_option(tmpBuffer, 'bufhidden', 'wipe')
		api.nvim_win_set_buf(api.nvim_get_current_win(), tmpBuffer)
		splitWindow = api.nvim_get_current_win()
	end
	if not preview.new(opts.preview) then
		originalWindow = nil
		list.close()
		return false
	end
	list.setData(opts.data, 0, -1)
	action.register(opts.callbacks, opts.info)
	local default_keymaps = {
		n = {
			['q'] = close_cancelled,
			['<Esc>'] = close_cancelled,
			['<CR>'] = close_selected
		}
	}
	local nested_autocmds = {
		['BufWipeout'] = close_cancelled,
		['BufDelete'] = close_cancelled,
		['BufLeave'] = close_cancelled
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
			for k, v in pairs(i_maps) do
				opts.keymaps.i[k] = v
			end
		end
		local n_maps = opts.additional_keymaps.n
		if n_maps then
			for k, v in pairs(n_maps) do
				opts.keymaps.n[k] = v
			end
		end
	end
	mappings.add_keymap(list.buffer, opts.keymaps)
	api.nvim_set_current_win(list.window)
	return true
end

function M.getFunction(name)
	if name == 'close-selected' then
		return close_selected
	elseif name == 'close-cancelled' then
		return close_cancelled
	end
end

return M
