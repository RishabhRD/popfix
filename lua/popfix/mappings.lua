local mappings = {}
local function_store = {}
local param_map = {}
local key_id = 0

local map = function(buf,type,key,value,opts)
	vim.fn.nvim_buf_set_keymap(buf,type,key,value,opts or {silent = true});
end

local function get_next_id()
	key_id = key_id + 1
	return key_id
end

local assign_function = function(buf,func)
	local key = get_next_id()
	if function_store[buf] == nil then
		function_store[buf] = {}
	end
	function_store[buf][key] = func
	return key
end

-- utility functionf to map keys and convert lua function to string internally
local bufferKeyMap = function(buf, mode, key_bind, key_func, opts)
	opts = opts or {
		silent = true
	}
	if type(key_func) == "string" then
		map(buf,mode,key_bind,key_func,opts)
	else
		local func_id = assign_function(buf, key_func)
		local prefix = ""
		local map_string
		if opts.expr then
			map_string = string.format(
				[[luaeval("require('popfix.mappings').execute_keymap(%s, %s)")]],
				buf,
				func_id
				)
		else
			-- if mode == "i" and not opts.expr then
			-- 	prefix = "<cmd>"
			-- end

			map_string = string.format(
				"%s<cmd>lua require('popfix.mappings').execute_keymap(%s, %s)<CR>",
				prefix,
				buf,
				func_id
				)
		end

		map(buf,mode,key_bind,map_string,opts)
	end
end

-- add keymap to buffer buf
--
-- param(buf): buffer to which mapping was to be added
-- param(mapping_table): actual mappings
-- mapping table{
--		n{
--			'string' : 'string'
--			or
--			'string' : lua functions
--		},
--		i{
--			'string' : 'string'
--			or
--			'string' : lua functions
--		}
-- }
function mappings.add_keymap(buf,mapping_table, param)
	if param ~= nil then
		param_map[buf] = param
	end
	local normalMappings = mapping_table.n
	if normalMappings ~= nil then
		for key,value in pairs(normalMappings) do
			bufferKeyMap(buf,'n',key,value)
		end
	end
	local insertMappings = mapping_table.i
	if insertMappings ~= nil then
		for key, value in pairs(insertMappings) do
			bufferKeyMap(buf,'n',key,value)
		end
	end
end

mappings.execute_keymap = function(buf, key)
	if function_store[buf] == nil then return end
	local func = function_store[buf][key]
	func(param_map[buf])
end

-- free keymaps from buffer buf
-- i.e., free the data structure
mappings.free = function(buf)
	function_store[buf] = nil
	param_map[buf] = nil
end

return mappings
