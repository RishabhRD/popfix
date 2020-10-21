local previewPopup = require'popfix.preview_popup'
local popup = require'popfix.popup'
local M = {}

local currentInstance = nil
local close = nil

function M.open(opts)
	if currentInstance ~= nil then
		currentInstance = nil
		close()
	end
	if opts.mode == nil then
		print('Provide a mode attribute')
		return
	end
	if opts.mode == 'editor' then
	elseif opts.mode == 'cursor' then
	elseif opts.mode == 'split' then
	else
		print('Note a valid mode')
	end
	if opts.list == nil then
		print('List attribute is necessary')
		return
	end
	if opts.preview then
		currentInstance = previewPopup
		close = previewPopup.getFunction('close-cancelled')
		if not previewPopup.popup(opts) then
			currentInstance = nil
		end
	else
		currentInstance = popup
		close = previewPopup.getFunction('close-cancelled')
		if not popup.popup(opts) then
			currentInstance = nil
		end
	end
end

return M
