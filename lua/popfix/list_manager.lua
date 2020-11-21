local M = {}
M.__index = M

local api = vim.api

local identifier = api.nvim_create_namespace('popfix.identifier')
local listNamespace = api.nvim_create_namespace('popfix.prompt_popup')


-- @class ListManager manages list UI and selection on various
-- events
function M:new(opts)
	local obj = {
		list = opts.list,
		action = opts.action
	}
	setmetatable(obj, self)
	return obj
end

function M:add(line, starting, ending, highlightTable, highlightLine)
	local selection = self.action.selection.index
	if ((not starting) or (not ending)) then
		vim.schedule(function()
			self.list:appendLine(line)
			if not selection then
				api.nvim_buf_clear_namespace(self.list.buffer, listNamespace,
				0, -1)
				api.nvim_buf_add_highlight(self.list.buffer, listNamespace,
				"Visual", 0, 0, -1)
				self.action:select(line, self.list:getCurrentLine())
			end
			for _, col in pairs(highlightTable) do
				api.nvim_buf_add_highlight(self.list.buffer, identifier,
				"Identifier", highlightLine, col - 1, col)
			end
		end)
		return
	end
	vim.schedule(function()
		self.list:addLine(line, starting, ending)
		if not selection then
			api.nvim_buf_clear_namespace(self.list.buffer, listNamespace, 0,
			-1)
			api.nvim_buf_add_highlight(self.list.buffer, listNamespace,
			"Visual", 0, 0, -1)
			self.action:select(line, self.list:getCurrentLine())
		end
		for _, col in pairs(highlightTable) do
			api.nvim_buf_add_highlight(self.list.buffer, identifier,
			"Identifier", highlightLine, col - 1, col)
		end
	end)
end

function M:clear()
	vim.schedule(function()
		self.list:clear()
	end)
end


return M
