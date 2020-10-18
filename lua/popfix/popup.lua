local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'
local list = require'popfix.list'
local api = vim.api

local exportedFunction = nil

local M = {}

local function close_selected()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, true)
	list.close()
	exportedFunction = nil
end

local function close_cancelled()
	if action.freed() then return end
	local line = action.getCurrentLine()
	local index = action.getCurrentIndex()
	action.close(index, line, false)
	list.close()
	exportedFunction = nil
end

local function selectionHandler()
	local oldIndex = action.getCurrentIndex()
	local line = list.getCurrentLineNumber()
	if oldIndex ~= line then
		action.select(line, list.getCurrentLine())
	end
end

function M.popup(opts)
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
	opts.list.height = opts.height
	opts.list.mode = opts.mode
	opts.mode = nil
	if not list.new(opts.list) then
		close_cancelled()
		return false
	end
	list.setData(opts.data, 0, -1)
	--TODO: don't simply return
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
		['BufLeave'] = close_cancelled
	}
	local non_nested_autocmds = {
		['CursorMoved'] = selectionHandler,
	}
	autocmd.addCommand(list.buffer, nested_autocmds, true)
	autocmd.addCommand(list.buffer, non_nested_autocmds, false)
	opts.keymaps = opts.keymaps or default_keymaps
	--TODO: handle additional keymaps
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
