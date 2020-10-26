local prompt = require'popfix.prompt'
local previewPopup = require'popfix.preview_popup'
local popup = require'popfix.popup'
local text = require'popfix.text'
local promptPopup = require'popfix.prompt_popup'
local promptPreviewPopup = require'popfix.prompt_preview_popup'
local M = {}

local currentInstance = nil

function M.open(opts)
	if currentInstance ~= nil then
		if not currentInstance.closed then return false end
		currentInstance = nil
	end
	if opts.mode == nil then
		print('Provide a mode attribute')
		return false
	end
	if opts.mode == 'editor' then
	elseif opts.mode == 'cursor' then
	elseif opts.mode == 'split' then
	else
		print('Note a valid mode')
		return false
	end
	if not opts.list then
		if opts.prompt then
			currentInstance = text
		else
			print('List attribute is necessary')
			return false
		end
	else
		if opts.preview then
			if opts.prompt then
				currentInstance = promptPreviewPopup
			else
				currentInstance = previewPopup
			end
		else
			if opts.prompt then
				currentInstance = promptPopup
			else
				currentInstance = popup
			end
		end
	end
	if not currentInstance.popup(opts) then
		currentInstance = nil
		return false
	end
	return true
end


function M.close_selected()
	currentInstance.close_selected()
end

function M.close_cancelled()
	currentInstance.close_cancelled()
end

function M.select_next()
	pcall(currentInstance.select_next)
end

function M.select_prev()
	pcall(currentInstance.select_prev)
end

function M.set_prompt_info(text)
	prompt.setPromptText(text)
end

return M
