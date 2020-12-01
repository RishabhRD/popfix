# popfix

popfix is a neovim API that helps plugin developers to write UI for their
plugins easily.
popfix internally handles UI rendering and its lifetime and makes plugin
developers to focus much on plugin logic and less on UI.

popfix targets UI where either user have to give some input or user have to
select something from a list of elements. Because these are most common
operations most plugins need to do. However, popfix is very customizable and
extensible that many of its default behaviour can be changed.

Also normal users can use this API to provide fancy UI for some common tasks.


## Screenshots
<!-- ![](https://user-images.githubusercontent.com/26287448/93617774-076ad600-f9f4-11ea-9c4e-d37019241320.gif) -->
<!-- ![](https://user-images.githubusercontent.com/26287448/93930985-d3691b00-fd3b-11ea-9053-b699e4d36558.gif) -->

## Prerequisites

- Neovim nightly

## Install

Install with any plugin manager. For example with vim-plug

	Plug 'RishabhRD/popfix'


## UI possible with popfix

- **Popup**

	A simple popup list of elements.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)
	- Cursor (On the cursor itself)

- **Preview Popup**
	
	A popup list of elements with a preview window that can be configured by
	user.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)

	(Preview window doesn't have cursor mode currently. This is because I don't
	have great idea about what it should look like. Make a PR if you have any
	good idea.)

- **Text**

	A simple prompt window where user can enter some text as input.

	Rendering modes:
	- Editor (Relative to neovim editor window)
	- Cursor (On cursor itself)

	(Currently working on split mode)

- **Prompt Popup**

	A popup list of elements with a prompt having fuzzy finding capabilities by
	default.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)
	- Cursor (On the cursor itself)

- **Prompt Preview Popup**

	A popup list of elements with a prompt and preview window having fuzzy
	finding capabilities by default.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)

	(Preview window doesn't have cursor mode currently. This is because I don't
	have great idea about what it should look like. Make a PR if you have any
	good idea.)

## Components

Popfix contains following components to build the UI:

- List
- Preview
- Prompt
- Sorter
- Fuzzy Engine


Because sorter and fuzzy engine defines how prompt popup and prompt preview
popup would behave and hence are very extensible and customizable. Infact users
can provide their own sorter and fuzzy engine.

Other components are UI components and their working is quite obvious and
are very customizable in terms of look and behaviour.

## API Description

### How to invoke plugin

Example (in most descriptive way, infact many of these options are optional):

```lua
local border_chars = {
	TOP_LEFT = '┌',
	TOP_RIGHT = '┐',
	MID_HORIZONTAL = '─',
	MID_VERTICAL = '│',
	BOTTOM_LEFT = '└',
	BOTTOM_RIGHT = '┘',
}

local function select_callback(index, line)
	-- function job here
end

local function close_callback(index, line)
	-- function job here
end

local opts = {
	height = 40,
	width = 120,
	mode = 'editor',
	close_on_bufleave = true,
	data = <data-table>, -- Read below how to provide this.
	keymaps = {
		i = {
			['<Cr>'] = function(popup)
				popup:close(select_callback)
			end
		},
		n = {
			['<Cr>'] = function(popup)
				popup:close(select_callback)
			end
		}
	}
	callbacks = {
		select = select_callback, -- automatically calls it when selection changes
		close = close_callback, -- automatically calls it when window closes.
	}
	list = {
		border = true,
		numbering = true,
		coloring = true,
		title = 'MyTitle',
		border_chars = border_chars
	},
	preview = {
		type = 'terminal'
		border = true,
		numbering = true,
		coloring = true,
		title = 'MyTitle',
		border_chars = border_chars
	},
	prompt = {
		border = true,
		numbering = true,
		coloring = true,
		title = 'MyTitle',
		border_chars = border_chars
	},
	sorter = require'popfix.sorter'.new_fzy_native_sorter(true),
	fuzzyEngine = require'popfix.fuzzy_engine'.new_SingleExecutionEngine()
}

local popup = require'popfix':new(opts)
```

``popup`` returned by the new function is the resource created by popfix.
If everything works well, it returns the resource otherwise false.

### Options description

list, preview, prompt, sorter, fuzzyEngine describes the components to render
UI. (See Components section)

If sorter and fuzzyEngine is not provided, popfix provides a suitable defaults
for it.

Popfix manipulates the UI on basis of list, preview and prompt options. So, for
example, if only list is provided then a Popup would render. If list and
preview both are provided then Preview Popup would render. Similarily, if list,
preview and prompt are provided then a Prompt Preview Popup would render.

See UI possible with popfix section for reasonable combinations possible with
popfix. Naming convention and options are non surprising.

list, preview and prompt have some common attributes (all of them are optional):
- **border** (boolean): If border should be there around corresponding window.
- **border_chars** (table): border chars to be used for borders. See example
	for border_chars syntax.
- **coloring** (boolean): a different color for background window than normal.
- **title** (string): title of window.
- **numbering** (boolean): whether vim line number should be displayed.

preview also provides an additional attribute (this is mendatory):
- **type** (string): Defines the type of preview window to render.
	Supported types:
	- terminal: Preview window would be a terminal window.
	- text: Preview window would display some text.
	- buffer: Preview window is an existing neovim buffer.

prompt also provides some additional attributes (these are optional):
- **prompt_text** (string): Prompt command text
- **init_text** (string): Initial text that is written in prompt when window
	is opened.

#### height [optional] [int]

Height of rendered window. (Height would be divided for components internally)

#### width [optional] [int]

Overall width of rendered window. (Width would be divided for components
internally)

#### close_on_bufleave [optional] [boolean]

Window should be closed when user leaves the buffer.
(Default: false)

#### mode [string]

Defines the rendering mode:

- Split
- Editor
- Cursor

#### data [table]

If you wanna display some list of string from lua itself then this table is an
array of strings.

Example: ``data = {"Hello", "World"}``

If you want to display the output of some command then, this table should be of
format:
```lua
data = {
	cmd = 'command here',
	cwd = 'directory from which this command should be launched.',
}
```

#### keymaps [optional] [table]

Keymaps are expressed as lua tables. Currently only normal mode and insert mode
keymappings are supported. n represents normal mode, i represents the insert
mode.

Any lua function or string can be provided as value to key.
Lua function have syntax:
```lua
function(popup)
end
```
where popup is the resource that was created by new function.

For example:
```lua
{
	i = {
		['<C-n>'] = function(popup)
			popup:select_next()
		end
	},
	n = {
		['q'] = ':q!'
	}
}
```


#### callbacks [optional]

API provides 2 callbacks on which plugins can react:

- select [optional]
- close  [optional]

See example for callbacks syntax.

The values for these callbacks are a function with syntax:

```lua
function(index, line)
	-- process and return data for preview if there.
end
```

index represents the index of currently selected element, i.e., its position
while adding.

line represents the string of line of currently selected element.

If preview is enabled then these function should return value for preview based
on preview type.

For different preview types return value should be:
- **terminal**

	Lua table with format:
	```lua
	{
		cmd = 'command here',
		cwd = 'directory from which this command should be launched.'
	}
	```
- **text**
	```lua
	{
		data = {'string', 'array'}, -- A string array
		line = 4 -- Line to be highlighted [optional]
	}
	```

- **buffer**
	```lua
	{
		filename = '/home/user/file', -- Filename of buffer
		line = 4 -- Line to be highlighted [optional]
	}
	```

### Methods exported by popfix resource
Every resource of popfix created by ``require'popfix'.new(opts)`` exports some
methods that can be called with syntax: ``resource:func(param)``

where resource is the resource returned by new function, func is the method
which is being called and param is parameter to the function.

The table shows the function exported by different resources:

|Function|Popup|Preview Popup|Text |Prompt Popup|Prompt Preview Popup|
|--------|:---:|:-----------:|:---:|:----------:|:------------------:|
|**set_data**|:heavy_check_mark:|:heavy_check_mark:||:heavy_check_mark:|:heavy_check_mark:|
|**get_current_selection**|:heavy_check_mark:|:heavy_check_mark:||:heavy_check_mark:|:heavy_check_mark:|
|**set_prompt_text**|||:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|
|**select_next**|:heavy_check_mark:|:heavy_check_mark:||:heavy_check_mark:|:heavy_check_mark:|
|**select_prev**|:heavy_check_mark:|:heavy_check_mark:||:heavy_check_mark:|:heavy_check_mark:|
|**close**|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|:heavy_check_mark:|

If you feel any useful method is missing here, please raise a issue or submit a
PR:smiley:.

#### Method description

- **set_data**

	Syntax: ``set_data(data)``

	@param data -> table : new data for resource.

- **get_current_selection**

	Syntax: ``get_current_selection() : index, line``

	@return index -> integer : represents currently selected index

	@return line -> string : represents currently selected string

- **set_prompt_text**

	Syntax: ``set_prompt_text(text)``

	@param text -> string : text to set to new prompt

- **select_next**

	Syntax: ``select_next(callback)``

	@param callback -> function : callback is called after selection change is
	done. Callback is a function with syntax:
	```lua
	function(index, line)
	end
	```
	If preview is enabled callback is expected to return appropriate data for
	preview according to preview type.
	(See callbacks section for appropriate data for preview)

- **select_prev**

	Syntax: ``select_prev(callabck)``

	@param callback -> function : same as select_next's callback

- **close**

	Syntax: ``close(callback)``

	@param callback -> function : callback is called when window is closed
	properly. Callback is a function with syntax:
	```lua
	function(index, line)
	```

## Some plugins based on this API

- https://github.com/RishabhRD/nvim-lsputils
	This plugin provides comfortable UI for LSP actions(code fix, references)
	for neovim 0.5 built-in LSP client.
