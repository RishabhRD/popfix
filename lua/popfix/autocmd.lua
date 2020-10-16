local autocmd = {}
local callback = {}
local param_map = {}
local key_id = 0

local function get_next_id()
	key_id = key_id + 1
	return key_id
end

local function assign_function(buf,func)
	local key = get_next_id()
	if callback[buf] == nil then
		callback[buf] = {}
	end
	callback[buf][key] = func
	return key
end

-- utility function for converting lua functions to appropriate string
-- and then add autocmd
local function buffer_autocmd(buf, property, action, nested)
	if type(action) == "string" then
		local command
		if nested then
			command = "autocmd %s <buffer=%s> ++nested %s"
		else
			command = "autocmd %s <buffer=%s> %s"
		end
		command = string.format(command, property, buf, action)
		vim.api.nvim_command(command)
	else
		local func = assign_function(buf,action)
		local command
		if nested then
			command = "autocmd %s <buffer=%s> ++nested lua require('popfix.autocmd').execute(%s,%s)"
		else
			command = "autocmd %s <buffer=%s> lua require('popfix.autocmd').execute(%s,%s)"
		end
		command = string.format(command,property,buf,buf,func)
		vim.api.nvim_command(command)
	end
end

-- add an autocmd to buf
--
-- param(buf): buffer to which autocmd is to be added
-- param(mapping_table): mappings for autocmd
--
-- mapping_table = {
--		string : string
--			or
--		string : lua_functions
-- }
function autocmd.addCommand(buf, mapping_table, nested, param)
	if param ~= nil then
		param_map[buf] = param
	end
	if nested == nil then nested = false end
	for property,action in pairs(mapping_table) do
		buffer_autocmd(buf,property,action, nested)
	end
end

function autocmd.execute(buf,key)
	if callback[buf] == nil then return end
	local func = callback[buf][key]
	func(param_map[buf])
end
-- i.e., free the data structure to free memory
function autocmd.free(buf)
	callback[buf] = nil
	param_map[buf] = nil
end

return autocmd
