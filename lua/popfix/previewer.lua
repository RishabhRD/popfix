local floating_win = require'popfix.floating_win'
local api = vim.api

local M = {}

local previewerNamespace = api.nvim_create_namespace('previewer')

function M.getPreviewer(opts, type, tp)
	local win_buf = floating_win.create_win(opts, tp)
	return {
		win = win_buf.win,
		buf = win_buf.buf,
		type = type
	}
end

function M.writePreview(previewer, data)
	if previewer.type == 'terminal' then
		api.nvim_buf_set_option(previewer.buf, 'modified', false)
		local cwd = data.cwd
		local opts = {
			cwd = cwd or vim.fn.getcwd()
		}
		local cur_win = api.nvim_get_current_win()
		api.nvim_set_current_win(previewer.win)
		--TODO: kill the job buddy
		vim.fn.termopen(data.cmd, opts)
		api.nvim_set_current_win(cur_win)
	elseif previewer.type == 'buffer' then
		api.nvim_buf_set_lines(previewer.buf, 0, -1, false, data.lines or {''})
		if data.line ~= nil then
			api.nvim_buf_add_highlight(previewer.buf, previewerNamespace,
			"Visual", data.line, 0, -1)
		end
	else
		print('Invalid preview type')
		return
	end
end

return M
