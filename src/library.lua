-- The distribution embeds the three UI factories above this module.
local Library={Version="1.0.0",__ThalassarUILibrary=true}
local windows={}
local function falseValue() return false end
local function call(callback,...)
    if type(callback)=="function" then return pcall(callback,...) end
    return true
end
local function disconnect(connection)
    if connection then pcall(function() connection:Disconnect() end) end
end
local function service(name)
    local ok,value=pcall(function() return game:GetService(name) end)
    if ok then return value end
end
local function connect(signal,callback)
    if not signal then return nil end
    local ok,value=pcall(function() return signal:Connect(callback) end)
    if ok then return value end
end

-- Windows VK codes are retained across adapters so saved bindings remain portable.
local function keyMap()
    local map={}
    if not Enum or not Enum.KeyCode then return map end
    local function add(code,name)
        local ok,value=pcall(function() return Enum.KeyCode[name] end)
        if ok and value then map[code]=value end
    end
    for code=65,90 do add(code,string.char(code)) end
    local digits={"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"}
    for i,name in ipairs(digits) do add(47+i,name) end
    for code=112,135 do add(code,"F"..tostring(code-111)) end
    local names={[8]="Backspace",[9]="Tab",[13]="Return",[16]="LeftShift",[17]="LeftControl",[18]="LeftAlt",
        [27]="Escape",[32]="Space",[33]="PageUp",[34]="PageDown",[35]="End",[36]="Home",[37]="Left",[38]="Up",[39]="Right",[40]="Down",
        [45]="Insert",[46]="Delete",[160]="LeftShift",[161]="RightShift",[162]="LeftControl",[163]="RightControl",[164]="LeftAlt",[165]="RightAlt",
        [186]="Semicolon",[187]="Equals",[188]="Comma",[189]="Minus",[190]="Period",[191]="Slash",[192]="Backquote",[219]="LeftBracket",[220]="BackSlash",[221]="RightBracket",[222]="Quote"}
    for code,name in pairs(names) do add(code,name) end
    return map
end

function Library:CreateWindow(options)
    options=options or {}
    assert(type(options)=="table","CreateWindow expects an options table")
    local backend=options.Drawing or Drawing
    assert(backend and type(backend.new)=="function","Thalassar UI requires a Drawing backend")
    assert(Color3 and Vector2,"Thalassar UI requires Color3 and Vector2")
    local mode=options.InputAdapter or "auto"
    assert(mode=="auto" or mode=="none" or mode=="matcha" or mode=="roblox","Unknown InputAdapter")
    if mode=="auto" then mode=type(iskeypressed)=="function" and type(ismouse1pressed)=="function" and "matcha" or "roblox" end
    if options.Singleton~=false then self:DestroyAll() end

    local window={}; local closed=false; local menu; local bridge; local connections={}
    local effects=createThalassarBackgroundEffects()
    local fault,frameConnection
    local keyReader,mouseReader=options.IsKeyPressed,options.IsMousePressed
    local typingReader=options.Typing
    local mouse=options.Mouse
    local consume=options.ConsumeWheel
    local wheelSource=consume and "custom" or "manual"
    local function onError(message)
        fault=tostring(message)
        call(options.OnError,fault)
    end
    local function cleanup(reason)
        if closed then return end
        closed=true
        for _,connection in ipairs(connections) do disconnect(connection) end
        disconnect(frameConnection); frameConnection=nil
        if bridge then bridge.close() end
        if menu then menu.destroy() end
        for i=#windows,1,-1 do if windows[i]==window then table.remove(windows,i) end end
        call(options.OnClose,reason or "destroy")
    end
    function window:Destroy() cleanup("destroy") end

    if mode=="matcha" then
        keyReader=keyReader or (type(iskeypressed)=="function" and iskeypressed) or falseValue
        mouseReader=mouseReader or (type(ismouse1pressed)=="function" and ismouse1pressed) or falseValue
        if not consume and options.MatchaWheel~=false and options.Singleton~=false and type(readfile)=="function" and type(writefile)=="function" and type(isfile)=="function" then
            local prefix=options.WheelFilePrefix or "Thalassar-UI"
            assert(type(prefix)=="string" and prefix:match("^[%w_-]+$"),"WheelFilePrefix must contain only letters, digits, underscores or dashes")
            bridge=createWheelBridge(prefix)
            consume=bridge.consume; wheelSource="matcha companion"
        end
    elseif mode=="roblox" then
        local input=service("UserInputService")
        local gui=service("GuiService")
        local map=keyMap()
        if input and Enum then
            keyReader=keyReader or function(code)
                if code==16 then return input:IsKeyDown(map[160]) or input:IsKeyDown(map[161]) end
                if code==17 then return input:IsKeyDown(map[162]) or input:IsKeyDown(map[163]) end
                if code==18 then return input:IsKeyDown(map[164]) or input:IsKeyDown(map[165]) end
                return map[code]~=nil and input:IsKeyDown(map[code])
            end
            mouseReader=mouseReader or function() return input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
            typingReader=typingReader or function() return input:GetFocusedTextBox()~=nil end
            local function position()
                local point=input:GetMouseLocation()
                local inset=Vector2.new(0,0)
                if gui then local ok,value=pcall(function() return gui:GetGuiInset() end); if ok and value then inset=value end end
                return point.X-inset.X,point.Y-inset.Y
            end
            if not mouse then mouse=setmetatable({},{__index=function(_,key)
                local x,y=position(); if key=="X" then return x elseif key=="Y" then return y end
            end}) end
            if not consume then
                local pending,px,py=0,0,0
                local connection=connect(input.InputChanged,function(event)
                    if closed or event.UserInputType~=Enum.UserInputType.MouseWheel then return end
                    local x,y=position()
                    if menu and menu.isInteracting() then
                        local regions=menu.scrollRegions(); local region=regions.window
                        if region and x>=region.x and x<=region.x+region.w and y>=region.y and y<=region.y+region.h then
                            pending=pending+(event.Position.Z or 0); px,py=x,y
                        end
                    end
                end)
                if connection then
                    connections[#connections+1]=connection; wheelSource="native"
                    consume=function() local value=pending; pending=0; return value,px,py end
                end
            end
        end
    end
    keyReader=keyReader or falseValue; mouseReader=mouseReader or falseValue
    local constructionOK,value=pcall(function()
        return createThalassarUI({
            title=options.Title or "Thalassar UI",footer=options.Footer,
            visible=options.Visible~=false,appearance=options.Appearance,
            mouse=mouse,viewport=options.Viewport,drawing=backend,fonts=options.Fonts,
            key=keyReader,mouseDown=mouseReader,focused=options.Focused,typing=typingReader,
            consumeWheel=consume,
            drawBackgroundEffects=function(painter) effects.draw(painter) end,
            onError=onError,onClose=function() cleanup("close") end,
            onVisibility=options.OnVisibility,onAppearanceChanged=options.OnAppearanceChanged,
        })
    end)
    if not constructionOK then cleanup("construction error"); assert(false,tostring(value)) end
    menu=value
    effects.install(menu.BackgroundSection)
    if options.Background then effects.import(options.Background) end
    if bridge then bridge.setUI(menu) end
    window.UI=menu; window.Effects=effects
    window.SettingsSection=menu.SettingsSection; window.BackgroundSection=menu.BackgroundSection
    function window:Tab(name,builder) return menu.AddTab(name,builder) end
    function window:RemoveTab(name) return menu.RemoveTab(name) end
    function window:GetValue(id) return menu.GetValue(id) end
    function window:SetValue(id,...) return menu.SetValue(id,...) end
    function window:Show() if not closed then menu.setVisible(true) end; return self end
    function window:Hide() if not closed then menu.setVisible(false) end; return self end
    function window:Toggle() if not closed then menu.setVisible(not menu.visible()) end; return self end
    function window:SelectSection(name) return not closed and menu.selectSection(name) end
    function window:Scroll(delta,x,y) if closed then return false end; return menu.scroll(delta,x,y) end
    function window:ScrollRegions() return menu.scrollRegions() end
    function window:ExportConfig()
        return {Version=1,Appearance=menu.exportAppearance(),Values=menu.exportValues(),Background=effects.export()}
    end
    function window:ImportConfig(config,notify)
        if closed or type(config)~="table" or config.Version~=1 then return false end
        if type(config.Appearance)=="table" then menu.importAppearance(config.Appearance) end
        if closed then return false end
        if type(config.Values)=="table" then menu.importValues(config.Values,notify==true) end
        if closed then return false end
        if type(config.Background)=="table" then effects.import(config.Background) end
        return not closed
    end
    function window:ResetAppearance() return not closed and menu.resetAppearance() end
    function window:Status()
        local state=menu.status(); state.version=Library.Version; state.error=fault or state.error
        state.inputAdapter=mode; state.wheelSource=wheelSource; state.automaticUpdate=frameConnection~=nil
        if bridge then state.wheel=bridge.status() end
        return state
    end
    function window:Step(dt)
        if closed then return false end
        local ok,message=pcall(function() menu.step(dt); if bridge and not closed then bridge.update() end end)
        if not ok then onError(message); cleanup("render error") end
        return ok and not closed
    end
    windows[#windows+1]=window
    if options.ManualUpdate~=true then
        local run=options.RunService or service("RunService")
        frameConnection=connect(run and run.RenderStepped,function(dt) window:Step(dt) end)
        if not frameConnection then cleanup("missing frame event"); assert(false,"RenderStepped unavailable; use ManualUpdate=true and call window:Step(dt)") end
    end
    return window
end

function Library:DestroyAll()
    local snapshot={}
    for i,window in ipairs(windows) do snapshot[i]=window end
    for _,window in ipairs(snapshot) do window:Destroy() end
end

local previous=_G.ThalassarUI
if previous and previous.__ThalassarUILibrary==true and type(previous.DestroyAll)=="function" then call(previous.DestroyAll,previous) end
_G.ThalassarUI=Library
return Library
