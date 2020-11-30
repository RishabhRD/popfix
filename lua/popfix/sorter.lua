local fzy_native = require'popfix.fzy-native'
local fzy = require'popfix.fzy'
local M = {}

M.__index = M

--- @class sorter
--- sorter provides the corresponding scoring function,
--- filter function and highlighting function.
--- This function helps fuzzy engine to sort in desired way.
---
--- @field scoringFunction function(needle, heystack, case_sensitive)
--- @field filterFunction function(needle, heystack, case_sensitive)
--- @field highlightingFunction function(needle, heystack, case_sensitive)
--- @field caseSensitive boolean
--- @field maxJobs integer maximum number of jobs possible in a millisecond
--- with optimal conditions.
function M:new(opts)
	return setmetatable({
		scoringFunction = opts.scoring_function,
		filterFunction = opts.filter_function,
		highlightingFunction = opts.highlighting_function,
		caseSensitive = opts.case_sensitive,
		maxJobs = opts.max_jobs
	}, self)
end

function M:new_fzy_sorter(caseSensitive)
	return setmetatable({
		scoringFunction = fzy.score,
		filterFunction = fzy.has_match,
		highlightingFunction = fzy.positions,
		caseSensitive = caseSensitive,
		maxJobs = 30
	}, self)
end

function M:new_fzy_native_sorter(caseSensitive)
	return setmetatable({
		scoringFunction = fzy_native.score,
		filterFunction = fzy_native.has_match,
		highlightingFunction = fzy_native.positions,
		caseSensitive = caseSensitive,
		maxJobs = 90
	}, self)
end

return M
