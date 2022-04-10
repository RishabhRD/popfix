local preview = require("popfix.preview")
local list = require("popfix.list")
local action = require("popfix.action")
local autocmd = require("popfix.autocmd")
local mappings = require("popfix.mappings")
local Job = require("popfix.job")
local util = require("popfix.util")
local api = vim.api

local M = {}

local listNamespace = api.nvim_create_namespace("popfix.preview_popup")

function M:close(callback)
    if self.closed then
        return
    end
    self.closed = true
    if self.job then
        self.job:shutdown()
        self.job = nil
    end
    local line = self.action:getCurrentLine()
    local index = self.action:getCurrentIndex()
    mappings.free(self.list.buffer)
    autocmd.free(self.list.buffer)
    vim.schedule(function()
        self.list:close()
        self.preview:close()
        if self.splitWindow then
            api.nvim_win_close(self.splitWindow, true)
            self.splitWindow = nil
        end
        if api.nvim_win_is_valid(self.originalWindow) then
            api.nvim_set_current_win(self.originalWindow)
        end
        self.action:close(index, line, callback)
    end)
end

local function selectionHandler(self, callback)
    local listSize = self.list:getSize()
    -- handle the situation where no element is there in list
    -- and the callback is triggered.
    if listSize == 0 then
        return
    end
    local oldIndex = self.action:getCurrentIndex()
    local line = self.list:getCurrentLineNumber()
    if oldIndex ~= line then
        api.nvim_buf_clear_namespace(self.list.buffer, listNamespace, 0, -1)
        api.nvim_buf_add_highlight(
            self.list.buffer,
            listNamespace,
            self.list.selection_highlight,
            line - 1,
            0,
            -1
        )
        local data = self.action:select(
            line,
            self.list:getCurrentLine(),
            callback
        )
        if data ~= nil then
            self.preview:writePreview(data)
        end
    end
end

local function popup_editor(self, opts)
    local editorWidth = api.nvim_get_option("columns")
    local editorHeight = api.nvim_get_option("lines")
    opts.list.height = opts.height or math.ceil((editorHeight * 0.8 - 4))
    opts.height = opts.list.height
    --TODO: better resize strategy
    if 2 * editorHeight > editorWidth then
        opts.list.height = opts.height
            or math.ceil((editorHeight * 0.8 - 4) / 2)
    end
    if opts.height >= api.nvim_get_option("lines") - 4 then
        print("no enough space to draw popup")
        return
    end
    if opts.width then
        opts.list.width = math.floor(opts.width / 2)
    else
        opts.list.width = math.ceil(editorWidth * 0.8 / 2)
        opts.width = math.ceil(editorWidth * 0.8) + 1
    end
    if opts.width >= api.nvim_get_option("columns") - 4 then
        print("no enough space to draw popup")
        return
    end
    opts.list.row = math.ceil((editorHeight - opts.list.height) / 2 - 1)
    opts.list.col = math.ceil((editorWidth - 2 * opts.list.width) / 2)
    self.list = list:new(opts.list)
    if not self.list then
        return false
    end
    opts.preview.width = opts.list.width
    opts.preview.height = opts.list.height
    opts.preview.row = opts.list.row
    opts.preview.col = opts.list.col + opts.list.width
    self.preview = preview:new(opts.preview)
    if not self.preview then
        self.list:close()
        return false
    end
    return true
end

local function popup_split(self, opts)
    opts.list.height = opts.height or 12
    opts.height = opts.list.height
    if opts.height >= api.nvim_get_option("lines") - 4 then
        print("no enough space to draw popup")
        return
    end
    self.list = list:newSplit(opts.list)
    if not self.list then
        return false
    end
    api.nvim_set_current_win(self.list.window)
    vim.cmd("vnew")
    if not api.nvim_get_option("splitright") then
        vim.cmd("wincmd r")
    end
    self.splitWindow = api.nvim_get_current_win()
    local splitBuffer = api.nvim_get_current_buf()
    api.nvim_buf_set_option(splitBuffer, "bufhidden", "wipe")
    api.nvim_set_current_win(self.originalWindow)
    opts.preview.width = api.nvim_win_get_width(self.list.window)
    opts.preview.height = api.nvim_win_get_height(self.list.window)
    opts.preview.row = api.nvim_win_get_position(self.list.window)[1]
    opts.preview.col = opts.preview.width
    self.preview = preview:new(opts.preview)
    if not self.preview then
        self.list:close()
        api.nvim_win_close(self.splitWindow)
        return false
    end
    return true
end

function M:new(opts)
    self.__index = self
    local obj = {}
    setmetatable(obj, self)
    obj.close_on_error = opts.close_on_error
    obj.action = action:new(opts.callbacks)
    if opts.data == nil then
        print("nil data")
        return false
    end
    if opts.mode == "cursor" then
        print("cursor mode is not supported for preview! (yet)")
    end
    if opts.list == nil or opts.preview == nil then
        print("No attributes found")
        return false
    end
    opts.preview.mode = opts.mode
    opts.preview.list_border = opts.list.border
    obj.originalWindow = api.nvim_get_current_win()
    if opts.mode == "split" then
        if not popup_split(obj, opts) then
            obj.originalWindow = nil
            return false
        end
    elseif opts.mode == "editor" then
        if not popup_editor(obj, opts) then
            obj.originalWindow = nil
            return false
        end
    end
    local nested_autocmds
    if opts.close_on_bufleave then
        nested_autocmds = {
            ["BufLeave,BufUnload"] = obj.close,
            ["nested"] = true,
            ["once"] = true,
        }
    else
        nested_autocmds = {
            ["BufUnload"] = obj.close,
            ["nested"] = true,
            ["once"] = true,
        }
    end
    local non_nested_autocmds = {
        ["CursorMoved"] = selectionHandler,
    }
    autocmd.addCommand(obj.list.buffer, nested_autocmds, obj)
    autocmd.addCommand(obj.list.buffer, non_nested_autocmds, obj)
    obj:set_data(opts.data)
    if opts.keymaps then
        mappings.add_keymap(obj.list.buffer, opts.keymaps, obj)
    end
    api.nvim_set_current_win(obj.list.window)
    obj.closed = false
    return obj
end

function M:select_next()
    self.list:select_next()
end

function M:select_prev()
    self.list:select_prev()
end

function M:set_data(data)
    self.action.selection.index = nil
    self.action.selection.line = nil
    -- cancel any job running
    if self.job then
        self.job:shutdown()
        self.job = nil
    end
    if data.cmd then
        local cmd, args = util.getArgs(data.cmd)
        vim.schedule(function()
            self.list:clear()
        end)
        self.job = Job:new({
            command = cmd,
            args = args,
            cwd = data.cwd or vim.fn.getcwd(),
            on_stdout = vim.schedule_wrap(function(_, line)
                if self.list then
                    self.list:addData({ line })
                    if not self.first_added then
                        self.first_added = true
                    end
                end
            end),
            on_exit = function()
                --TODO: is doing nil doesn't leak resources
                self.action:complete_job()
                self.job = nil
            end,
            on_stderr = function(err, line)
                if err then
                    if self.close_on_error then
                        vim.schedule(function()
                            self:close(function()
                                util.printError(line)
                            end)
                        end)
                    end
                elseif line then
                    if self.close_on_error then
                        vim.schedule(function()
                            self:close(function()
                                util.printError(line)
                            end)
                        end)
                    end
                end
            end,
        })
        self.job:start()
    else
        vim.schedule(function()
            self.list:setData(data, 0, -1)
        end)
    end
end

function M:get_current_selection()
    return self.action:getCurrentIndex(), self.action:getCurrentLine()
end

return M
