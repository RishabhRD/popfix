local M = {}

local api = vim.api
local autocmd = require'popfix.autocmd'
local mappings = require'popfix.mappings'
local action = require'popfix.action'

local prompt = require'popfix.prompt'
local list = require'popfix.list'
M.closed = true
local originalWindow = nil

local function plainSearchHandler(str)
	print(str)
end

local function close_selected()
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

local function close_cancelled()
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


local function popup_split(opts)
	local editorHeight = api.nvim_get_option("lines")
	local maximumHeight = editorHeight - 5
	opts.height = opts.height or 12
	if opts.height > maximumHeight then
		opts.height = maximumHeight
	end
	opts.list.height = opts.height
	list.new(opts.list)
	opts.prompt.row = editorHeight - opts.height - 5
	opts.prompt.col = 0
	opts.prompt.width = math.floor(api.nvim_win_get_width(list.window) / 2)
	prompt.new(opts.prompt)
end

function M.new(opts)
	if opts.data == nil or #opts.data == 0 then
		print 'nil data'
		return false
	end
	opts.list = opts.list or {}
	opts.list.mode = opts.mode
	if opts.prompt_type == 'plain' then
		opts.prompt.callback = plainSearchHandler
	end
	originalWindow = api.nvim_get_current_win()
	popup_split(opts)
	list.setData(opts.data, 0, -1)
	action.register(opts.callbacks)
	local default_keymaps = {
		n = {
			['q'] = close_cancelled
		}
	}
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
	local nested_autocmds = {
		['BufLeave'] = close_cancelled,
		['BufDelete'] = close_cancelled,
		['BufWipeout'] = close_cancelled
	}
	autocmd.addCommand(prompt.buffer, nested_autocmds, true)
	api.nvim_set_current_win(prompt.window)
	mappings.add_keymap(prompt.buffer, opts.keymaps)
	M.closed = false
	return true
end

return M
