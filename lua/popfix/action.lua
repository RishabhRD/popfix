local selection = {}
local action = {}

-- action to update current line to some other line(i.e., update data structure)
--
-- param(buf): popup buffer id
action.update_selection = function(buf)
	if selection[buf] == nil then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(selection[buf].win)
	if selection[buf].index ~= cursor[1] then
		selection[buf].index = cursor[1]
		local func = selection[buf]['selection']
		if func ~= nil then
			func(buf,cursor[1])
		end
	end
end

-- action to initialize popup buffer inside window win, and place data in buffer
--
-- param(buf): popup buffer id
-- param(win): popup window id
-- param(data): string list to be displayed in popup window
action.init = function(buf,win,data)
	if selection[buf] == nil then
		selection[buf] ={}
	end
	selection[buf].win = win
	selection[buf].index = 1
	local func = selection[buf]['init']
	if func ~= nil then
		func(buf)
	end
	vim.api.nvim_buf_set_lines(buf,0,-1,false,data)
	vim.api.nvim_buf_set_option(buf, 'modifiable',false)
end

-- action to denote current line notation was selected as window was closed
--
-- param(buf): popup buffer id
action.close_selected = function(buf)
	if selection[buf] == nil then
		return
	end
	require'popfix.mappings'.free(buf)
	require'popfix.autocmd'.free(buf)
	local line = vim.api.nvim_win_get_cursor(selection[buf].win)[1]
	vim.api.nvim_win_close(selection[buf].win,true)
	local func = selection[buf]['close']
	selection[buf] = nil
	if func ~= nil then
		func(buf,true,line)
	end
end

-- action to denote current line notation was not selected as window was closed
--
-- param(buf): popup buffer id
action.close_cancelled = function(buf)
	if selection[buf] == nil then
		return
	end
	require'popfix.mappings'.free(buf)
	require'popfix.autocmd'.free(buf)
	local line = vim.api.nvim_win_get_cursor(selection[buf].win)[1]
	vim.api.nvim_win_close(selection[buf].win,true)
	local func = selection[buf]['close']
	selection[buf] = nil
	if func ~= nil then
		func(buf,false,line)
	end
end

-- register a new handler for buf
--
-- param(buf): popup buffer id
-- param(func_key): string denoting to which callback func wants to attach
-- param(func): actual callback function
--
-- func_key can be: 'init', 'close', 'selection'
action.register = function(buf,func_key,func)
	if selection[buf] == nil then
		selection[buf] = {}
	end
	selection[buf][func_key] = func
end

return action
