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

![](https://user-images.githubusercontent.com/26287448/100769832-964b9400-3422-11eb-934c-db1e7ecada08.gif)


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

	<details>
	<summary>Click to see all screenshots</summary>
	<br>
	<img src="https://user-images.githubusercontent.com/26287448/100777730-33f79100-342c-11eb-904e-9df3786e4c84.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100777113-65bc2800-342b-11eb-8d28-28a191aa2ae0.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100777492-e4b16080-342b-11eb-8f8b-16ab647bba64.gif">
	</details>

- **Preview Popup**
	
	A popup list of elements with a preview window that can be configured by
	user.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)

	<details>
	<summary>Click to see all screenshots</summary>
	<br>
	<img src="https://user-images.githubusercontent.com/26287448/100772505-add84c00-3425-11eb-9288-671eaf8d89ff.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100772166-49b58800-3425-11eb-95da-49e883df8d40.gif">
	</details>

	(Preview window doesn't have cursor mode currently. This is because I don't
	have great idea about what it should look like. Make a PR if you have any
	good idea.)

- **Text**

	A simple prompt window where user can enter some text as input.

	Rendering modes:
	- Editor (Relative to neovim editor window)
	- Cursor (On cursor itself)

	<details>
	<summary>Click to see all screenshots</summary>
	<br>
	<img src="https://user-images.githubusercontent.com/26287448/100778573-30183e80-342d-11eb-9665-3bc8bf45a921.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100778387-f810fb80-342c-11eb-8744-474ab8996ff5.gif">
	</details>

	(Currently working on split mode)

- **Prompt Popup**

	A popup list of elements with a prompt having fuzzy finding capabilities by
	default.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)
	- Cursor (On the cursor itself)

	<details>
	<summary>Click to see all screenshots</summary>
	<br>
	<img src="https://user-images.githubusercontent.com/26287448/100773857-6e126400-3427-11eb-8241-5504615ac700.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100774175-d06b6480-3427-11eb-89b2-b98d24ed4209.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100775103-d0b82f80-3428-11eb-9aae-23582a21faec.gif">
	</details>

- **Prompt Preview Popup**

	A popup list of elements with a prompt and preview window having fuzzy
	finding capabilities by default.

	Rendering modes:
	- Split (In a down split)
	- Editor (Relative to neovim editor window)

	<details>
	<summary>Click to see all screenshots</summary>
	<br>
	<img src="https://user-images.githubusercontent.com/26287448/100769832-964b9400-3422-11eb-934c-db1e7ecada08.gif">
	<img src="https://user-images.githubusercontent.com/26287448/100771655-ae241780-3424-11eb-8d82-65b097bbfbbb.gif">
	</details>

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
		bufnr = 0, -- Current buffer is represented by 0
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
### Sorter

Sorter provides the sorting algorithm, filter algorithm and highlighting
algorithm.

For using builtin sorters:
- fzy-native

	```lua
	require'popfix.sorter'.new_fzy_native_sorter(case_sensitive)
	```

- fzy (default)

	```lua
	require'popfix.sorter'.new_fzy_sorter(case_sensitive)
	```

case_sensitive is boolean that indicates if sorting algorithm is case_sensitive
or not.

You can also create new sorters:
```lua
local sorter = require'popfix.sorter'.new{
	sorting_function = function(prompt_text, comparing_text, case_sensitive)
		-- scoring logic here
	end,
	filter_function = function(prompt_text, comparing_text, case_sensitive)
		-- scoring logic here
	end,
	highlighting_function = function(prompt_text, comparing_text, case_sensitive)
		-- scoring logic here
	end
}
```

filter_function should return a boolean indicating comparing_text should be
listed in results or not.

sorting_function should return a score. Higher score value means better score.

highlighting_function should return array of integers representing columns need
to be highlighted for comparing_text. Column should be 0 indexed.
eg: {0, 3, 5, 9}

### Fuzzy Engine
Fuzzy Engine schedules the job for fuzzy search. This actually sorts the
result according to sorter's algorithm and then send it to a manager using
add method of manager.

Popfix provides 2 built-in fuzzy engines:

- SingleExecutionEngine (default)

	Executes submitted job one time and sorts the whole thing when prompt
	change.
	```lua
	require'popfix.fuzzy_enigne'.new_SingleExecutionEngine()
	```

- RepeatedExecutionEngine
	
	Executes the submitted job (with formatted command) everytime prompt is
	changed and displays the output as result. It only uses the highlighting
	part of sorter.

	Because command need to be formatted, it should be given in special format
	string. For example: ``rg --vimgrep %s`` . This %s will be replaced with
	current prompt text while running the job. So, be careful while entering
	data in opts.
	```lua
	require'popfix.fuzzy_enigne'.new_RepeatedExecutionEngine()
	```

You can also create new fuzzy engines. Fuzzy engines have 2 tables:
- list : Fuzzy engines are expected to fill this array with strings obtained
  from submitted job.
- sortedList : Fuzzy engines are expected to fill this array with a table with
  synatx:
	```lua
	{
		score = <score : int>,
		index = <index of element in list : int>
	}
	```
UI manager use these table to render UI efficiently. However, this is not
necessary that fuzzy engine follow the expectation, i.e., until unless fuzzy
engine is filling the table with proper syntax that means ``list`` with string
array and ``sortedList`` with example table, UI manager would work properly
till the index part of sortedList table entry is valid in list.
You can fill data smartly to create different behaviour you may want to have.

To create a new fuzzy engine:

```lua
require'popfix.fuzzy_engine'.new{
	run = function(opts)
	end,
	close = function()
	end
}
```

run is the function that will start fuzzy engine. It accepts an opts parameter
that has 4 fields
- data (data provided while calling new function of popfix)
- manager (render manger)
- sorter (sorter class)
- currentPromptText: currentPromptText during intialisation

manager is the utility that takes cares of actual rendering.
It has 2 methods:
- add(line, first, last, index) : add the line to UI list at first index,
ending on last index (replacing first to last, i.e, first = last if no
replacement is needed). index represents the index of line in sorted list.

- clear() : clear the list's UI.
	



## Some plugins built upon popfix

- https://github.com/RishabhRD/nvim-lsputils
	This plugin provides comfortable UI for LSP actions(code fix, references)
	for neovim 0.5 built-in LSP client.
