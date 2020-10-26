local M = {}
local api = vim.api
local prompt = require'popfix.prompt'
local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'

M.closed = true
local originalWindow = nil


local function close_cancelled()
	if M.closed then return end
	M.closed = true
	local line = prompt.getCurrentPromptText()
	mappings.free(prompt.buffer)
	autocmd.free(prompt.buffer)
	api.nvim_set_current_win(originalWindow)
	prompt.close()
	originalWindow = nil
	action.close(0, line, false)
end

local function close_selected()
	if M.closed then return end
	M.closed = true
	local line = prompt.getCurrentPromptText()
	mappings.free(prompt.buffer)
	autocmd.free(prompt.buffer)
	api.nvim_set_current_win(originalWindow)
	prompt.close()
	originalWindow = nil
	action.close(0, line, true)
end

local function popup_editor(opts)
	local editorWidth = api.nvim_get_option('columns')
	local editorHeight = api.nvim_get_option("lines")
	opts.prompt.width = opts.width or math.ceil(editorWidth * 0.8)
	opts.prompt.row = math.ceil((editorHeight - 1) / 2 - 5)
	opts.prompt.col = math.ceil((editorWidth - opts.prompt.width) /2)
	if not prompt.new(opts.prompt) then
		return false
	end
	return true
end

local function popup_cursor(opts)
	opts.prompt.row = 1
	opts.prompt.col = 0
	opts.prompt.relative = "cursor"
	if opts.prompt.border then
		opts.prompt.row = opts.prompt.row + 1
	end
	if not prompt.new(opts.prompt) then
		return false
	end
	return true
end

function M.popup(opts)
	originalWindow = api.nvim_get_current_win()
	if opts.mode == 'editor' then
		if not popup_editor(opts) then
			return false
		end
	elseif opts.mode == 'cursor' then
		if not popup_cursor(opts) then
			return false
		end
	end
	M.closed = false
	action.register(opts.callbacks)
	local default_keymaps = {
		n = {
			['q'] = close_cancelled,
			['<Esc>'] = close_cancelled,
			['<CR>'] = close_selected
		},
		i = {
			['<C-c>'] = close_cancelled,
			['<CR>'] = close_selected,
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
		['BufLeave'] = close_cancelled,
	}
	autocmd.addCommand(prompt.buffer, nested_autocmds, true)
	mappings.add_keymap(prompt.buffer, opts.keymaps)
	api.nvim_set_current_win(prompt.window)
	return true
end

return M
