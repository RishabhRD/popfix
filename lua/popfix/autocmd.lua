local autocmd = {}
local callback = {}
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

local function buffer_autocmd(buf,property,action)
	if type(action) == "string" then
		local command = "autocmd %s <buffer> %s"
		command = string.format(command,property,action)
		vim.api.nvim_command(command)
	else
		local func = assign_function(buf,action)
		local command = "autocmd %s <buffer=%s> lua require('popfix.autocmd').execute(%s,%s)"
		command = string.format(command,property,buf,buf,func)
		vim.api.nvim_command(command)
	end
end

function autocmd.addCommand(buf, mapping_table)
	for property,action in pairs(mapping_table) do
		buffer_autocmd(buf,property,action)
	end
end

function autocmd.execute(buf,key)
	if callback[buf] == nil then
		return
	end
	local func = callback[buf][key]
	func(buf)
end

function autocmd.free(buf)
	callback[buf] = nil
end

return autocmd
