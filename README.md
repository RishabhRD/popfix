# popfix

popfix is neovim lua API for highly extensible quickfix or popup window.
Any neovim plugin in lua can make use of it to reduce efforts to manage
underlying buffer and window.

**WARNING: neovim 0.5 is required for using this API.**

## TODO

- Implement OOP pattern and depreciate global things.
- One instance of each thing

## Where this can be helpful?

If your plugin doesn't require highly customized window popups and things,
and you want to focus most on data to be displayed and actions upon events,
then this plugin is what you want.

This plugin is intended to provide sensible window templates with highly
extensible event-driven programming capability.

Plugin writers can configure events using lua callbacks and passing keymap
tables. They can directly map lua functions to keymap with underlying
architecture.

## Screenshots
![](https://user-images.githubusercontent.com/26287448/93617774-076ad600-f9f4-11ea-9c4e-d37019241320.gif)
![](https://user-images.githubusercontent.com/26287448/93930985-d3691b00-fd3b-11ea-9053-b699e4d36558.gif)

## Features

- Floating popup
- Navigable preview window (syntax coloring possible)

## Future goals

- Floating preview
- Fuzzy search

## Prerequisites

- Neovim nightly

## Install

Install with any plugin manager. For example with vim-plug

	Plug 'RishabhRD/popfix'

## API Description

### Keymaps

Keymaps are expressed as lua tables. Currently normal mode and insert mode
keymappings are supported.

Keymap table example:

	{
		n = {
			['<CR>'] = action.close_selected,
			['<C-n>'] = 'j'
		},
		i = {
			['<C-c>'] = action.close_cancelled
		}
	}

Every keymap lua functions accepts popup buffer id as only argument.
However, this is not a limitation as it is only needed to map desired
parameters to buffer id using lua tables.
A little coding trick would do the job.

n represents normal mode mappings and i represents insert mode mappings.
First mapping for normal mode maps a lua function ``action.close_selected``
to <CR>. However, second mapping of normal mode maps string j to <C-n> (i.e.,
map <C-n> to go down).
This gives a lot flexibility while writing plugins.

### Special actions

Two special lua functions are shipped for easily managing lifetime of
popup window.

To use these actions, you need to import files:

	local action = require'popfix.action'

Provided actions are:

- action.close_selected(popup_buf)
- action.close_cancelled(popup_buf)

First action close popup as the current option is selected. Second action
close popup as the current option is not selected.

### Callbacks

API provides 3 callbacks on which plugins can react:

- init callback
- select callback
- close callback

init callback is called after popup menu appears and loaded with data.

select callback is called after selection change event occurs.
(i.e., cursor moves to different line)

close callback is called after popup is closed.

Plugins can map any functions to callback with this syntax:

	init_callback(popup_buffer_id)
	select_callback(popup_buffer_id, line_selected)
	close_callback(popup_buffer_id, is_selected, line_selected)

popup_buffer_id represents buffer id of popup menu.

line_selected represents the current selected item in popup menu.

is_selected represents boolean value as buffer was closed as selected or
cancelled. (See special actions)

### Preview specific criteria

For preview menu init_callback, select_callback, close_callback functions are
expected to return a lua table. Lua table format is:

	{
		data,
		line,
		filetype
	}

data is list of string and can be represented as:

	local data = {
		[1] = "This is an example",
		[2] = "Example ends here"
	}

line_num is an integer and can be represented as:

	local line_num = 4

filetype is a string that should be a valid filetype.
This filetype parameter is used to do syntax coloring of preview data.
If filetype parameter is nil then no syntax coloring is done.

So, return data can be represented as:

	local return_data = {
		data = data,
		line = line_num,
		filetype = filetype
	}

This return_data is used for content of preview window after callback.

- ``return_data.data`` is filled in preview window and have syntax highlighting according to ``return_data.filetype``
- ``return_data.line`` is highlighted in preview window.

### Initializing popup

For initializing a popup use:

	local popup_buffer_id = require'popfix.popup'.popup_window(
		data,
		key_map,
		init_callback,
		select_callback,
		close_callback
	)

data represents the data to be displayed in popup window.

key_map represents the key mapping to be added to popup window as discussed
earlier.

Others are callback functions as discussed earlier.

For initializing a popup preview use:

	local popup_buffer_id = require'popfix.preview'.popup_preview(
		data,
		key_map,
		init_callback,
		select_callback,
		close_callback
	)

## Some plugins based on this API

- https://github.com/RishabhRD/nvim-lsputils
	This plugin provides comfortable UI for LSP actions(code fix, references)
	for neovim 0.5 built-in LSP client.
