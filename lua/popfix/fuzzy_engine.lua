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
	}, self)
end

local function clear(t)
	for k, _ in ipairs(t) do
		t[k] = nil
	end
end

function M:new_SingleExecutionEngine()
	return self:new({
		run = self.run_SingleExecutionEngine,
		close = self.close_SingleExecutionEngine,
	})
end

function M:close_SingleExecutionEngine()
	self.idle:stop()
	self.idle:close()
	self.idle = nil
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
	self.manager:close()
	self.manager = nil
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
		self.numData = self.numData	+ 1
		self.manager:add(line,self.numData, 0)
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
	self.manager:close()
	self.manager = nil
end

function M:new_RepeatedExecutionEngine()
	return self:new({
		run = self.run_RepeatedExecutionEngine,
		close = self.close_RepeatedExecutionEngine,
	})
end

function M:run_SingleExecutionEngine(opts)
	-- initilaization
	self.sortedList = {}
	self.list = {}
	self.manager = opts.manager
	self.currentPromptText = opts.currentPromptText
	self.sorter = opts.sorter
	self.numData = 0
	self.sortedNumData = 0
	self.error_handler = opts.error_handler
	self.startingIndex = 1


	-- Additional initilaization job
	self.scoringFunction = self.sorter.scoringFunction
	self.filterFunction = self.sorter.filterFunction
	self.maxJob = self.sorter.maxJob
	if self.maxJob == nil then
		self.maxJob = 50
	end
	self.sorter = nil
	-- Our requirements
	self.manager.currentPromptText = self.currentPromptText

	local function appendAggregateData(itrStart, itrEnd)
		for cur = itrStart, itrEnd do
			local line = self.list[cur]
			if self.currentPromptText == '' then
				self.sortedNumData = self.sortedNumData + 1
				self.sortedList[self.sortedNumData] = cur
				self.manager:add(line, self.sortedNumData, cur)
			else
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
							self.manager:add(line, k, cur)
							break
						end
					end
					if not found then
						self.sortedNumData = self.sortedNumData + 1
						table.insert(self.sortedList, {
							score = score,
							index = cur
						})
						self.manager:add(line, self.sortedNumData, cur)
					end
				end
			end
		end
	end

	local function addSortedDataToTable()
		if self.numData == 0 then return end
		local tmp = self.startingIndex
		local len = self.numData - (self.startingIndex - 1)
		if len <= 0 then return end
		if len > self.maxJob then
			appendAggregateData(tmp, tmp + self.maxJob - 1)
			self.startingIndex = self.startingIndex + self.maxJob
		else
			appendAggregateData(tmp, self.numData)
			self.startingIndex = self.numData + 1
			if self.idle then
				self.idle:stop()
			end
		end
	end

	local function textChanged(prompt)
		if self.currentPromptText == '' and prompt == '' then
			return
		end
		if self.idle then
			if not self.idle:is_active() then
				self.idle:start(addSortedDataToTable)
			end
		end
		self.currentPromptText = prompt
		self.manager.currentPromptText = prompt
		self.startingIndex = 1
		self.manager:clear()
		clear(self.sortedList)
		self.sortedNumData = 0
	end

	local function addData(_, line)
		self.numData = self.numData	+ 1
		self.list[self.numData] = line
		if self.idle then
			if not self.idle:is_active() then
				self.idle:start(addSortedDataToTable)
			end
		end
	end

	local function createJob(data)
		if data.cmd then
			local cmd, args = util.getArgs(data.cmd)
			local cwd = data.cwd or vim.fn.getcwd()
			self.job = Job:new{
				command = cmd,
				args = args,
				cwd = cwd,
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
			for k,v in ipairs(data) do
				self.numData = self.numData + 1
				self.list[k] = v
			end
			if self.idle then
				if not self.idle:is_active() then
					self.idle:start(addSortedDataToTable)
				end
			end
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
		createJob(data)
	end
	self.idle = uv.new_idle()
	self.idle:start(addSortedDataToTable)
	createJob(opts.data)
	opts = nil
	return textChanged, setData
end


return M
