local function split(inputstr, sep)
    if sep == nil then
	sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
	table.insert(t, str)
    end
    return t
end

local function getArgs(inputstr)
    local sep = "%s"
    local t={}
    local cmd
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
	if not cmd then
	    cmd = str
	else
	    table.insert(t, str)
	end
    end
    return cmd, t
end

local function p(t)
    print(vim.inspect(t))
end

local function printError(msg)
    vim.cmd('echohl ErrorMsg')
    vim.cmd(string.format([[echomsg '%s']],msg))
    vim.cmd('echohl None')
end

return {
    split = split,
    getArgs = getArgs,
    p = p,
    printError = printError
}
