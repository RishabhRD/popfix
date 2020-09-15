local selection = {}
local action = {}

action.next_select = function(buf,callback)
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
		callback(buf,curLine)
	end
end

action.prev_select = function(buf,callback)
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
		callback(buf,curLine)
	end
end

action.index_select = function(buf,index,callback)
	if selection[buf] == nil then
		return
	end
	local total_lines = vim.api.nvim_buf_line_count(buf)
	if index <= total_lines and index >= 1 then
		local pos = {}
		pos[1] = index
		pos[2] = 0
		vim.api.nvim_win_set_cursor(selection[buf].win,pos)
		selection[buf].index = index
		callback(buf,index)
	end
end

action.init = function(buf,win)
	if selection[buf] ~= nil then
		return
	end
	selection[buf] = {}
	selection[buf].win = win
	selection[buf].index = 0
end

action.close = function(buf,selected,index,callback)
	if selection[buf] == nil then
		return
	end
	selection[buf] = nil
	if selected then
		callback(buf,index)
	end
end
