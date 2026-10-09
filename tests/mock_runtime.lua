-- Minimal native Drawing and input bindings for offline public API checks.
-- Every Drawing write is validated, including writes after removal.
local Runtime = {
    drawings = {}, made = 0, removed = 0, keys = {}, mouse = {X = 0, Y = 0},
    focused = true, typing = false, connections = {}, files = {}, time = 1000,
}
local _G = {}
local Color3 = {
    fromRGB = function(r, g, b) return {R = r / 255, G = g / 255, B = b / 255} end,
    new = function(r, g, b) return {R = r, G = g, B = b} end,
}
local Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local Vector3 = {new = function(x, y, z) return {X = x, Y = y, Z = z} end}
local shared = {
    Visible = true, Color = true, Transparency = true, Thickness = true,
    ZIndex = true, Outline = true, Filled = true, Corner = true,
}
local allowed = {
    Square = {Position = true, Size = true},
    Circle = {Position = true, Radius = true, NumSides = true},
    Line = {From = true, To = true},
    Text = {Text = true, Position = true, Size = true, Center = true, Font = true},
    Triangle = {PointA = true, PointB = true, PointC = true},
}
local Drawing = {}
function Drawing.new(kind)
    assert(allowed[kind], "unsupported Drawing kind: " .. tostring(kind))
    local values = {}
    local record = {kind = kind, properties = values, dead = false}
    Runtime.made += 1
    Runtime.drawings[#Runtime.drawings + 1] = record
    local object = setmetatable({}, {
        __index = function(_, name)
            if name == "Remove" or name == "Destroy" then
                return function()
                    assert(not record.dead, "Drawing removed twice")
                    record.dead = true
                    values.Visible = false
                    Runtime.removed += 1
                end
            end
            if name == "TextBounds" then
                return Vector2.new(#tostring(values.Text or "") * (values.Size or 14) * .52, values.Size or 14)
            end
            return values[name]
        end,
        __newindex = function(_, name, value)
            assert(not record.dead, "Drawing write after removal: " .. kind .. "." .. name)
            assert(shared[name] or allowed[kind][name], "unsupported Drawing property: " .. kind .. "." .. name)
            if name == "Position" or (name == "Size" and kind ~= "Text") or name == "From" or name == "To" then
                assert(type(value) == "table" and type(value.X) == "number" and type(value.Y) == "number", "expected Vector2")
            end
            values[name] = value
        end,
    })
    record.object = object
    return object
end
local function signal()
    local callbacks = {}
    local event = {}
    function event:Connect(callback)
        local connection = {Connected = true, callback = callback}
        function connection:Disconnect() self.Connected = false end
        callbacks[#callbacks + 1] = connection
        Runtime.connections[#Runtime.connections + 1] = connection
        return connection
    end
    function event:Fire(...)
        for _, connection in ipairs(callbacks) do
            if connection.Connected then connection.callback(...) end
        end
    end
    return event
end
Runtime.render = signal()
Runtime.inputChanged = signal()
Runtime.inputBegan = signal()
Runtime.inputEnded = signal()
Runtime.windowFocused = signal()
Runtime.windowFocusReleased = signal()
local Enum = {
    UserInputType = {MouseWheel = "MouseWheel", MouseButton1 = "MouseButton1", Keyboard = "Keyboard"},
    KeyCode = {Unknown = {Value = 0}},
}
for code = 65, 90 do Enum.KeyCode[string.char(code)] = {Value = code} end
for code = 112, 135 do Enum.KeyCode["F" .. (code - 111)] = {Value = code} end
local keyNames = {[8] = "Backspace", [9] = "Tab", [13] = "Return", [16] = "LeftShift", [17] = "LeftControl", [18] = "LeftAlt",
    [27] = "Escape", [32] = "Space", [160] = "LeftShift", [161] = "RightShift", [162] = "LeftControl", [163] = "RightControl",
    [164] = "LeftAlt", [165] = "RightAlt"}
for code, name in pairs(keyNames) do Enum.KeyCode[name] = {Value = code} end
local digitNames = {"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
for i, name in ipairs(digitNames) do Enum.KeyCode[name] = {Value = 47 + i} end
Runtime.inset = Vector2.new(0, 36)
local services = {
    RunService = {RenderStepped = Runtime.render},
    UserInputService = {
        InputChanged = Runtime.inputChanged, InputBegan = Runtime.inputBegan, InputEnded = Runtime.inputEnded,
        WindowFocused = Runtime.windowFocused, WindowFocusReleased = Runtime.windowFocusReleased,
        GetMouseLocation = function() return Vector2.new(Runtime.mouse.X, Runtime.mouse.Y) end,
        IsKeyDown = function(_, key) return Runtime.keys[type(key) == "table" and key.Value or key] == true end,
        IsMouseButtonPressed = function() return Runtime.keys[1] == true end,
        GetFocusedTextBox = function() return Runtime.typing and {} or nil end,
    },
    Players = {LocalPlayer = {GetMouse = function() return Runtime.mouse end}},
    GuiService = {GetGuiInset = function() return Runtime.inset, Vector2.new(0, 0) end},
    HttpService = {},
}
local game = {GetService = function(_, name)
    assert(services[name], "unexpected service: " .. tostring(name))
    return services[name]
end}
local workspace = {CurrentCamera = {ViewportSize = Vector2.new(1920, 1080)}}
local function iskeypressed(vk) return Runtime.keys[vk] == true end
local function ismouse1pressed() return Runtime.keys[1] == true end
local function isrbxactive() return Runtime.focused end
local function tick() return Runtime.time end
local function readfile(path) assert(Runtime.files[path], "file missing"); return Runtime.files[path] end
local function writefile(path, value) Runtime.files[path] = value end
local function isfile(path) return Runtime.files[path] ~= nil end

function Runtime.visibleText(value)
    for _, record in ipairs(Runtime.drawings) do
        if not record.dead and record.kind == "Text" and record.properties.Visible and record.properties.Text == value then
            return record.properties
        end
    end
    return nil
end
function Runtime.visibleCount()
    local count = 0
    for _, record in ipairs(Runtime.drawings) do
        if not record.dead and record.properties.Visible then count += 1 end
    end
    return count
end
function Runtime.connectedCount()
    local count = 0
    for _, connection in ipairs(Runtime.connections) do if connection.Connected then count += 1 end end
    return count
end
