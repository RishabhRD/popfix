local fzy = require'popfix.fzy'
local M = {}

M.__index = M

-- @class sorter
-- sorter provides the corresponding scoring function,
-- filter function and highlighting function.
-- This function helps fuzzy engine to sort in desired way.
--
-- scoringFunction: function(needle, heystack, case_sensitive)
-- filterFunction: function(needle, heystack, case_sensitive)
-- highlightingFunction: function(needle, heystack, case_sensitive)
-- caseSensitive : boolean
function M:new(opts)
	return setmetatable({
		scoringFunction = opts.scoring_function,
		filterFunction = opts.filter_function,
		highlightingFunction = opts.highlighting_function,
		caseSensitive = opts.case_sensitive
	}, self)
end

function M:new_fzy_sorter(caseSensitive)
	return setmetatable({
		scoringFunction = fzy.score,
		filterFunction = fzy.has_match,
		highlightingFunction = fzy.positions,
		caseSensitive = caseSensitive
	}, self)
end

return M
