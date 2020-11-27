local previewPopup = require'popfix.preview_popup'
local popup = require'popfix.popup'
local text = require'popfix.text'
local promptPopup = require'popfix.prompt_popup'
local promptPreviewPopup = require'popfix.prompt_preview_popup'
local M = {}


function M:new(opts)
	self.__index = self
	local obj = {}
	setmetatable(obj, self)
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
			return text:new(opts)
		else
			print('List attribute is necessary')
			return false
		end
	else
		if opts.preview then
			if opts.prompt then
				return promptPreviewPopup:new(opts)
			else
				return previewPopup:new(opts)
			end
		else
			if opts.prompt then
				return promptPopup:new(opts)
			else
				return popup:new(opts)
			end
		end
	end
end

return M
