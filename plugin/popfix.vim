if exists('g:loaded_popfix') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo " save user coptions
set cpo&vim " reset them to defaults

let &cpo = s:save_cpo " and restore after
unlet s:save_cpo

command !Popup lua require'popfix'.popup_window()

let g:loaded_popfix = 1
