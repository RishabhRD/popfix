local M = {}
M.__index = M

function M:new(opts)
	local obj = setmetatable({}, self)
	obj.currentPromptText = opts.init_text or ''
	opts.prompt_text = opts.prompt_text or ''
	obj.prefix = opts.prompt_text .. '> ' 
	return obj
end

function M:setPromptText(text)
	self.currentPromptText = text
	if self.textChanged then
		self.textChanged(text)
	end
end

function M:getCurrentPromptText()
	return self.currentPromptText
end

function M:registerTextChanged(func)
	self.textChanged = func
	self.textChanged(self.currentPromptText)
end

function M:close()
	self.textChanged = nil
	self.currentPromptText = nil
	self.prefix = nil
end

return M
