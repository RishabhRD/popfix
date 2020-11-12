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
local function buffer_autocmd(buf, property, action, param, nested, once)
	local nested_string = ''
	if nested then nested_string = "++nested" end
	local once_string = ''
	if once then once_string = "++once" end
	if type(action) == "string" then
		local command = string.format("autocmd %s <buffer=%s> %s %s %s", property, buf, nested_string, once_string, action)
		vim.cmd(command)
	else
		local func = assign_function(buf,action)
		if param then
			param_map[buf][func] = param
		end
		local command = string.format("autocmd %s <buffer=%s> %s %s lua require('popfix.autocmd').execute(%s,%s)", property, buf, nested_string, once_string, buf, func)
		vim.cmd(command)
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
function autocmd.addCommand(buf, mapping_table, param)
	if not param_map[buf] then
		param_map[buf] = {}
	end
	local nested = mapping_table.nested
	local once = mapping_table.once
	if mapping_table['nested'] then
		mapping_table['nested'] = nil
	end
	if mapping_table['once'] then
		mapping_table['once'] = nil
	end
	for property,action in pairs(mapping_table) do
		buffer_autocmd(buf, property, action, param, nested, once)
	end
end

function autocmd.execute(buf,key)
	if callback[buf] == nil then return end
	local func = callback[buf][key]
	func(param_map[buf][key])
end
-- i.e., free the data structure to free memory
function autocmd.free(buf)
	callback[buf] = nil
	param_map[buf] = nil
end

return autocmd
