local M = {}
M.__index = M


-- @class ListManager manages list UI and selection on various
-- events
function M:new(opts)
	local obj = {
		list = opts.list
	}
	setmetatable(obj, self)
	return obj
end

function M:add(line, starting, ending)
	if ((not starting) or (not ending)) then
		vim.schedule(function()
			self.list:appendLine(line)
		end)
		return
	end
	vim.schedule(function()
		self.list:addLine(line, starting, ending)
	end)
end

function M:clear()
	vim.schedule(function()
		self.list:clear()
	end)
end


return M
