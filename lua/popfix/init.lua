local M = {}


-- possible modes: cursor, float, split
local default_opts = {
	preview_enabled = false,
	prompt_enabled = false,
	mode = 'split'
}

function M.open(opts)
	opts = opts or default_opts
	opts.preview_enabled = opts.preview_enabled or default_opts.preview_enabled
	opts.prompt_enabled = opts.prompt_enabled or default_opts.prompt_enabled
	opts.mode = opts.mode or default_opts.mode
end

return M
