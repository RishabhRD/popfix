local selection = {}
local action = {}

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

action.register = function(buf,func_key,func)
	if selection[buf] == nil then
		selection[buf] = {}
	end
	selection[buf][func_key] = func
end

return action
