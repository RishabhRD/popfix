local action = {}

action.__index = action

local function free(self)
    self.selection = nil
end

function action:getCurrentLine()
    if not self.selection then
	return nil
    end
    return self.selection.line
end

function action:getCurrentIndex()
    if not self.selection then
	return nil
    end
    return self.selection.index
end

function action:new(callbacks)
    local obj = {
	selection = {},
	callbacks = callbacks
    }
    setmetatable(obj, self)
    return obj
end

-- if callback is there then call callback
-- otherwise call registered default callback.
-- (Useful in autocmd)
function action:select(index, line, callback)
    if not self.selection then return end
    self.selection.index = index
    self.selection.line = line
    if callback then
	return callback(index, line)
    end
    if self.callbacks  then
	if self.callbacks['select'] then
	    return self.callbacks.select(index, line)
	end
    end
end

-- if callback is there then call callback
-- otherwise call registered default callback.
-- (Useful in autocmd)
function action:close(index, line, callback)
    if callback then
	callback(index, line)
	free(self)
	return
    end
    if self.callbacks  and self.callbacks.close then
	self.callbacks.close(index, line)
    end
    free(self)
end

return action
