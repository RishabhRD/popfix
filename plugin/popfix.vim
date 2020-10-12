" if exists('g:loaded_popfix') | finish | endif

" let s:save_cpo = &cpo
" set cpo&vim

" let &cpo = s:save_cpo
" unlet s:save_cpo

" let g:loaded_popfix = 1


fun! PopFix()
   lua for k in pairs(package.loaded) do if k:match(".*") then package.loaded[k] = nil end end
   lua require'popfix.floating_win'.default_win()
endfun

augroup PopFix
   autocmd!
augroup END
