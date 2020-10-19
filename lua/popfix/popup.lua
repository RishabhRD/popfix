local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local list = require'popfix.list'
local api = vim.api

local M = {}

local exportedFunction = nil
local originalWindow = nil

local function close_selected()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, true)
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	list.close()
	exportedFunction = nil
	api.nvim_set_current_win(originalWindow)
	originalWindow = nil
end

local function close_cancelled()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, false)
	mappings.free(list.buffer)
	autocmd.free(list.buffer)
	list.close()
	exportedFunction = nil
	api.nvim_set_current_win(originalWindow)
	originalWindow = nil
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = list.getCurrentLineNumber()
	if oldIndex ~= line then
		action.select(line, list.getCurrentLine())
	end
end

function M.popup(opts)
	if opts.data == nil then
		print "nil data"
		return false
	end
	if opts.mode == nil then opts.mode = 'split' end
	if opts.list == nil then
		print 'No attributes found'
		return false
	end
	if opts.mode == 'cursor' then
		local width = 0
		for _, str in ipairs(opts.data) do
			if #str > width then
				width = #str
			end
		end
		opts.width = width + 5
		opts.height = opts.height or #opts.data
	end
	originalWindow = api.nvim_get_current_win()
	opts.list.height = opts.height
	opts.list.mode = opts.mode
	opts.mode = nil
	if not list.new(opts.list) then
		originalWindow = nil
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
		['BufWipeout,BufDelete,BufLeave'] = close_cancelled,
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
	exportedFunction = {
		close_selected = close_selected,
		close_cancelled = close_cancelled
	}
	api.nvim_set_current_win(list.window)
	return true
end

function M.getFunction(name)
	return exportedFunction[name]
end

return M
