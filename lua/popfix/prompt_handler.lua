local fzy = require'popfix.fzy'
local M = {}
M.__index = M

local function clear(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end

function M:new(opts)
	local obj = {}
	setmetatable(obj, self)
	obj.originalEntry = {}
	obj.sortedEntry = {}
	obj.hl_pos = {}
	obj.numEntry = 0
	obj.currentPromptText = ''
	obj.caseSensitive = opts.caseSensitive
	return obj
end



function M:addEntry(str)
	self.originalEntry[#self.originalEntry+1] = str
	if self.currentPromptText == '' then return end
	clear(self.sortedEntry)
	clear(self.hl_pos)
	for k, matcher in pairs(self.originalEntry) do
		if fzy.has_match(self.currentPromptText, matcher, self.caseSensitive) then
			local score = fzy.score(self.currentPromptText, matcher, self.caseSensitive)
			self.sortedEntry[#self.sortedEntry + 1] = {
				string = matcher,
				score = score,
			}
			if self.indexing then
				self.sortedEntry[#self.sortedEntry].index = k
			end
		end
	end
	table.sort(self.sortedEntry, function(a, b)
		return a.score > b.score
	end)
end

function M:setPromptText(prompt)
	self.currentPromptText = prompt
	if self.currentPromptText == '' then return end
	clear(self.sortedEntry)
	for k, matcher in pairs(self.originalEntry) do
		if fzy.has_match(self.currentPromptText, matcher, self.caseSensitive) then
			local score = fzy.score(self.currentPromptText, matcher, self.caseSensitive)
			self.sortedEntry[#self.sortedEntry + 1] = {
				string = matcher,
				score = score,
			}
			if self.indexing then
				self.sortedEntry[#self.sortedEntry].index = k
			end
		end
	end
	table.sort(self.sortedEntry, function(a, b)
		return a.score > b.score
	end)
end

function M:getHighlightPositions()
	clear(self.hl_pos)
	for _, v in pairs(self.sortedEntry) do
		self.hl_pos[#self.hl_pos + 1] =
		fzy.positions(self.currentPromptText, v.string)
	end
	return self.hl_pos
end

return M
