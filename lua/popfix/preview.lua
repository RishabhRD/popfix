local action = require'popfix.action'
local mappings = require'popfix.mappings'
local autocmd = require'popfix.autocmd'

local preview_map = {}


local function preview(buf, filepath, range)
	local raw_command = "cat -n %s | sed -n '%s,%sp'"
	local line = range.start.line + 1
	local startLine = range.start.line + 1
	local endLine
	if startLine <= 3 then
		endLine  = 11 - startLine
		startLine = 1
	else
		endLine = startLine + 7
		startLine = startLine - 2
	end
	-- TODO highlighting of code
	-- local cur_window = vim.api.nvim_get_current_win()
	local command = string.format(raw_command,filepath,startLine,endLine)
	local data = vim.fn.systemlist(command)
	vim.api.nvim_buf_set_lines(preview_map[buf].buf,0,-1,false,data)
	-- vim.api.nvim_set_current_win(preview_map[buf].win)
	-- vim.api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filepath))
	-- vim.api.nvim_set_current_win(cur_window)
	vim.api.nvim_buf_set_option(preview_map[buf].buf, "filetype", "text")
	vim.api.nvim_buf_add_highlight(preview_map[buf].buf, -1, "Visual", line - startLine , 0, -1)
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
	vim.api.nvim_win_set_height(win,12)
	-- end

	return { buf = buf, win = win}
end

local function getPreview(win)
	local width = vim.api.nvim_win_get_width(win)
	local height = vim.api.nvim_win_get_height(win)

	local win_height =  height
	local win_width = math.ceil(width*0.5)

	local row = 0
	local col = win_width

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
		}
	}
	local autocmds = {}
	autocmds['CursorMoved'] = action.update_selection
	autocmds['BufWipeout'] = action.close_cancelled
	mappings.add_keymap(buf,keymaps)
	autocmd.addCommand(buf,autocmds)
end

local function setWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', true)
	vim.api.nvim_win_set_option(win, 'cursorline', true)
end

local function setPreviewBufferProperty(buf)
	vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
end

local function setPreviewWindowProperty(win)
	vim.api.nvim_win_set_option(win, 'wrap', false)
	vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')
	vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
	vim.api.nvim_win_set_option(win, 'foldlevel', 100)
end

local function close(buf, selected, line)
	if preview_map[buf] == nil then
		return
	end
	local preview_win = preview_map[buf].win
	if preview_win == nil then
		return
	end
	vim.api.nvim_win_close(preview_win,true)
	if(selected) then
		vim.lsp.util.jump_to_location(preview_map[buf].locations[line])
	end
	preview_map[buf] = nil
end

local function init(buf)
	local locations = preview_map[buf].locations
	local data = {}
	for i, location in pairs(locations) do
		local uri = location.uri or location.targetUri
		local range = location.range or location.targetSelectionRange
		local filePath = uri:gsub('^file://', '')
		--TODO path shortening
		local curData = filePath .. ': '
		local command = "sed '%sq;d' %s"
		command = string.format(command, range.start.line + 1, filePath)
		local appendedList = vim.fn.systemlist(command)
		local appendedData = appendedList[1]
		curData = curData .. appendedData
		data[i] = curData
	end
	vim.api.nvim_buf_set_lines(buf,0,-1,false,data)
	local location = locations[1]
	local uri = location.uri or location.targetUri
	local range = location.range or location.targetSelectionRange
	local filePath = uri:gsub('^file://', '')
	preview(buf,filePath,range)
end

local function selectIndex(buf,index)
	local location = preview_map[buf].locations[index]
	local uri = location.uri or location.targetUri
	local range = location.range or location.targetSelectionRange
	local filePath = uri:gsub('^file://', '')
	preview(buf,filePath,range)
end

local function popup_preview(locations)
	local newWindow = getWindow()
	local popup_buf = newWindow.buf
	local popup_win = newWindow.win
	local previewWindow = getPreview(popup_win)
	local preview_win = previewWindow.win
	local preview_buf = previewWindow.buf
	preview_map[popup_buf] = {}
	preview_map[popup_buf].win = preview_win
	preview_map[popup_buf].buf = preview_buf
	preview_map[popup_buf].locations = locations
	action.register(popup_buf,'close_selected',close)
	action.register(popup_buf,'close_cancelled',close)
	action.register(popup_buf,'init',init)
	action.register(popup_buf,'update_selection',selectIndex)
	action.init(popup_buf,popup_win)
	setBufferProperty(popup_buf)
	setWindowProperty(popup_win)
	setPreviewWindowProperty(preview_win)
	setPreviewBufferProperty(preview_buf)
end

return{
	popup_preview = popup_preview
}
