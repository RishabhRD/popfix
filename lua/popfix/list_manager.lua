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
	sortedList = {},
	numData = 0
    }
    setmetatable(obj, self)
    return obj
end

function M:select(lineNumber, callback)
    if self.list.buffer == 0 or self.list.buffer == nil then
	return
    end
    vim.schedule(function()
      api.nvim_buf_clear_namespace(self.list.buffer, listNamespace,
      0, -1)
      api.nvim_buf_add_highlight(self.list.buffer, listNamespace,
      self.list.selection_highlight, lineNumber - 1, 0, -1)
      self.list:select(lineNumber)
    end)
    -- pcall(self.list.select, self.list, lineNumber)
    local data
    if self.sortedList[lineNumber] then
	data = self.action:select(self.sortedList[lineNumber].index,
	self.sortedList[lineNumber].line, callback)
    end
    if data then
	if self.preview then
	    if data ~= nil then
	      vim.schedule(function()
		self.preview:writePreview(data)
	      end)
	    end
	end
    end
end

-- lazy rendering while next selection
function M:select_next(callback)
    if self.numData == 0 then return end
    if self.currentLineNumber == self.numData then
	return
    end
    vim.schedule(function()
    self.currentLineNumber = self.currentLineNumber + 1
    self:select(self.currentLineNumber, callback)
  end)
end

function M:select_prev(callback)
    if self.numData == 0 then return end
    if self.currentLineNumber == 1 then return end
    self.currentLineNumber = self.currentLineNumber - 1
    self:select(self.currentLineNumber, callback)
end

local function clear(t)
    for k,_ in ipairs(t) do
	t[k] = nil
    end
end

function M:clear()
    clear(self.sortedList)
    self.currentLineNumber = nil
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
--- @param originalIndex number : Index at which current line was added originally.
--- Note: Index in 1 based.
function M:add(line, index, originalIndex)
  self.numData = self.numData + 1
  -- This can be made optional using a preprovided sortedList however
  -- it is important to make API stable first.
  table.insert(self.sortedList, index, {index = originalIndex, line = line})
  local select = nil
  if self.currentLineNumber == nil then
    self.currentLineNumber = 1
    select = true
  elseif index <= self.currentLineNumber then
    select = true
  end
  local highlight = nil
  -- TODO: This can be done lazily. However, it is more important to stabalize
  -- the API first. And still we are good on performance.
  if self.currentPromptText ~= nil then
    highlight = self.highlightingFunction(self.currentPromptText, line,
    self.caseSensitive)
  end
  local currentLineNumber = self.currentLineNumber
  vim.schedule(function()
    self.list:addLine(line, index - 1, index - 1)
    if highlight then
      for _, col in pairs(highlight) do
	api.nvim_buf_add_highlight(self.list.buffer, identifier,
	self.list.matching_highlight, index - 1, col - 1, col)
      end
    end
    if select then
      self:select(currentLineNumber)
    end
  end)
end

function M:close()
    clear(self.sortedList)
end

return M
