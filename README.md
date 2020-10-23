# popfix

popfix is neovim lua API for highly extensible quickfix or popup window.
Any neovim plugin in lua can make use of it to reduce efforts to manage
underlying buffer and window.

**WARNING: neovim 0.5 is required for using this API.**

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

- Fuzzy search

## Prerequisites

- Neovim nightly

## Install

Install with any plugin manager. For example with vim-plug

	Plug 'RishabhRD/popfix'

## API Description

Popfix UI has 2 major components:
 - List
 - Preview

 List displays the menu.

 Preview displays the preview.

### How to invoke plugin

Example:

	local opts = {
		height = 40,
		mode = 'split',
		data = <data-table>,
		keymaps = <keymaps>,
		additional_keymaps = <additional-keymaps>,
		callbacks = {
			select = <select-callback>,
			close = <close-callback>
		}
		list = {
			border = true,
			numbering = true,
			coloring = true,
			title = 'MyTitle'
		},
		preview = {
			type = 'terminal'
			border = true,
			numbering = true,
			coloring = true,
			title = 'MyTitle'
		}
	}

	require'popfix'.open(opts)

### Height [optional]

Number of results to display in window at a time(window height).

### Mode

Plugin can operate in 3 modes:

- Split
- Editor
- Cursor

Split mode opens menu in a bottom split

Editor mode opens menu in a floating window relative to editor.

Cursor mode opens menu in a floating window relative to current cursor position.

### Data

Data to be displayed in menu. (String table)



### Keymaps [optional]

Keymaps are expressed as lua tables. Currently normal mode and insert mode
keymappings are supported.

Keymap table example:

	{
		n = {
			['<C-q>'] = <lua-function>
			['<C-n>'] = 'j'
		},
		i = {
			['<C-c>'] = 'close-cancelled'
		}
	}

Any lua function or string can be provided as value

Keymaps field replaces the default keymaps. (Default keymaps are used if this is
not provided)

### Additional keymaps [optional]

These are also same type as keymaps. However, these are appended in keymaps list.
i.e., After applying this resultant keymaps = original keymaps + additional keymaps

### Special actions

Two special lua functions are shipped for easily managing lifetime of
popup window. These can be used to pass as keymapping value.

- 'close-cancelled'
- 'close-selected'

close-cancelled closes the current preview with invoking close callback as
cancelled.

close-selected closes the current preview with invoking close callback as
selected.


### Callbacks [optional]

API provides 2 callbacks on which plugins can react:

- select callback [optional]
- close callback  [optional]

select callback is called after selection change event occurs.
(i.e., cursor moves to different line)

close callback is called after popup is closed.

Plugins can map any functions to callback with this syntax:

	selection_changed(line_num, line_string)
	popup_closed(line_num, line_string, selected)

line_num is line number which is currently selected.

line_string is string on line_num.

selected is for close callback if current selection was confirmed or cancelled.

### List

List supports 3 attributes:

- border [optional]
- numbering [optional]
- coloring [optional]
- title [optional]

If border is true then list is displayed with border. [only for floating window]

Numbering is true then numbers are also displayed in list.

Coloring is true then special color(different than normal background) is
displayed for list. [only for floating window]

Title represents title of list window. It would be displayed iff borders are
active.


### Preview [optional]

If preview option is not provided then preview window is not displayed.

Preview supports 4 attributes:

- border [optional]
- numbering [optional]
- coloring [optional]
- title [optional]
- type

border, numbering, coloring and title are similar to list attributes and apply in similar
way to preview window also. However, border and colors are also applied even if
list is in split mode.

type field can have 3 values:
- terminal
- text
- buffer [Still experimental]

Return value of select callback determines the content of preview window.

If preview type is terminal then function provided as select callback should
return a table with attributes:
- cmd : Command to be executed in terminal
- cwd [optional] : Working directory in which terminal should be opened.

If preview type is text then function provided as select callback should return
a table with attributes:
- data : text to be displayed (list(table) of strings)
- line : line to be highlighted with different color

If preview type is buffer then function provided as select callback should return
a table with attributes:
- filename : filename that should be displayed in preview.
- line : line number that should be highlighted in file.

## Some plugins based on this API

- https://github.com/RishabhRD/nvim-lsputils
	This plugin provides comfortable UI for LSP actions(code fix, references)
	for neovim 0.5 built-in LSP client.
