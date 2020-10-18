local preview = require'popfix.preview'
local list = require'popfix.list'
local action = require'popfix.action'
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local api = vim.api

local M = {}

local splitWindow = nil
local exportedFunc = nil

local function close_selected()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, true)
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	preview.close()
	list.close()
	if splitWindow then
		api.nvim_win_close(splitWindow, true)
		splitWindow = nil
	end
	exportedFunc = nil
	--TODO: return to original window
end

local function close_cancelled()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, false)
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	preview.close()
	list.close()
	if splitWindow then
		api.nvim_win_close(splitWindow, true)
		splitWindow = nil
	end
	exportedFunc = nil
	--TODO: return to original window
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = list.getCurrentLineNumber()
	if oldIndex ~= line then
		local data = action.select(line, list.getCurrentLine())
		preview.writePreview(data)
	end
end

function M.popup(opts)
	if opts.data == nil then
		print "nil data"
		return false
	end
	if opts.mode == nil then opts.mode = 'split' end
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
	if not list.new(opts.list) then
		return false
	end
	vim.cmd('vsplit')
	local tmpBuffer = api.nvim_create_buf(false, true)
	api.nvim_buf_set_option(tmpBuffer, 'bufhidden', 'wipe')
	api.nvim_win_set_buf(api.nvim_get_current_win(), tmpBuffer)
	splitWindow = api.nvim_get_current_win()
	if not preview.new(opts.preview) then
		list.close()
		return false
	end
	list.setData(opts.data, 0, -1)
	if opts.callbacks == nil then return end
	action.register(opts.callbacks, opts.info)
	local default_keymaps = {
		n = {
			-- ['q'] = close_cancelled,
			['<Esc>'] = close_cancelled,
			['<CR>'] = close_selected
		}
	}
	local nested_autocmds = {
		['BufWipeout'] = close_cancelled,
		['BufDelete'] = close_cancelled,
		-- TODO: add bufleave but also add noautocmd
		-- ['BufLeave'] = close_cancelled
	}
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(list.buffer, nested_autocmds, true)
	autocmd.addCommand(list.buffer, non_nested_autocmds, false)
	opts.keymaps = opts.keymaps or default_keymaps
	--TODO: handle additional keymaps
	mappings.add_keymap(list.buffer, opts.keymaps)
	exportedFunc = {
		close_selected = close_selected,
		close_cancelled = close_cancelled
	}
	api.nvim_set_current_win(list.window)
	return true
end

function M.getFunction(name)
	return exportedFunc[name]
end

return M
