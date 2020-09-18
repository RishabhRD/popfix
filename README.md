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
![](https://user-images.githubusercontent.com/26287448/93617977-4e58cb80-f9f4-11ea-9406-6e0ff0f2ec93.gif)

## Features

- Floating popup
- Navigable preview window

## Future goals

- Floating preview
- Fuzzy search
