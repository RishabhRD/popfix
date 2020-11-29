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
		linesRendered = 0,
		highlightingFunction = opts.highlightingFunction,
	}
	setmetatable(obj, self)
	return obj
end

function M:select(lineNumber, callback)
	api.nvim_buf_clear_namespace(self.list.buffer, listNamespace,
	0, -1)
	api.nvim_buf_add_highlight(self.list.buffer, listNamespace,
	"Visual", lineNumber - 1, 0, -1)
	local data
	local preview = true
	local currentIndex = self.action:getCurrentIndex()
	if currentIndex and currentIndex == self.sortedList[lineNumber].index then
		preview = false
	end
	if self.sortedList[lineNumber] then
		data = self.action:select(self.sortedList[lineNumber].index,
		self.list:get(lineNumber - 1), callback)
	end
	if preview then
		if data then
			vim.schedule(function()
				if self.preview then
					if data ~= nil then
						self.preview:writePreview(data)
					end
				end
			end)
		end
	end
end

-- lazy rendering while next selection
function M:select_next(callback)
	if self.currentLineNumber == #self.sortedList then
		return
	end
	if self.currentLineNumber == self.renderLimit then
		self.currentLineNumber = self.currentLineNumber + 1
		self.renderLimit = self.renderLimit + 1
		local string =
		self.originalList[self.sortedList[self.currentLineNumber].index]
		vim.schedule(function()
			self.list:appendLine(string)
			self:select(self.currentLineNumber, callback)
		end)
	else
		self.currentLineNumber = self.currentLineNumber + 1
		vim.schedule(function()
			self:select(self.currentLineNumber, callback)
		end)
	end
end

function M:select_prev(callback)
	if self.currentLineNumber == 1 then return end
	self.currentLineNumber = self.currentLineNumber - 1
	self:select(self.currentLineNumber, callback)
end

function M:add(line, starting, ending, highlightLine)
	local add = false
	local highlight = true
	if self.currentPromptText == '' then
		highlight = false
	end
	if self.linesRendered < self.renderLimit then
		add = true
	end
	if ((not starting) or (not ending)) then
		if not add then return end
		self.linesRendered = self.linesRendered + 1
		local highlightTable
		if highlight then
			highlightTable = self.highlightingFunction(self.currentPromptText,
			line)
		end
		self.currentLineNumber = 1
		vim.schedule(function()
			self.list:appendLine(line)
			-- TODO: don't select 1 only. because it can be distracting to users.
			-- Try to select the indicies as it is.
			self:select(1)
			if highlight then
				for _, col in pairs(highlightTable) do
					api.nvim_buf_add_highlight(self.list.buffer, identifier,
					"Identifier", highlightLine, col - 1, col)
				end
			end
		end)
		return
	end
	if starting >= self.renderLimit then
		return
	end
	if add then
		self.linesRendered = self.linesRendered + 1
	end
	local highlightTable =
	self.highlightingFunction(self.currentPromptText, line)
	self.currentLineNumber = 1
	vim.schedule(function()
		if not add then
			self.list:clearLast()
		end
		self.list:addLine(line, starting, ending)
		-- TODO: don't select 1 only. because it can be distracting to users.
		-- Try to select the indicies as it is.
		self:select(1)
		for _, col in pairs(highlightTable) do
			api.nvim_buf_add_highlight(self.list.buffer, identifier,
			"Identifier", highlightLine, col - 1, col)
		end
	end)
end

function M:clear()
	self.linesRendered = 0
	self.action:select(nil, nil)
	vim.schedule(function()
		self.list:clear()
		api.nvim_buf_clear_namespace(self.list.buffer, identifier,
		0, -1)
	end)
end

return M
