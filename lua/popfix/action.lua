local selection = {}
local action = {}

action.next_select = function(buf)
	if selection[buf] == nil then
		return
	end
	local curLine = selection[buf].index
	curLine = curLine + 1
	local total_lines = vim.api.nvim_buf_line_count(buf)
	if curLine <= total_lines then
		local pos = {}
		pos[1] = curLine
		pos[2] = 0
		vim.api.nvim_win_set_cursor(selection[buf].win,pos)
		selection[buf].index = curLine
		local func = selection[buf]['next_select']
		if func ~= nil then
			func(buf,curLine)
		end
	end
end

action.prev_select = function(buf)
	if selection[buf] == nil then
		return
	end
	local curLine = selection[buf].index
	curLine = curLine - 1
	if curLine >= 1 then
		local pos = {}
		pos[1] = curLine
		pos[2] = 0
		vim.api.nvim_win_set_cursor(selection[buf].win,pos)
		selection[buf].index = curLine
		local func = selection[buf]['prev_select']
		if func ~= nil then
			func(buf,curLine)
		end
	end
end

-- action.index_select = function(buf,index)
-- 	if selection[buf] == nil then
-- 		return
-- 	end
-- 	local total_lines = vim.api.nvim_buf_line_count(buf)
-- 	if index <= total_lines and index >= 1 then
-- 		local pos = {}
-- 		pos[1] = index
-- 		pos[2] = 0
-- 		vim.api.nvim_win_set_cursor(selection[buf].win,pos)
-- 		selection[buf].index = index
-- 		if selection[buf].index_select ~= nil then
-- 			selection[buf].index_select(buf,index)
-- 		end
-- 	end
-- end

action.init = function(buf,win)
	if selection[buf] ~= nil then
		return
	end
	selection[buf] = {}
	selection[buf].win = win
	selection[buf].index = 0
	local func = selection[buf]['init']
	if func ~= nil then
		func(buf,0)
	end
end

action.close_selected = function(buf)
	if selection[buf] == nil then
		return
	end
	require'popfix.mappings'.free(buf)
	local line = vim.api.nvim_win_get_cursor(selection[buf].win)[1]
	vim.api.nvim_win_close(selection[buf].win,true)
	local func = selection[buf]['close_selected']
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
	local line = vim.api.nvim_win_get_cursor(selection[buf].win)[1]
	vim.api.nvim_win_close(selection[buf].win,true)
	local func = selection[buf]['close_cancelled']
	selection[buf] = nil
	if func ~= nil then
		func(buf,false,line)
	end
end

action.register = function(buf,func_key,func)
	if selection[buf] == nil then
		return
	end
	selection[buf][func_key] = func
end

return action
