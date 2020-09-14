fun! PopFix()
    lua for k in pairs(package.loaded) do if k:match("^popfix") then package.loaded[k] = nil end end
	lua require'popfix'.popup_window()
endfun

augroup PopFix
    autocmd!
augroup END
