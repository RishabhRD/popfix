local describe = describe
local it  = it
-- local helpers = require('test.functional.helpers')(after_each)
-- local Screen = require('test.functional.ui.screen')

-- local clear         = helpers.clear
-- local command       = helpers.command
-- local exec_capture  = helpers.exec_capture
-- local feed          = helpers.feed
-- local exec_lua      = helpers.exec_lua
-- local sleep         = helpers.sleep
-- local split         = helpers.split
local eq = assert.are.same

local function newListSizeTest()
	local testList = require'test_list':new({})
	eq(testList:getSize(), 1)
end

local function addFirstListElement()
	local testList = require'test_list':new({})
	testList:add('first')
	eq(1, testList:getSize())
end

local function addSecondListElement()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second', true)
	eq(2, testList:getSize())
end

local function addElementToListAferClose()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second')
	testList:close()
	testList:add('third')
end

local function listElementDeltedAfterClose()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second')
	testList:close()
	eq(testList:getSize(), nil)
end

local function sizeOfListAfterClear()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second')
	testList:clear()
	eq(testList:getSize(), 1)
	testList:close()
end

local function clearListAfterClose()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second')
	testList:close()
	testList:clear()
end

local function addElementToListAfterClear()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second')
	testList:clear()
	testList:add('first')
	eq(1, testList:getSize())
	testList:close()
end

local function sizeOfListAfterRemovingElement()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:add('second')
	testList:add('third')
	testList:removeLast()
	eq(2, testList:getSize())
	testList:removeLast()
	eq(1, testList:getSize())
	testList:close()
end

local function sizeOfListAfterFullyRemovingElement()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:removeLast()
	eq(1, testList:getSize())
	testList:close()
end

local function addingOneElementAfterFullyRemovingElements()
	local testList = require'test_list':new({})
	testList:add('first')
	testList:removeLast()
	testList:add('second')
	eq(1, testList:getSize())
	testList:add('third')
	eq(2, testList:getSize())
	testList:close()
end

describe('Popfix:', function()
	it('new_list_size', newListSizeTest)
	it('add first list element should result in size 1', addFirstListElement)
	it('add second list element should result in size 2', addSecondListElement)
	it('list elemnts deleted after close', listElementDeltedAfterClose)
	it('add element after close', addElementToListAferClose)
	it('size of list after clear', sizeOfListAfterClear)
	it('clear list after close', clearListAfterClose)
	it('size of list after adding after clear', addElementToListAfterClear)
	it('size of list after removing element', sizeOfListAfterRemovingElement)
	it('size of list after fully removing element', sizeOfListAfterFullyRemovingElement)
	it('adding one element after fully removing elements', addingOneElementAfterFullyRemovingElements)
end)
