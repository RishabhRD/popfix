local M = {}

M.__index = M

function M:new(opts)
	local obj = {
		internalArray = {''},
		numData = 1,
	}
	setmetatable(obj, self)
	return obj
end

function M:getSize()
	return self.numData
end

function M:add(ele)
	if self.numData == nil then return end
	assert(self.numData	~= nil)
	if not self.emptyCleared then
		self.internalArray[1] = ele
		self.emptyCleared = true
	else
		self.numData = self.numData + 1
		self.internalArray[self.numData] = ele
	end
end

local function clearTable(t)
	for k,_ in ipairs(t) do
		t[k] = nil
	end
end

function M:clear()
	if self.numData == nil then return end
	assert(self.numData ~= nil)
	clearTable(self.internalArray)
	self.internalArray[1] = ''
	self.numData = 1
	self.emptyCleared = nil
end

function M:close()
	self.numData = nil
	self.emptyCleared = nil
	self.internalArray = nil
	self.emptyCleared = nil
end

function M:removeLast()
	if self.numData == nil then return end
	if self.numData == 1 then
		self:clear()
	else
		self.internalArray[self.numData] = nil
		self.numData = self.numData - 1
	end
end

return M
