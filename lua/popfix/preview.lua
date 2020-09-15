local map = function(buf,type,key,value)
	vim.fn.nvim_buf_set_keymap(buf,type,key,value,{noremap = true,silent = true});
end

local function getWindow()
	local buf, win
	-- if floating then
	-- 	local width = vim.api.nvim_get_option("columns")
	-- 	local height = vim.api.nvim_get_option("lines")

	-- 	local win_height = math.ceil(height * 0.85 - 4)
	-- 	local win_width = math.ceil(width * 0.8)

	-- 	local row = math.ceil((height - win_height) / 2 + 1)
	-- 	local col = math.ceil((width - win_width) / 2 + 1)
	-- 	local opts = {
	-- 		style = "minimal",
	-- 		relative = "editor",
	-- 		width = win_width,
	-- 		height = win_height,
	-- 		row = row,
	-- 		col = col
	-- 	}

	-- 	buf = vim.api.nvim_create_buf(false, true)
	-- 	win = vim.api.nvim_open_win(buf,true,opts)
	-- else
	vim.api.nvim_command('bot new')
	win = vim.api.nvim_get_current_win()
	buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf,'Preview #' .. buf)
	vim.api.nvim_win_set_height(win,20)
	-- end

	return { buf = buf, win = win}
end

local function getPreview(win)
	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)

	local win_height =  height - 3;
	local win_width = math.ceil(width*0.5 - 2)

	local row = 2
	local col = win_width + 2

	local opts = {
		style = "minimal",
		relative = "win",
		width = win_width,
		height = win_height,
		row  = row,
		col = col
	}

	local buf = vim.api.nvim_create_buf(false,true)
	local win_newWin = vim.api.nvim_open_win(buf,true,opts)
	return { buf = buf, win = win_newWin}
end

local function setBufferProperty(buf)
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
end

local function setWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

local function popup_preview()
	local newWindow = getWindow()
	local buf = newWindow.buf
	local win = newWindow.win
	setBufferProperty(buf)
	setWindowProperty(win)
	local previewWindow = getPreview(win)
end

return{
	popup_preview = popup_preview
}
