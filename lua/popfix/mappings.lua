local mappings = {}
local function_store = {}
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
	function_store[buf][key] = func
	return key
end

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
			if mode == "i" and not opts.expr then
				prefix = "<cmd>"
			end

			map_string = string.format(
				"%s:lua require('popfix.mappings').execute_keymap(%s, %s)<CR>",
				prefix,
				buf,
				func_id
				)
		end

		map(buf,mode,key_bind,map_string,opts)
	end
end

function mappings.add_keymap(buf,mapping_table)
	local normalMappings = mapping_table.n
	if normalMappings ~= nil then
		for key,value in normalMappings do
			bufferKeyMap(buf,'n',key,value)
		end
	end
	local insertMappings = mapping_table.i
	if insertMappings ~= nil then
		for key, value in insertMappings do
			bufferKeyMap(buf,'n',key,value)
		end
	end
end

mappings.execute_keymap = function(buf, key)
	local func = function_store[buf][key]
	func(buf)
end

return mappings
