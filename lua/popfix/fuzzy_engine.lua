local util = require'popfix.util'
local M = {}
local Job = require'popfix.job'
local uv = vim.loop
M.__index = M


--- @class FuzzyEngine
--- FuzzyEngine actually sorts the data obtained from job/data submitted to it
--- using the sorter's function. It is the class that submits the data
--- to manager to actually render it.
---
--- Internally FuzzyEngine should have a list and sortedList array.
--- list should contain the original data obtained from submitted job / data
--- sortedList should contain the array of {index, score} where index
--- represents the position of element in list and score represents the score
--- of that element wrt to prompt. This array is expected to be sorted wrt to
--- score. However, this behaviour is totally defined by FuzzyEngine and would
--- not impact working of other classes.
--- @field run function Function that has interface:
---     (opts): function,function
--- @field close function
--- Shuts down the fuzzy engine
--
--  Return value for run
--  @return textChagned : function(str), setData(data) : function
--  - textChanged would be invoked when there is any text change in prompt.
--    It accepts the string as parameter.
--  - setData would be called when user explicitly calls the setData function
--  It accepts data that has same spec as other classes.
--
--  Specification for opts:
--  Field for opts:
--  data (data provided by lua function)
--  manager (list manger)
--  sorter (sorter class)
--  currentPromptText: currentPromptText during intialisation
function M:new(opts)
	opts = opts or {}
	return setmetatable({
		run = opts.run,
		close = opts.close,
		list = {},
		sortedList = {}
	}, self)
end

local function clear(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end

function M:run_SingleExecutionEngine(opts)
	-- initilaization
	self.data = opts.data
	self.manager = opts.manager
	self.currentPromptText = opts.currentPromptText
	self.sorter = opts.sorter


	-- Additional initilaization job
	self.scoringFunction = self.sorter.scoringFunction
	self.filterFunction = self.sorter.filterFunction
	self.sorter = nil
	if self.data.cmd then
		local cmd, args = util.getArgs(self.data.cmd)
		self.cmd = cmd
		self.args = args
		self.cwd = self.data.cwd or vim.fn.getcwd()
		self.data = nil
	end

	-- Our requirements
	self.timeInterval = 1
	self.maxJob = 15
	self.manager.currentPromptText = self.currentPromptText

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

			if self.filterFunction(self.currentPromptText, line,
				self.caseSensitive) then
				local score = self.scoringFunction(self.currentPromptText,
				line, self.caseSensitive)
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
				self.manager:add(line, nil, nil, #self.sortedList - 1)
			end
		end
	end
	local function appendAggregateData(itrStart, itrEnd)
		for cur = itrStart, itrEnd do
			local line = self.list[cur]
			if self.filterFunction(self.currentPromptText, line,
				self.caseSensitive) then
				local score = self.scoringFunction(self.currentPromptText,
				line, self.caseSensitive)
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
	local function setData(data)
		if self.job then
			self.job:shutdown()
			self.job = nil
		end
		self.manager:clear()
		clear(self.list)
		clear(self.sortedList)
		if data.cmd then
			local cmd, args = util.getArgs(data.cmd)
			self.cmd = cmd
			self.cwd = data.cwd or vim.fn.getcwd()
			self.args = args
			self.job = Job:new{
				command = self.cmd,
				args = self.args,
				cwd = self.cwd,
				on_stdout = addData,
				on_exit = function()
					self.job = nil
				end,
			}
			self.job:start()
		else
			for k,v in ipairs(self.data) do
				self.list[k] = v
				self.sortedList[k] = {
					score = 0,
					index = k
				}
				self.manager:add(v, nil, nil, k)
			end
		end
	end
	if self.cmd then
		self.job = Job:new{
			command = self.cmd,
			args = self.args,
			cwd = self.cwd,
			on_stdout = addData,
			on_exit = function()
				self.job = nil
			end,
		}
		self.job:start()
	else
		for k,v in ipairs(self.data) do
			self.list[k] = v
			self.sortedList[k] = {
				score = 0,
				index = k
			}
			self.manager:add(v, nil, nil, k)
		end
	end
	return textChanged, setData
end

function M:newSingleExecutionEngine()
	return self:new({
		run = self.run_SingleExecutionEngine,
		close = self.close_SingleExecutionEngine
	})
end

function M:close_SingleExecutionEngine()
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
end

return M
