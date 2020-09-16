local action = require'popfix.action'
local mappings = require'popfix.mappings'

local preview_map = {}

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
	local win_newWin = vim.api.nvim_open_win(buf,false,opts)
	return { buf = buf, win = win_newWin}
end

local function setBufferProperty(buf)
	vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
	vim.api.nvim_buf_set_option(buf, 'swapfile', false)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
	local keymaps = {
		n = {
			['<CR>'] = action.close_selected,
			['<ESC>'] = action.close_cancelled,
			['<C-n>'] = action.next_select,
			['<C-p>'] = action.prev_select,
			['<C-j>'] = action.next_select,
			['<C-k>'] = action.prev_select,
			['<DOWN>'] = action.next_select,
			['<UP>'] = action.prev_select,
			['j'] = action.next_select,
			['k'] = action.prev_select
		}
	}
	mappings.add_keymap(buf,keymaps)
end

local function setWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

local function close(buf, selected, line)
	local preview_win = preview_map[buf].win
	if preview_win == nil then
		return
	end
	vim.api.nvim_win_close(preview_win,true)
	if(selected) then
		print("selected close: ",line)
	else
		print("cancelled close: ")
	end
	preview_map[buf] = nil
end

local function popup_preview()
	local newWindow = getWindow()
	local popup_buf = newWindow.buf
	local popup_win = newWindow.win
	local previewWindow = getPreview(popup_win)
	local preview_win = previewWindow.win
	local preview_buf = previewWindow.buf
	preview_map[popup_buf] = {}
	preview_map[popup_buf].win = preview_win
	preview_map[popup_buf].buf = preview_buf
	action.init(popup_buf,popup_win)
	action.register(popup_buf,'close_selected',close)
	action.register(popup_buf,'close_cancelled',close)
	setBufferProperty(popup_buf)
	setWindowProperty(popup_win)
end

return{
	popup_preview = popup_preview
}
