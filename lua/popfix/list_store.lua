local M = {}
local Job = require'popfix.job'
local uv = vim.loop
M.__index = M
M.timeInterval = 1
M.maxJob = 20

-- @class List store stores all the job output.
-- It also maintains job output itself and prompt event.
-- It also maintains a sorted list with respect to current prompt text
function M:new(opts)
	local obj = {
		luaTable = opts.luaTable,
		manager = opts.manager,
		scoringFunction = opts.scoringFunction,
		filterFunction = opts.filterFunction,
		caseSensitive = opts.caseSensitive,
		currentPromptText = '',
		prompt = opts.prompt,
		cmd = opts.cmd,
		args = opts.args,
		list = {},
		sortedList = {},
	}
	setmetatable(obj, self)
	return obj
end

local function clear(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end


function M:run()
	local function addData(_, line)
		if not self.list then return end
		self.list[#self.list + 1] = line
		-- if there is any existing timer then it will do your job.
		-- Don't worry then.
		if self.promptTimer then
			return
		end
		-- If there is no text in prompt then just add the things in sortedList
		if self.currentPromptText == '' then
			self.sortedList[#self.sortedList + 1] = {
				score = 0,
				index = #self.list
			}
			-- Put the line in last of UI list
			self.manager:add(line, nil ,nil, #self.sortedList - 1)
		else
			-- Traverse sorted list and get the location where output text
			-- fits with respect to its score with current prompt
			-- Time complextity : O(n)

			if self.filterFunction(self.currentPromptText, line) then
				local score = self.scoringFunction(self.currentPromptText, line)
				for k,v in ipairs(self.sortedList) do
					if score > v.score then
						table.insert(self.sortedList, k, {
							score = score,
							index = #self.list
						})
						self.manager:add(line, k-1, k-1, k-1)
						return
					end
				end
				table.insert(self.sortedList, {
					score = score,
					index = #self.list
				})
			end
		end
	end
	local function appendAggregateData(itrStart, itrEnd)
		for cur = itrStart, itrEnd do
			local line = self.list[cur]
			if self.filterFunction(self.currentPromptText, line) then
				local score = self.scoringFunction(self.currentPromptText, line)
				local found = false
				for k,v in ipairs(self.sortedList) do
					if score > v.score then
						found = true
						table.insert(self.sortedList, k, {
							score = score,
							index = cur
						})
						self.manager:add(line, k-1, k-1, k-1)
						break
					end
				end
				if not found then
					table.insert(self.sortedList, {
						score = score,
						index = cur
					})
					self.manager:add(line, nil ,nil, #self.sortedList - 1)
				end
			end
		end
	end
	-- this function fills start filling the data in sorted table
	-- from where it was left off. From there it tries fill remaining data.
	-- if remaining is still not sufficient then it tries to again schedule a
	-- timer.
	local function fillPartialPromptData()
		self.promptTimer:stop()
		self.promptTimer:close()
		self.promptTimer = nil
		local tmp = self.startingIndex
		local len = #self.list
		len = len - self.startingIndex + 1
		if len > self.maxJob then
			appendAggregateData(tmp, tmp + self.maxJob - 1)
			self.startingIndex = self.startingIndex + self.maxJob
			self.promptTimer = uv.new_timer()
			self.promptTimer:start(self.timeInterval, 0, fillPartialPromptData)
		else
			appendAggregateData(tmp, #self.list)
			self.startingIndex = #self.list + 1
		end
	end
	-- TODO: what if some callback done by timer is executing.
	-- (Race condition needs to be solved)
	local function textChanged(prompt)
		if self.currentPromptText == '' and prompt == '' then
			return
		end
		self.currentPromptText = prompt
		self.manager.currentPromptText = prompt
		if self.promptTimer then
			self.promptTimer:stop()
			self.promptTimer:close()
			self.promptTimer = nil
		end
		self.startingIndex = 1
		self.manager:clear()
		clear(self.sortedList)
		if #self.list > self.maxJob then
			appendAggregateData(self.startingIndex, self.startingIndex +
			self.maxJob - 1)
			self.startingIndex = self.startingIndex + self.maxJob
			self.promptTimer = uv.new_timer()
			self.promptTimer:start(self.timeInterval, 0, fillPartialPromptData)
		else
			appendAggregateData(self.startingIndex, #self.list)
			self.startingIndex = #self.list + 1
		end
	end
	if self.cmd then
		self.job = Job:new{
			command = self.cmd,
			args = self.args,
			cwd = vim.fn.getcwd(),
			on_stdout = addData,
			on_exit = function()
				self.job = nil
			end,
		}
		self.job:start()
	else
		for k,v in ipairs(self.luaTable) do
			self.list[k] = v
			self.sortedList[k] = {
				score = 0,
				index = k
			}
			self.manager:add(v, nil, nil, k)
		end
	end
	self.prompt:registerTextChanged(textChanged)
end


function M:close()
	if self.promptTimer then
		self.promptTimer:stop()
		self.promptTimer:close()
		self.promptTimer = nil
	end
	if self.job then
		if self.job then
			self.job:shutdown()
			self.job = nil
		end
	end
	self.sortedList = nil
	self.list = nil
end

return M
