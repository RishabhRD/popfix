local api = vim.api

local function open_window(data,maxWidth,maxHeight)
	local minWidth = 30
	local minHeight = 5
	if #data == 0 then
		return nil
	end
	if maxHeight < minHeight then
		return nil
	end
	if maxWidth < minWidth then
		return nil
	end
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	api.nvim_buf_set_lines(buf,0,-1,false,data)
	api.nvim_buf_set_option(buf, 'modifiable',false)
	-- local width = api.nvim_get_option("columns")
	-- local height = api.nvim_get_option("lines")

	local winHeight = #data + 1
	if winHeight < minHeight then
		winHeight = minHeight
	end
	if winHeight > maxHeight then
		winHeight = maxHeight
	end

	local winWidth = minWidth
	for _,cur in pairs(data) do
		local curWidth =  string.len(cur)
		if curWidth > winWidth then
			winWidth = curWidth
		end
	end
	if winWidth > maxWidth then
		winWidth = maxWidth
	end

	local opts = {
		style = "minimal",
		relative = "cursor",
		width = winWidth,
		height = winHeight,
		row = 0,
		col = 1
	}

	local win = api.nvim_open_win(buf, true, opts)
	local ret = {}
	ret[1] = buf;
	ret[2] = win;
	return ret
end

local function popup_window(data,maxWidth,maxHeight)
	local newWindow = open_window(data,maxWidth,maxHeight)
	print(newWindow[2])
end

return{
	popup_window = popup_window
}
