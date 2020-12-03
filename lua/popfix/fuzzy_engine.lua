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
	self.numData = 0
	self.sortedNumData = 0
	self.error_handler = opts.error_handler


	-- Additional initilaization job
	self.scoringFunction = self.sorter.scoringFunction
	self.filterFunction = self.sorter.filterFunction
	self.maxJob = self.sorter.maxJob
	if self.maxJob == nil then
		self.maxJob = 50
	end
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
	self.manager.currentPromptText = self.currentPromptText

	local function addData(_, line)
		if not self.list then return end
		self.numData = self.numData + 1
		self.list[self.numData] = line
		-- if there is any existing timer then it will do your job.
		-- Don't worry then.
		if self.promptTimer then
			return
		end
		-- If there is no text in prompt then just add the things in sortedList
		if self.currentPromptText == '' then
			self.sortedNumData = self.sortedNumData + 1
			self.sortedList[self.sortedNumData] = {
				score = 0,
				index = self.numData
			}
			-- Put the line in last of UI list
			self.manager:add(line, self.sortedNumData)
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
						self.sortedNumData = self.sortedNumData + 1
						table.insert(self.sortedList, k, {
							score = score,
							index = self.numData
						})
						self.manager:add(line, k)
						return
					end
				end
				self.sortedNumData = self.sortedNumData + 1
				table.insert(self.sortedList, {
					score = score,
					index = self.numData
				})
				self.manager:add(line, self.sortedNumData)
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
						self.sortedNumData = self.sortedNumData + 1
						table.insert(self.sortedList, k, {
							score = score,
							index = cur
						})
						self.manager:add(line, k)
						break
					end
				end
				if not found then
					self.sortedNumData = self.sortedNumData + 1
					table.insert(self.sortedList, {
						score = score,
						index = cur
					})
					self.manager:add(line, self.sortedNumData)
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
		local len = self.numData
		len = len - self.startingIndex + 1
		if len > self.maxJob then
			appendAggregateData(tmp, tmp + self.maxJob - 1)
			self.startingIndex = self.startingIndex + self.maxJob
			self.promptTimer = uv.new_timer()
			self.promptTimer:start(self.timeInterval, 0, fillPartialPromptData)
		else
			appendAggregateData(tmp, self.numData)
			self.startingIndex = self.numData + 1
		end
	end
	-- TODO: what if some callback done by timer is executing.
	-- (Race condition needs to be solved)... Really?
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
		self.sortedNumData = 0
		if self.numData > self.maxJob then
			appendAggregateData(self.startingIndex, self.startingIndex +
			self.maxJob - 1)
			self.startingIndex = self.startingIndex + self.maxJob
			self.promptTimer = uv.new_timer()
			self.promptTimer:start(self.timeInterval, 0, fillPartialPromptData)
		else
			appendAggregateData(self.startingIndex, self.numData)
			self.startingIndex = self.numData + 1
		end
	end
	local function setData(data)
		if self.job then
			self.job:shutdown()
			self.job = nil
		end
		self.manager:clear()
		self.numData = 0
		self.sortedNumData = 0
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
				on_stderr = function(err, line)
					self.error_handler(err, line)
				end
			}
			self.job:start()
		else
			for k,v in ipairs(self.data) do
				self.sortedNumData = self.sortedNumData + 1
				self.numData = self.numData + 1
				self.list[k] = v
				self.sortedList[k] = {
					score = 0,
					index = k
				}
				self.manager:add(v,k)
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
			on_stderr = function(err, line)
				self.error_handler(err, line)
			end
		}
		self.job:start()
	else
		for k,v in ipairs(self.data) do
			self.sortedNumData = self.sortedNumData + 1
			self.numData = self.numData + 1
			self.list[k] = v
			self.sortedList[k] = {
				score = 0,
				index = k
			}
			self.manager:add(v,k)
		end
	end
	return textChanged, setData
end

function M:new_SingleExecutionEngine()
	return self:new({
		run = self.run_SingleExecutionEngine,
		close = self.close_SingleExecutionEngine,
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
	self.numData = 0
	self.sortedNumData = 0
	clear(self.list)
	clear(self.sortedList)
	self.list = nil
	self.sortedList = nil
	collectgarbage()
	collectgarbage()
end

-- Every time a new character is entered in prompt, this engine executes
-- the given command after formatting that with currentPromptText like
-- string.format(cmd, currentPromptText). It then outputs the result in
-- sortedList.
-- Currently this function only supports job from outside string of arrays are
-- not being supported by this function currently.
-- TODO: I need to think what should be the behaviour is someone uses this
-- engine with string array
function M:run_RepeatedExecutionEngine(opts)
	self.manager = opts.manager
	self.currentPromptText = opts.currentPromptText
	opts.sorter = nil
	self.base_cmd = opts.data.cmd
	self.cwd = opts.data.cwd or vim.fn.getcwd()
	self.numData = 0
	local function addData(_, line)
		self.numData = self.numData + 1
		self.list[self.numData] = line
		self.sortedList[self.numData] = {
			score = 0,
			index = self.numData
		}
		self.manager:add(line,self.numData)
	end
	local function textChanged(str)
		if self.currentJob then
			self.currentJob:shutdown()
			self.currentJob = nil
		end
		self.numData = 0
		if self.base_cmd == nil then return end
		self.manager:clear()
		self.currentPromptText = str
		self.manager.currentPromptText = str
		local command = string.format(self.base_cmd, str)
		local cmd, args = util.getArgs(command)
		self.currentJob = Job:new{
			command = cmd,
			args = args,
			cwd = self.cwd,
			on_stdout = addData,
			on_exit = function()
				self.currentJob = nil
			end
		}
		self.currentJob:start()
	end
	local function setData(data)
		self.base_cmd = data.cmd
		if not self.base_cmd then return end
		self.cwd = data.cwd or vim.fn.getcwd()
		textChanged(self.currentPromptText)
	end
	return textChanged, setData
end

function M:close_RepeatedExecutionEngine()
	if self.currentJob then
		self.currentJob:shutdown()
		self.currentJob = nil
	end
	clear(self.list)
	clear(self.sortedList)
	self.list = nil
	self.sortedList = nil
	-- TODO: I don't know why, but this is freeing the memory
	-- I have also seen this in a potential fuzzy finder implementation
	-- telescope.nvim. After exploring their source I realised they are also
	-- doing the same hack.
	collectgarbage()
	collectgarbage()
end

function M:new_RepeatedExecutionEngine()
	return self:new({
		run = self.run_RepeatedExecutionEngine,
		close = self.close_RepeatedExecutionEngine,
	})
end

return M
