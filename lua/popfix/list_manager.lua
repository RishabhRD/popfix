local M = {}
M.__index = M

local api = vim.api

local identifier = api.nvim_create_namespace('popfix.identifier')
local listNamespace = api.nvim_create_namespace('popfix.listManager')


-- @class ListManager manages list UI and selection on various
-- events
function M:new(opts)
	local obj = {
		list = opts.list,
		preview = opts.preview,
		action = opts.action,
		renderLimit = opts.renderLimit,
		highlightingFunction = opts.highlightingFunction,
		caseSensitive = opts.caseSensitive,
		currentlyDisplayed = 0,
		linesRendered = 0,
		numData = 0
	}
	setmetatable(obj, self)
	return obj
end

function M:select(lineNumber, callback)
	if self.list.buffer == 0 or self.list.buffer == nil then
		return
	end
	api.nvim_buf_clear_namespace(self.list.buffer, listNamespace,
	0, -1)
	api.nvim_buf_add_highlight(self.list.buffer, listNamespace,
	"Visual", lineNumber - 1, 0, -1)
	self.list:select(lineNumber)
	local data
	if self.sortedList[lineNumber] then
		data = self.action:select(self.sortedList[lineNumber].index,
		self.list:get(lineNumber - 1), callback)
	end
	if data then
		if self.preview then
			if data ~= nil then
				self.preview:writePreview(data)
			end
		end
	end
end

-- lazy rendering while next selection
function M:select_next(callback)
	if self.currentLineNumber == self.numData then
		return
	end
	if self.currentLineNumber == self.currentlyDisplayed then
		local line = self.originalList
		[self.sortedList[self.currentLineNumber + 1].index]
		self.list:addLine(line, self.currentlyDisplayed, self.currentlyDisplayed)
		local highlight = self.highlightingFunction(self.currentPromptText,
		line, false)
		for _, col in pairs(highlight) do
			api.nvim_buf_add_highlight(self.list.buffer, identifier,
			"Identifier", self.currentlyDisplayed, col - 1, col)
		end
		self.currentlyDisplayed = self.currentlyDisplayed + 1
	end
	self.currentLineNumber = self.currentLineNumber + 1
	self:select(self.currentLineNumber, callback)
end

function M:select_prev(callback)
	if self.currentLineNumber == 1 then return end
	self.currentLineNumber = self.currentLineNumber - 1
	self:select(self.currentLineNumber, callback)
end

function M:clear()
	self.currentLineNumber = nil
	self.currentlyDisplayed = 0
	self.linesRendered = 0
	self.numData = 0
	self.action:select(nil, nil)
	vim.schedule(function()
		self.list:clear()
		api.nvim_buf_clear_namespace(self.list.buffer, identifier,
		0, -1)
	end)
end

--- add the elements to for rendering. However, we are doing lazy rendering
--- to not consume much processing capability in next gui schedule in an
--- intense process. That's why list and sortedList are a pre-requesite of it.
--- @param line string : the line which needs to be added
--- @param index number : Index at which addition is gonna happen
--- Note: Index in 1 based.
function M:add(line, index)
	-- condition for adding the elements
	-- add == nil means just return
	-- add == false means add but delete the last of list
	-- add == true means truly add
	self.numData = self.numData + 1
	local add = nil
	if index > self.renderLimit then
		add = nil
	else
		if self.currentlyDisplayed < self.renderLimit then
			add = true
		else
			add = false
		end
	end
	if add == nil then return end
	-- condition for selection
	local select = false
	if self.currentLineNumber == nil then
		self.currentLineNumber = 1
		select = true
	elseif index <= self.currentLineNumber then
		select = true
	end
	-- condition for highlight
	local highlight = nil
	if self.currentPromptText ~= '' then
		highlight = self.highlightingFunction(self.currentPromptText, line,
		self.caseSensitive)
	end
	-- now just render it
	if add == true then
		self.currentlyDisplayed = self.currentlyDisplayed + 1
	end
	local currentLineNumber = self.currentLineNumber
	vim.schedule(function()
		if add == false then
			self.list:clearLast()
		end
		self.list:addLine(line, index - 1, index - 1)
		if highlight then
			for _, col in pairs(highlight) do
				api.nvim_buf_add_highlight(self.list.buffer, identifier,
				"Identifier", index - 1, col - 1, col)
			end
		end
		if select then
			self:select(currentLineNumber)
		end
	end)
end

return M
