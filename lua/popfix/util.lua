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

return {
	split = split,
	getArgs = getArgs
}