-- Thalassar UI standalone demo. MIT licensed. Interface showcase only.
local ThalassarDemoLibrary = (function()
-- Thalassar UI v1.0.0. MIT licensed. UI library only.

local createThalassarUI = (function()
-- Thalassar UI. Original Drawing-based glass renderer. MIT licensed.
-- Lexically embed the factory: Matcha discards chunk return values from loadstring.
local function createThalassarUI(ctx)
    ctx = ctx or {}
    local rgb, v2 = Color3.fromRGB, Vector2.new
    local drawingBackend=ctx.drawing or Drawing
    local title=tostring(ctx.title or "Thalassar UI")
    local fonts=ctx.fonts or {}
    local function finiteNumber(value,fallback)
        value=tonumber(value)
        if not value or value~=value or value==math.huge or value==-math.huge then return fallback end
        return value
    end
    local clamp, floor, min, max = math.clamp, math.floor, math.min, math.max
    local unpackValues = table.unpack or unpack
    local ui, tabs, pages, ids, objects, lastFrame = {}, {}, {}, {}, {}, {}
    local objectKinds={}
    local st = {alive=true, open=ctx.visible~=false, x=80, y=80, w=900, h=650,
        mx=0, my=0, prevMouse=false, prevMenu=false, prevKeys={}, time=0, count=0,
        group="Settings", active=nil, initialized=false, visibility=ctx.visible~=false and 1 or 0,
        dt=.016, animation={}, pageFade=1, navScroll=0, navTarget=0, navMax=0, regions={}}
    local theme = {Scale=1, Opacity=.64, BodyOpacity=.12, Rounding=24,
        Tint={29,32,35,255}, Accent={147,171,182,255}, Text={237,239,240,255},
        FontSize=14, Font=fonts.System or 1, Spacing=3, Grain=true, GrainStrength=.12,
        Glow=true, GlowStrength=.16, Particles=false, ParticleAmount=8,
        ParticleSpeed=.18, Vignette=false, VignetteStrength=.10,
        ReducedMotion=false, MenuKey=0x50, Specular=.42, Bevel=.24, AnimationSpeed=1}
    local defaultTheme = {}
    for k,v in pairs(theme) do defaultTheme[k]=type(v)=="table" and {unpackValues(v)} or v end
    local mouse = ctx.mouse
    if not mouse then pcall(function() mouse=game:GetService("Players").LocalPlayer:GetMouse() end) end
    local function safe(callback,...)
        if type(callback)~="function" then return true end
        local ok,err=pcall(callback,...)
        if not ok then st.error=tostring(err); if ctx.onError then pcall(ctx.onError,st.error) end end
        return ok
    end
    local function animate(id,target,speed,initial)
        local value=st.animation[id]
        if value==nil then value=initial~=nil and initial or target end
        if theme.ReducedMotion then value=target
        else value=value+(target-value)*(1-math.exp(-(speed or 20)*theme.AnimationSpeed*st.dt)) end
        if math.abs(value-target)<.001 then value=target end
        st.animation[id]=value
        return value
    end
    local function scrollToward(value,target)
        if theme.ReducedMotion then return target end
        value=value+(target-value)*(1-math.exp(-25*theme.AnimationSpeed*st.dt))
        return math.abs(value-target)<.03 and target or value
    end
    local drawOpacity,drawScale,drawCX,drawCY,drawDY,scopeOpacity,scopeDY=1,1,0,0,0,1,0
    local rawPaint=false
    local function point(x,y)
        if rawPaint then return x,y end
        return drawCX+(x-drawCX)*drawScale,drawCY+(y-drawCY)*drawScale+drawDY+scopeDY
    end
    local function alpha(a) return clamp((a or 1)*(rawPaint and 1 or drawOpacity*scopeOpacity),0,1) end
    local function dimension(v) return v*(rawPaint and 1 or drawScale) end
    local function col(v) return rgb(clamp(v[1] or 0,0,255),clamp(v[2] or 0,0,255),clamp(v[3] or 0,0,255)) end
    local function mix(a,b,t) return rgb((a.R+(b.R-a.R)*t)*255,(a.G+(b.G-a.G)*t)*255,(a.B+(b.B-a.B)*t)*255) end
    local function hit(x,y,w,h) return st.mx>=x and st.mx<=x+w and st.my>=y and st.my<=y+h end
    local function key(vk)
        local readKey=ctx.key or iskeypressed
        if type(readKey)~="function" then return false end
        local ok,value=pcall(readKey,vk); return ok and value==true
    end
    local function focused()
        if ctx.focused then local ok,v=pcall(ctx.focused); return ok and v==true end
        if type(isrbxactive)=="function" then local ok,v=pcall(isrbxactive); return ok and v==true end
        return true
    end
    local function typing()
        if not ctx.typing then return false end
        local ok,v=pcall(ctx.typing); return not ok or v==true
    end
    local function viewport()
        if ctx.viewport then
            local ok,a,b=pcall(ctx.viewport)
            if ok and type(a)=="number" then return a,b end
            if ok and a then return a.X,a.Y end
        end
        local ok,v=pcall(function() return workspace.CurrentCamera.ViewportSize end)
        if ok and v then return v.X,v.Y end
        return 1920,1080
    end
    -- Stable names reuse native objects; views allocate only their first time shown.
    local function drawing(frame,name,kind)
        local d=objects[name]
        if d and objectKinds[name]~=kind then
            pcall(function() d:Remove() end); objects[name]=nil; d=nil; st.count=st.count-1
        end
        if not d then
            d=drawingBackend.new(kind); assert(d,"Unable to create Thalassar "..kind)
            objects[name]=d; objectKinds[name]=kind; st.count=st.count+1; d.Visible=false
            if kind~="Text" then d.Thickness=1 end
        end
        frame[name]=true; return d
    end
    local function rect(f,id,x,y,w,h,c,a,r,z,outline)
        if w<=0 or h<=0 then return end
        local d=drawing(f,id,"Square")
        x,y=point(x,y)
        d.Position=v2(x,y); d.Size=v2(dimension(w),dimension(h)); d.Color=c; d.Transparency=alpha(a)
        d.Corner=dimension(r or 0); d.Filled=not outline; d.ZIndex=z or 100; d.Visible=true
    end
    local function roundedStroke(f,id,x,y,w,h,c,a,r,thickness,z)
        rect(f,id,x,y,w,h,c,a,r,z,true)
        local d=objects[id]
        if d then d.Thickness=dimension(thickness or 1) end
    end
    local function circle(f,id,x,y,r,c,a,z,outline)
        local d=drawing(f,id,"Circle")
        x,y=point(x,y)
        d.Position=v2(x,y); d.Radius=dimension(r); d.Color=c; d.Transparency=alpha(a)
        d.Filled=not outline; d.NumSides=24; d.ZIndex=z or 100; d.Visible=true
    end
    local function line(f,id,x1,y1,x2,y2,c,a,z)
        local d=drawing(f,id,"Line")
        x1,y1=point(x1,y1); x2,y2=point(x2,y2)
        d.From=v2(x1,y1); d.To=v2(x2,y2); d.Color=c; d.Transparency=alpha(a)
        d.ZIndex=z or 100; d.Visible=true
    end
    local function text(f,id,value,x,y,size,c,a,z,width,bold,alignment)
        value=tostring(value or "")
        if width then local chars=floor(width/(size*.52)); if #value>chars and chars>4 then value=value:sub(1,chars-3).."..." end end
        local d=drawing(f,id,"Text")
        d.Text=value; d.Size=dimension(size); d.Font=bold and (fonts.Bold or 2) or theme.Font
        if alignment=="right" and width then
            local measured=#value*size*.52
            local ok,bounds=pcall(function() return d.TextBounds end)
            if ok and bounds and type(bounds.X)=="number" and bounds.X>0 then measured=bounds.X/(rawPaint and 1 or drawScale) end
            x=x+max(0,width-measured)
        end
        x,y=point(x,y)
        d.Position=v2(x,y); d.Color=c; d.Transparency=alpha((a or 1)*(theme.Text[4]/255))
        d.Center=false; d.Outline=false; d.ZIndex=z or 120; d.Visible=true
    end
    local function finish(frame)
        for id in pairs(lastFrame) do if not frame[id] then objects[id].Visible=false end end
        lastFrame=frame
    end
    local function hide()
        for id in pairs(lastFrame) do objects[id].Visible=false end
        lastFrame={}
    end
    local function fire(row)
        if row.kind=="Color" then safe(row.callback,col(row.value),row.value[4]/255)
        elseif row.kind=="Keybind" and not row.internal then safe(row.callback,row.boundOn==true,row.value)
        else safe(row.callback,row.value) end
    end
    local function colorValues(a,b,c,d)
        local byteArray=false
        if type(a)=="table" or type(a)=="userdata" then
            local ok,red,green,blue=pcall(function() return a.R,a.G,a.B end)
            if ok and type(red)=="number" then a,b,c,d=red,green,blue,b
            else byteArray=true; a,b,c,d=a[1],a[2],a[3],a[4] or b end
        end
        a,b,c,d=finiteNumber(a,255),finiteNumber(b,255),finiteNumber(c,255),finiteNumber(d,255)
        if not byteArray and a<=1 and b<=1 and c<=1 then a,b,c=a*255,b*255,c*255 end
        if not byteArray and d<=1 then d=d*255 end
        return {clamp(a,0,255),clamp(b,0,255),clamp(c,0,255),clamp(d,0,255)}
    end
    local function set(row,notify,...)
        local args={...}; local v=args[1]
        if row.kind=="Color" then row.value=colorValues(unpackValues(args))
        elseif row.kind=="Toggle" then row.value=v==true
        elseif row.kind=="Slider" then
            row.value=clamp(finiteNumber(v,row.min),row.min,row.max)
            if row.step>0 then row.value=clamp(floor(row.value/row.step+.5)*row.step,row.min,row.max) end
        elseif row.kind=="Combo" then row.value=clamp(floor(finiteNumber(v,0)),0,max(0,#row.items-1))
        elseif row.kind=="Keybind" then row.value=clamp(floor(finiteNumber(v,0)),0,255)
        elseif row.kind=="InputText" or row.kind=="Label" then row.value=tostring(v or ""); if row.kind=="Label" then row.label=row.value end
        else row.value=v end
        if notify then fire(row) end
        return row
    end
    local serial=0
    local function add(page,kind,id,label,value,callback,opt)
        assert(not page.removed,"Cannot add controls to a removed tab")
        serial=serial+1; opt=opt or {}; id=tostring(id or "thalassar_control_"..serial)
        assert(not ids[id],"Duplicate control ID: "..id)
        local row={id=id,kind=kind,label=tostring(label or id),value=value,callback=callback,
            hidden=opt.Hidden==true,enabled=opt.Enabled~=false,tip=opt.Tooltip,page=page,internal=page.interface==true}
        function row:SetValue(...) return set(self,self.internal,...) end
        function row:SetText(value) return set(self,false,value) end
        function row:GetValue() if self.kind=="Color" then return unpackValues(self.value) end; if self.kind=="Keybind" then return self:IsEnabled() end; return self.value end
        function row:GetText() return self.kind=="Combo" and (self.items[self.value+1] or "") or tostring(self.value or "") end
        function row:SetTitle(v) self.label=tostring(v); return self end
        function row:SetVisible(v) self.hidden=v~=true; return self end
        function row:SetDisabled(v) self.enabled=not v; return self end
        function row:Tip(v) self.tip=tostring(v); return self end
        function row:Clear() if self.kind=="Combo" then self.items={}; self.value=0 end; return self end
        function row:Add(v) if self.kind=="Combo" then self.items[#self.items+1]=v end; return self end
        function row:AddToHotkey(label,toggleId) self.hotkeyLabel,self.toggleId=label,toggleId; return self end
        function row:IsEnabled()
            if self.kind~="Keybind" then return self.enabled end
            return self.boundOn==true
        end
        ids[id]=row; page.rows[#page.rows+1]=row; return row
    end
    local methods={}
    function methods:Toggle(id,label,value,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,value,cb=o.Id,o.Title,o.Default,o.Callback end
        if type(value)=="function" then cb,value=value,false end
        return add(self,"Toggle",id,label,value==true,cb,o)
    end
    function methods:Slider(id,label,minimum,maximum,value,cb,step)
        local o=type(id)=="table" and id or nil
        if o then id,label,minimum,maximum,value,cb,step=o.Id,o.Title,o.Min,o.Max,o.Default,o.Callback,o.Step end
        local row=add(self,"Slider",id,label,finiteNumber(value,0),cb,o)
        row.min,row.max,row.step=finiteNumber(minimum,0),finiteNumber(maximum,100),math.max(0,finiteNumber(step,1))
        assert(row.max>=row.min,"Invalid slider range: "..row.id); set(row,false,row.value); return row
    end
    function methods:SliderInt(id,label,minimum,maximum,value,cb) return self:Slider(id,label,minimum,maximum,value,cb,1) end
    function methods:SliderFloat(id,label,minimum,maximum,value,format,cb)
        if type(format)=="function" then cb,format=format,nil end
        local row=self:Slider(id,label,minimum,maximum,value,cb,.01); row.format=format or "%.2f"; return row
    end
    function methods:Combo(id,label,items,value,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,items,value,cb=o.Id,o.Title,o.Options or o.Items,o.Default,o.Callback end
        if type(items)=="number" and type(value)=="table" then items,value=value,items end
        local row=add(self,"Combo",id,label,tonumber(value) or 0,cb,o)
        row.items=type(items)=="table" and items or {}; set(row,false,row.value); return row
    end
    methods.Dropdown=methods.Combo
    function methods:ColorPicker(id,r,g,b,a,cb,label)
        local o=type(id)=="table" and id or nil
        if o then id,label,cb=o.Id,o.Title,o.Callback; r,g,b,a=unpackValues(colorValues(o.Default or o.Color or {255,255,255},o.Alpha or 255)) end
        if not label then local prev=self.rows[#self.rows]; label=prev and prev.label.." color" or "Color" end
        return add(self,"Color",id,label,colorValues(r,g,b,a),cb,o)
    end
    function methods:Button(id,label,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,cb=o.Id,o.Title,o.Callback
        elseif type(label)=="function" then cb,label,id=label,id,nil end
        return add(self,"Button",id,label,nil,cb,o)
    end
    function methods:Keybind(id,label,vk,cb,mode)
        local o=type(id)=="table" and id or nil
        if o then id,label,vk,cb,mode=o.Id,o.Title,o.Default,o.Callback,o.Mode
        elseif type(label)=="number" then vk,mode,label=label,vk,"Shortcut" end
        local row=add(self,"Keybind",id,label or "Shortcut",tonumber(vk) or 0,cb,o); row.mode=mode or "toggle"; return row
    end
    function methods:InputText(id,label,value,cb)
        local o=type(id)=="table" and id or nil
        if o then id,label,value,cb=o.Id,o.Title,o.Default,o.Callback end
        return add(self,"InputText",id,label,tostring(value or ""),cb,o)
    end
    function methods:Label(id,label)
        local o=type(id)=="table" and id or nil
        if o then id,label=o.Id,o.Title elseif not label then label,id=id,nil end
        return add(self,"Label",id,label,tostring(label or ""),nil,o)
    end
    function methods:Tip(value) local row=self.rows[#self.rows]; if row then row.tip=tostring(value) end; return row end
    function methods:Heading(value) return add(self,"Heading",nil,value,nil,nil) end
    local groupOrder,groupKnown={"Settings"},{Settings=true}
    local function rememberGroup(group)
        group=tostring(group)
        if not groupKnown[group] then groupKnown[group]=true; groupOrder[#groupOrder+1]=group end
        return group
    end
    function ui.AddTab(name,builder)
        local tab={name=tostring(name),sections={}}
        function tab:Section(title,opt)
            opt=type(opt)=="table" and opt or {}
            local page=setmetatable({title=tostring(title),group=rememberGroup(opt.Group or self.name),rows={},scroll=0,targetScroll=0,tab=self,interface=opt.Interface==true},{__index=methods})
            pages[#pages+1]=page; self.sections[#self.sections+1]=page
            if not st.active or st.active.interface and not page.interface then st.active=page; st.group=page.group end
            return page
        end
        tabs[#tabs+1]=tab; if type(builder)=="function" then builder(tab) end; return tab
    end
    function ui.RemoveTab(name)
        for i=#pages,1,-1 do if pages[i].tab.name==name then
            local page=pages[i]; page.removed=true
            if st.popup and st.popup.row.page==page then st.popup=nil end
            if st.edit and st.edit.row.page==page then st.edit=nil end
            if st.capture and st.capture.page==page then st.capture=nil end
            if st.drag and (st.drag.row and st.drag.row.page==page or st.active==page and st.drag.kind=="scroll") then st.drag=nil end
            for _,row in ipairs(page.rows) do
                ids[row.id]=nil
                local prefix=row.id..":"
                for id,d in pairs(objects) do if id:sub(1,#prefix)==prefix then
                    pcall(function() d:Remove() end); objects[id]=nil; objectKinds[id]=nil; lastFrame[id]=nil; st.count=st.count-1
                end end
                for id in pairs(st.animation) do if id:sub(1,#prefix)==prefix then st.animation[id]=nil end end
            end
            if st.active==page then st.active=nil end
            table.remove(pages,i)
        end end
        for i=#tabs,1,-1 do if tabs[i].name==name then table.remove(tabs,i) end end
        if not st.active then st.active=pages[1]; if st.active then st.group=st.active.group end end
    end
    function ui.GetValue(id) local row=ids[id]; if row then return row:GetValue() end end
    function ui.SetValue(id,...) local row=ids[id]; if row then return set(row,row.internal,...) end end
    function ui.visible() return st.open and st.alive end
    function ui.setVisible(value)
        value=value==true; if st.open==value then return end
        st.open=value; st.popup=nil; st.drag=nil; st.edit=nil; st.capture=nil
        if theme.ReducedMotion then st.visibility=value and 1 or 0; st.transition=nil; if not value then hide() end
        else st.transition={from=st.visibility,to=value and 1 or 0,time=0,duration=.22/theme.AnimationSpeed} end
        safe(ctx.onVisibility,value)
    end
    local function insideRegion(region,x,y)
        return region and x>=region.x and x<=region.x+region.w and y>=region.y and y<=region.y+region.h
    end
    function ui.scrollRegions()
        local out={}
        for name,region in pairs(st.regions) do
            out[name]={x=region.x,y=region.y,w=region.w,h=region.h,max=region.max or 0,
                current=region.current or 0,target=region.target or 0,scale=region.scale or 1}
        end
        return out
    end
    function ui.scroll(delta,x,y)
        delta=tonumber(delta)
        if not delta or delta~=delta or delta==0 or not st.alive or not st.open or st.visibility<.99 or not focused() or typing() then return false end
        delta=clamp(delta,-24,24)
        x=tonumber(x) or tonumber(mouse and mouse.X) or st.mx
        y=tonumber(y) or tonumber(mouse and mouse.Y) or st.my
        local region
        if st.popup then
            region=st.regions.dropdown
            if st.popup.kind=="Combo" and not st.popup.closing and insideRegion(region,x,y) then
                st.popup.scrollTarget=clamp((st.popup.scrollTarget or 0)-delta,0,max(0,#st.popup.row.items-8))
                region.target=st.popup.scrollTarget
                return true,"dropdown"
            end
            return false
        end
        region=st.regions.sidebar
        if insideRegion(region,x,y) then
            st.navTarget=clamp(st.navTarget-delta*34*region.scale,0,st.navMax)
            region.target=st.navTarget
            return true,"sidebar"
        end
        region=st.regions.page
        if region and region.page==st.active and insideRegion(region,x,y) then
            st.active.targetScroll=clamp(st.active.targetScroll-delta*34*region.scale,0,region.max)
            region.target=st.active.targetScroll
            return true,"page"
        end
        return false
    end
    function ui.isInteracting() return st.alive and st.open and focused() and not typing() end
    function ui.selectSection(name)
        for _,p in ipairs(pages) do if p.title==name then
            if st.active~=p then st.pageFade=theme.ReducedMotion and 1 or 0 end
            st.active=p; st.group=p.group; st.popup=nil; st.regions={}; return true
        end end
        return false
    end
    function ui.exportValues()
        local out={}
        for id,row in pairs(ids) do if row.kind~="Button" and row.kind~="Heading" and row.kind~="Label" then out[id]=type(row.value)=="table" and {unpackValues(row.value)} or row.value end end
        return out
    end
    function ui.importValues(values,notify)
        if type(values)~="table" then return false end
        for id,value in pairs(values) do local row=ids[id]; if row then set(row,row.internal or notify==true,value); if not st.alive then return false end end end
        return st.alive
    end
    local settingRows={}
    function ui.exportAppearance()
        local out={}; for name,value in pairs(theme) do out[name]=type(value)=="table" and {unpackValues(value)} or value end
        out.Window={st.x,st.y,st.w,st.h}; return out
    end
    function ui.importAppearance(saved)
        if type(saved)~="table" then return false end
        for name,row in pairs(settingRows) do if saved[name]~=nil then set(row,true,saved[name]); if not st.alive then return false end end end
        if type(saved.Window)=="table" then local w=saved.Window; st.x=finiteNumber(w[1],st.x); st.y=finiteNumber(w[2],st.y); st.w=clamp(finiteNumber(w[3],st.w),700,1400); st.h=clamp(finiteNumber(w[4],st.h),480,1000); st.initialized=true end
        return st.alive
    end
    function ui.resetAppearance() return ui.importAppearance(defaultTheme) end
    function ui.status() return {name=title,alive=st.alive,visible=st.open,minimized=st.alive and not st.open,section=st.active and st.active.title,drawings=st.count,error=st.error,backdropBlur=false,width=st.w,height=st.h,opacity=st.visibility,animating=st.transition~=nil,font=theme.Font} end
    function ui.destroy()
        if not st.alive then return end
        st.alive=false; st.open=false; st.drag=nil; st.popup=nil; st.capture=nil; st.edit=nil
        safe(ctx.onVisibility,false); for _,d in pairs(objects) do pcall(function() d:Remove() end) end
        objects={}; objectKinds={}; lastFrame={}; st.count=0
    end
    local function keyName(code)
        if code>=65 and code<=90 or code>=48 and code<=57 then return string.char(code) end
        if code>=112 and code<=135 then return "F"..tostring(code-111) end
        local names={[0]="None",[27]="Esc",[32]="Space",[9]="Tab",[13]="Enter",[16]="Shift",[17]="Ctrl",[18]="Alt",[45]="Insert",[46]="Delete",[36]="Home",[35]="End",[33]="Page Up",[34]="Page Down"}
        return names[code] or string.format("0x%02X",code)
    end
    local function rowHeight(row,s)
        if row.hidden then return 0 end
        return (row.kind=="Slider" and 56 or row.kind=="Heading" and 31 or row.kind=="Label" and 36 or 43)*s
    end
    local function sliderSet(row,x,w) set(row,true,row.min+(row.max-row.min)*clamp((st.mx-x)/max(w,1),0,1)) end
    local function number(row)
        if row.format then local ok,v=pcall(string.format,row.format,row.value); if ok then return v end end
        return row.step>=1 and tostring(floor(row.value+.5)) or string.format("%.2f",row.value)
    end
    local function primeEditKeys() for vk=8,222 do st.prevKeys[vk]=key(vk) end end
    local function drawRow(f,row,x,y,w,s,c,click,input,bottom)
        local id,h,font=row.id,rowHeight(row,s),theme.FontSize*s
        local hover=input and hit(x,y,w,h); local opacity=row.enabled and 1 or .4
        local highlight=animate(id..":hoverAnimation",hover and not st.popup and 1 or 0,23,0)
        row.bounds={x=x,y=y,w=w,h=h}
        if row.kind=="Heading" or row.kind=="Label" then
            text(f,id..":label",row.label,x+12*s,y+9*s,font-s,c.text,.58,120,w-24*s,row.kind=="Heading"); return
        end
        if highlight>.001 then rect(f,id..":hover",x+3*s,y+s,w-6*s,h-2*s,c.white,.075*highlight,8*s,116) end
        local labelW=w-120*s
        if row.kind=="Combo" or row.kind=="InputText" then labelW=w-260*s end
        if row.kind~="Button" then text(f,id..":name",row.label,x+12*s,y+12*s,font,c.text,.93*opacity,120,labelW) end
        local right=x+w-14*s
        if row.kind=="Toggle" then
            local tx,ty=right-35*s,y+12*s
            local on=animate(id..":toggleAnimation",row.value and 1 or 0,24,row.value and 1 or 0)
            rect(f,id..":track",tx,ty,35*s,18*s,mix(c.white,c.accent,on),(.12+.68*on)*opacity,9*s,120)
            circle(f,id..":knobShadow",tx+(9+17*on)*s,ty+10*s,6.5*s,c.black,.15*opacity,121)
            circle(f,id..":knob",tx+(9+17*on)*s,ty+9*s,6*s,mix(c.muted,c.text,on),opacity,122)
            circle(f,id..":knobHighlight",tx+(9+17*on)*s,ty+8*s,5*s,c.white,(.12+.13*highlight)*opacity,123)
            if click and hover and row.enabled and not st.popup then set(row,true,not row.value) end
        elseif row.kind=="Slider" then
            text(f,id..":number",number(row),right-100*s,y+12*s,font,c.text,.72*opacity,120,100*s,false,"right")
            local sx,sy,sw=x+14*s,y+40*s,w-28*s
            local targetRatio=row.max==row.min and 0 or (row.value-row.min)/(row.max-row.min)
            local ratio=animate(id..":sliderAnimation",targetRatio,34,targetRatio)
            rect(f,id..":range",sx,sy,sw,3*s,c.white,.10*opacity,2*s,120)
            rect(f,id..":fill",sx,sy,max(1,sw*ratio),3*s,c.accent,.85*opacity,2*s,122)
            circle(f,id..":handleShadow",sx+sw*ratio,sy+2.5*s,6*s,c.black,.20*opacity,123)
            circle(f,id..":handle",sx+sw*ratio,sy+1.5*s,(5+highlight)*s,c.text,opacity,124)
            if click and row.enabled and hit(sx-5*s,sy-10*s,sw+10*s,20*s) and not st.popup then st.drag={kind="slider",row=row,x=sx,w=sw}; sliderSet(row,sx,sw) end
        elseif row.kind=="Combo" or row.kind=="InputText" then
            local bx,by,bw,bh=right-235*s,y+7*s,235*s,29*s
            rect(f,id..":box",bx,by,bw,bh,c.white,(.045+.055*highlight)*opacity,7*s,120)
            rect(f,id..":border",bx,by,bw,bh,c.white,(.10+.12*highlight)*opacity,7*s,121,true)
            local value=row:GetText()
            if st.edit and st.edit.row==row then value=st.edit.buffer..(floor(st.time*2)%2==0 and "|" or "") end
            text(f,id..":value",value,bx+10*s,by+7*s,font,c.text,.82*opacity,124,bw-35*s)
            if row.kind=="Combo" then
                line(f,id..":chevronA",right-18*s,by+12*s,right-14*s,by+16*s,c.text,.5,125)
                line(f,id..":chevronB",right-14*s,by+16*s,right-10*s,by+12*s,c.text,.5,125)
            end
            if click and row.enabled and hit(bx,by,bw,bh) and not st.popup then
                if row.kind=="Combo" then
                    local ph=(min(#row.items,8)*32+12+(#row.items>8 and 28 or 0))*s; local py=by+bh+4*s
                    if py+ph>bottom then py=max(st.y+65*s,by-ph-4*s) end
                    st.popup={kind="Combo",row=row,x=bx,y=py,w=bw,scroll=0,scrollTarget=0,justOpened=true,fade=0}
                else st.edit={row=row,buffer=row.value}; primeEditKeys() end
            end
        elseif row.kind=="Color" then
            local bx,by=right-44*s,y+9*s
            rect(f,id..":swatch",bx,by,44*s,25*s,col(row.value),opacity,6*s,120)
            rect(f,id..":swatchBorder",bx,by,44*s,25*s,c.white,(.25+.35*highlight)*opacity,6*s,122,true)
            if click and row.enabled and hit(bx-5*s,by-4*s,54*s,33*s) and not st.popup then
                local pw,ph,py=285*s,206*s,by+34*s
                if py+ph>bottom then py=max(st.y+65*s,by-ph-5*s) end
                st.popup={kind="Color",row=row,x=right-pw,y=py,w=pw,justOpened=true,fade=0}
            end
        elseif row.kind=="Button" then
            rect(f,id..":button",x+12*s,y+5*s,w-24*s,32*s,c.white,.045+.065*highlight,8*s,120)
            rect(f,id..":buttonBorder",x+12*s,y+5*s,w-24*s,32*s,c.white,.11+.12*highlight,8*s,121,true)
            text(f,id..":buttonText",row.label,x+24*s,y+13*s,font,c.text,.85*opacity,124,w-54*s)
            if click and hover and row.enabled and not st.popup then safe(row.callback) end
        elseif row.kind=="Keybind" then
            local bx,by,bw=right-112*s,y+7*s,112*s
            rect(f,id..":bind",bx,by,bw,29*s,c.white,.045+.075*highlight,7*s,120)
            rect(f,id..":bindBorder",bx,by,bw,29*s,c.white,.09+.09*highlight,7*s,121,true)
            text(f,id..":key",st.capture==row and "Press a key..." or keyName(row.value),bx+10*s,by+7*s,font-s,c.text,.7,123,bw-15*s)
            if click and row.enabled and hit(bx,by,bw,29*s) and not st.popup then st.capture=row; primeEditKeys() end
        end
        if row.tip and hover and not st.popup and not st.drag then st.tip=row.tip end
    end
    local function drawPopup(f,c,s,click,input)
        local p=st.popup; if not p then return end
        local target=p.closing and 0 or 1
        p.fade=theme.ReducedMotion and target or p.fade+(target-p.fade)*(1-math.exp(-24*theme.AnimationSpeed*st.dt))
        if p.closing and p.fade<.005 then st.popup=nil; return end
        local x,y,w=p.x,p.y,p.w
        local h=p.kind=="Combo" and (min(#p.row.items,8)*32+12+(#p.row.items>8 and 28 or 0))*s or 206*s
        if p.kind=="Combo" and #p.row.items==0 then h=44*s end
        if click and input and not p.justOpened and not hit(x,y,w,h) then p.closing=true end
        local popupClick=click and not p.justOpened and not p.closing
        p.justOpened=false
        local oldScope,oldDY=scopeOpacity,scopeDY
        scopeOpacity=oldScope*p.fade; scopeDY=oldDY+(1-p.fade)*4*s
        local popupX,popupY=point(x,y)
        st.regions.dropdown={x=popupX,y=popupY,w=dimension(w),h=dimension(h),max=max(0,#(p.row.items or {})-8),current=p.scroll or 0,target=p.scrollTarget or 0,scale=s*drawScale}
        rect(f,"popup:shadow",x-3*s,y+3*s,w+6*s,h+6*s,c.black,.3,10*s,300)
        rect(f,"popup:body",x,y,w,h,mix(c.tint,c.black,.1),.98,9*s,301)
        rect(f,"popup:edge",x,y,w,h,c.white,.12,9*s,302,true)
        if p.kind=="Combo" then
            p.scrollTarget=clamp(p.scrollTarget or 0,0,max(0,#p.row.items-8))
            p.scroll=scrollToward(p.scroll or 0,p.scrollTarget)
            st.regions.dropdown.current=p.scroll; st.regions.dropdown.target=p.scrollTarget
            local first=floor(p.scroll); local fraction=p.scroll-first
            for i=1,min(9,#p.row.items-first) do
                local index=i+first; local oy=y+6*s+((i-1)-fraction)*32*s
                if oy>=y+6*s-.01 and oy+31*s<=y+6*s+min(8,#p.row.items)*32*s then
                local over=input and not p.closing and hit(x+5*s,oy,w-10*s,32*s)
                local hover=animate("popup:optionHover:"..i,over and 1 or 0,23,0)
                local selected=p.row.value==index-1 and 1 or 0
                if hover>.001 or selected==1 then rect(f,"popup:option:"..i,x+5*s,oy,w-10*s,31*s,c.accent,.11*selected+.13*hover,6*s,303) end
                text(f,"popup:text:"..i,p.row.items[index],x+12*s,oy+9*s,theme.FontSize*s,c.text,.9,306,w-24*s)
                if popupClick and over then set(p.row,true,index-1); if not st.alive then return end; p.closing=true end
                end
            end
            if #p.row.items>8 then
                local fy=y+h-27*s
                text(f,"popup:range",tostring(first+1).."-"..tostring(min(#p.row.items,first+8)).." / "..tostring(#p.row.items),x+12*s,fy+7*s,10*s,c.text,.40,306,w-100*s)
                text(f,"popup:previous","Up",x+w-76*s,fy+6*s,11*s,c.text,.65,306,27*s)
                text(f,"popup:next","Down",x+w-45*s,fy+6*s,11*s,c.text,.65,306,36*s)
                if popupClick and hit(x+w-80*s,fy,33*s,24*s) then p.scrollTarget=max(0,p.scrollTarget-8) end
                if popupClick and hit(x+w-47*s,fy,42*s,24*s) then p.scrollTarget=min(max(0,#p.row.items-8),p.scrollTarget+8) end
                local up,down=key(33),key(34)
                if input and up and not p.prevUp then p.scrollTarget=max(0,p.scrollTarget-8) end
                if input and down and not p.prevDown then p.scrollTarget=min(max(0,#p.row.items-8),p.scrollTarget+8) end
                p.prevUp,p.prevDown=up,down
            end
        else
            local row=p.row
            text(f,"popup:title",row.label,x+14*s,y+13*s,theme.FontSize*s,c.text,.9,306,w-72*s,true)
            rect(f,"popup:preview",x+w-52*s,y+10*s,37*s,24*s,col(row.value),1,5*s,306)
            for i,label in ipairs({"Red","Green","Blue","Opacity"}) do
                local oy=y+(49+(i-1)*36)*s; local sx,sy,sw=x+82*s,oy+5*s,w-144*s
                text(f,"popup:channel:"..i,label,x+14*s,oy-3*s,theme.FontSize*s-2*s,c.text,.58,306,56*s)
                text(f,"popup:number:"..i,tostring(floor(row.value[i]+.5)),x+w-43*s,oy-3*s,theme.FontSize*s-2*s,c.text,.7,306,40*s)
                rect(f,"popup:track:"..i,sx,sy,sw,3*s,c.white,.12,2*s,306)
                rect(f,"popup:fill:"..i,sx,sy,max(1,sw*row.value[i]/255),3*s,c.accent,.8,2*s,307)
                circle(f,"popup:handle:"..i,sx+sw*row.value[i]/255,sy+1.5*s,4*s,c.text,1,308)
                if popupClick and input and hit(sx-4*s,oy-8*s,sw+8*s,25*s) then
                    st.drag={kind="color",row=row,index=i,x=sx,w=sw}
                    local values={unpackValues(row.value)}
                    values[i]=floor(clamp((st.mx-sx)/sw,0,1)*255+.5)
                    set(row,true,values)
                    if not st.alive then return end
                end
            end
            text(f,"popup:foot","Click outside to close",x+14*s,y+h-19*s,10*s,c.text,.36,306,w-28*s)
        end
        scopeOpacity,scopeDY=oldScope,oldDY
    end
    local function consumeWheel()
        if type(ctx.consumeWheel)~="function" then return end
        local ok,delta,x,y=pcall(ctx.consumeWheel)
        if ok then ui.scroll(delta,x,y) else st.error=tostring(delta); safe(ctx.onError,st.error) end
    end
    local function updateKeys(input)
        local menu=key(theme.MenuKey); local edge=menu and not st.prevMenu; st.prevMenu=menu
        if input and edge and not st.capture and not st.edit then ui.setVisible(not st.open) end
        if input and (st.capture or st.edit) then
            local shift=key(16) or key(160) or key(161)
            for vk=8,222 do
                local held=key(vk); local pressed=held and not st.prevKeys[vk]; st.prevKeys[vk]=held
                if pressed then
                    if st.capture then local row=st.capture; st.capture=nil; if vk~=27 then set(row,true,vk); if not st.alive then return end end; break
                    elseif st.edit then
                        local edit=st.edit
                        if vk==27 then st.edit=nil; break
                        elseif vk==13 then set(edit.row,true,edit.buffer); st.edit=nil; if not st.alive then return end; break
                        elseif vk==8 then edit.buffer=edit.buffer:sub(1,max(0,#edit.buffer-1))
                        elseif #edit.buffer<120 then
                            local char
                            if vk>=65 and vk<=90 then char=string.char(shift and vk or vk+32)
                            elseif vk>=48 and vk<=57 then char=shift and (")!@#$%^&*("):sub(vk-47,vk-47) or string.char(vk)
                            elseif vk==32 then char=" "
                            else local chars={[186]={";",":"},[187]={"=","+"},[188]={",","<"},[189]={"-","_"},[190]={".",">"},[191]={"/","?"},[192]={"`","~"},[219]={"[","{"},[220]={"\\","|"},[221]={"]","}"},[222]={"'",'"'}}; if chars[vk] then char=chars[vk][shift and 2 or 1] end end
                            if char then edit.buffer=edit.buffer..char end
                        end
                    end
                end
            end
        end
        for _,row in pairs(ids) do if row.kind=="Keybind" and row.value~=0 then
            local held=key(row.value); local pressed=held and not row.prevHeld; row.prevHeld=held
            local previous=row.boundOn==true
            if row.enabled and input and not st.open then
                if row.mode=="hold" then row.boundOn=held elseif pressed then row.boundOn=not previous end
            elseif row.mode=="hold" or not row.enabled then row.boundOn=false end
            if not row.internal and previous~=(row.boundOn==true) then fire(row); if not st.alive then return end end
        end end
    end
    function ui.step(dt)
        if not st.alive then return end
        dt=clamp(finiteNumber(dt,.016),0,.1); st.time=st.time+dt; st.dt=dt
        local vw,vh=viewport()
        if not st.initialized then st.initialized=true; st.x=max(12,(vw-st.w)/2); st.y=max(12,(vh-st.h)/2) end
        st.mx=tonumber(mouse and mouse.X) or st.mx; st.my=tonumber(mouse and mouse.Y) or st.my
        local readMouse=ctx.mouseDown or ismouse1pressed
        local mouseOK,mouseValue=false,false
        if type(readMouse)=="function" then mouseOK,mouseValue=pcall(readMouse) end
        local down=mouseOK and mouseValue==true
        local input=focused() and not typing(); local click=down and not st.prevMouse and input
        if not st.alive then return end
        st.prevMouse=down; updateKeys(input)
        if not st.alive then return end
        consumeWheel()
        if not st.alive then return end
        if st.transition then
            local transition=st.transition
            transition.time=min(transition.duration,transition.time+dt)
            local t=transition.time/transition.duration
            local eased=t*t*(3-2*t)
            st.visibility=transition.from+(transition.to-transition.from)*eased
            if t>=1 or theme.ReducedMotion then st.visibility=transition.to; st.transition=nil end
        end
        if not st.open and st.visibility<=.001 then hide(); st.drag=nil; return end
        input=input and st.open and st.visibility>.99
        click=click and input
        if not input then st.drag=nil; st.capture=nil; st.edit=nil end
        local targetScale=clamp(theme.Scale,.75,1.5)
        local s=animate("glass:scaleAnimation",targetScale,27,targetScale)
        local maxW,maxH=max(470,(vw-24)/s),max(350,(vh-24)/s)
        st.w=clamp(st.w,min(700,maxW),maxW); st.h=clamp(st.h,min(480,maxH),maxH)
        local w,h=st.w*s,st.h*s
        st.x=clamp(st.x,12,max(12,vw-w-12)); st.y=clamp(st.y,12,max(12,vh-h-12))
        if st.drag and input then
            local d=st.drag
            if not down then st.drag=nil
            elseif d.kind=="window" then st.x=st.mx-d.dx; st.y=st.my-d.dy
            elseif d.kind=="resize" then st.w=(st.mx-st.x+d.dx)/s; st.h=(st.my-st.y+d.dy)/s
            elseif d.kind=="slider" then sliderSet(d.row,d.x,d.w)
            elseif d.kind=="color" then local v={unpackValues(d.row.value)}; v[d.index]=floor(clamp((st.mx-d.x)/d.w,0,1)*255+.5); set(d.row,true,v)
            elseif d.kind=="scroll" then
                st.active.targetScroll=clamp((st.my-d.y)/d.h,0,1)*d.maximum; st.active.scroll=st.active.targetScroll
            elseif d.kind=="navscroll" then
                st.navTarget=clamp((st.my-d.y)/d.h,0,1)*d.maximum; st.navScroll=st.navTarget
            end
        end
        if not st.alive then return end
        local x,y,r=st.x,st.y,animate("glass:roundingAnimation",theme.Rounding,24,theme.Rounding)*s
        w,h=st.w*s,st.h*s
        drawOpacity=st.visibility; drawScale=theme.ReducedMotion and 1 or .965+.035*st.visibility
        drawCX,drawCY,drawDY=x+w/2,y+h/2,theme.ReducedMotion and 0 or (1-st.visibility)*12*s
        scopeOpacity,scopeDY,rawPaint=1,0,false
        st.regions={}
        local windowX,windowY=point(x,y)
        st.regions.window={x=windowX,y=windowY,w=dimension(w),h=dimension(h),scale=s*drawScale}
        if theme.ReducedMotion then st.pageFade=1 else st.pageFade=st.pageFade+(1-st.pageFade)*(1-math.exp(-22*theme.AnimationSpeed*dt)) end
        local f={}; local c={tint=col(theme.Tint),accent=col(theme.Accent),text=col(theme.Text),white=rgb(255,255,255),black=rgb(0,0,0),muted=rgb(161,167,170)}
        st.tip=nil
        if theme.Glow then roundedStroke(f,"glass:glow",x-s,y-s,w+2*s,h+2*s,c.accent,theme.GlowStrength*.035,r+s,5*s,94) end
        roundedStroke(f,"glass:shadow",x-1.5*s,y-1.5*s,w+3*s,h+3*s,c.black,.12,r+1.5*s,4*s,95)
        rect(f,"glass:body",x,y,w,h,c.tint,animate("glass:opacityAnimation",theme.Opacity,24,theme.Opacity),r,100)
        roundedStroke(f,"glass:edge",x,y,w,h,c.white,.17+theme.Bevel*.16+theme.Specular*.12,r,s,104)
        rect(f,"glass:sheen",x+5*s,y+4*s,w-10*s,50*s,c.white,.014+theme.Specular*.055,max(0,r-4*s),103)
        line(f,"glass:reflection",x+r,y+s,x+w-r,y+s,c.white,.14+theme.Specular*.45,105)
        if theme.Grain then for i=1,38 do
            local gx=x+14*s+((i*127+i*i*19)%997/997)*(w-28*s); local gy=y+14*s+((i*173+i*i*7)%991/991)*(h-28*s)
            circle(f,"glass:grain:"..i,gx,gy,.55*s,c.white,theme.GrainStrength*.22,106)
        end end
        if theme.Particles then for i=1,floor(theme.ParticleAmount) do
            local t=theme.ReducedMotion and 0 or st.time*theme.ParticleSpeed
            local px=x+18*s+((i*193%997/997+t*(.015+i%4*.002))%1)*(w-36*s)
            local py=y+20*s+(i*139%991/991)*(h-40*s)+(theme.ReducedMotion and 0 or math.sin(t+i*1.1)*6*s)
            circle(f,"glass:particle:"..i,px,py,(1.2+i%2*.4)*s,c.white,.06+theme.GrainStrength*.15,107)
        end end
        if theme.Vignette then
            roundedStroke(f,"glass:vignette",x+5*s,y+5*s,w-10*s,h-10*s,c.black,theme.VignetteStrength*.30,max(0,r-5*s),3*s,107)
        end
        if ctx.drawBackgroundEffects then
            local fxX,fxY=point(x,y)
            local api={x=fxX,y=fxY,w=dimension(w),h=dimension(h),radius=dimension(r),scale=s*drawScale,
                dt=dt,time=st.time,opacity=st.visibility,reducedMotion=theme.ReducedMotion,colors=c}
            api.rect=function(id,px,py,pw,ph,color,opacity,radius,z,outline)
                rawPaint=true; rect(f,id,px,py,pw,ph,color,opacity,radius,z or 107,outline); rawPaint=false
            end
            api.circle=function(id,px,py,radius,color,opacity,z,outline)
                rawPaint=true; circle(f,id,px,py,radius,color,opacity,z or 107,outline); rawPaint=false
            end
            api.line=function(id,px,py,qx,qy,color,opacity,z)
                rawPaint=true; line(f,id,px,py,qx,qy,color,opacity,z or 107); rawPaint=false
            end
            safe(ctx.drawBackgroundEffects,api); rawPaint=false
            if not st.alive then return end
        end
        local side=196*s
        text(f,"header:name",title,x+24*s,y+20*s,(theme.FontSize+6)*s,c.text,.98,120,w-200*s,true)
        local cx,cy=x+w-30*s,y+30*s
        local mx,my=x+w-66*s,y+30*s
        local closeHover=input and hit(cx-15*s,cy-15*s,30*s,30*s)
        local minHover=input and hit(mx-15*s,my-15*s,30*s,30*s)
        local ca=animate("header:closeHover",closeHover and 1 or 0,24,0)
        local ma=animate("header:minHover",minHover and 1 or 0,24,0)
        if ca>.001 then rect(f,"header:closeHover",cx-15*s,cy-15*s,30*s,30*s,c.white,.11*ca,9*s,118) end
        if ma>.001 then rect(f,"header:minHover",mx-15*s,my-15*s,30*s,30*s,c.white,.10*ma,9*s,118) end
        line(f,"header:closeA",cx-7*s,cy-7*s,cx+7*s,cy+7*s,c.text,.82+.18*ca,122)
        line(f,"header:closeB",cx-7*s,cy+7*s,cx+7*s,cy-7*s,c.text,.82+.18*ca,122)
        line(f,"header:minimize",mx-7*s,my+2*s,mx+7*s,my+2*s,c.text,.78+.22*ma,122)
        if closeHover then st.tip="Close interface" elseif minHover then st.tip="Minimize interface" end
        if click and not st.popup and closeHover then
            safe(ctx.onClose)
            if st.alive then ui.destroy() end
            return
        end
        if click and not st.popup and minHover then ui.setVisible(false); if not st.alive then return end; click=false end
        if click and not st.popup and hit(x+8*s,y+8*s,w-100*s,45*s) then st.drag={kind="window",dx=st.mx-x,dy=st.my-y} end
        line(f,"header:divider",x+17*s,y+59*s,x+w-17*s,y+59*s,c.white,.07,115)
        line(f,"sidebar:divider",x+side,y+79*s,x+side,y+h-47*s,c.white,.07,115)
        local navTop,navH=y+78*s,h-127*s
        local navBottom=navTop+navH
        local navGroups,navTotal={},0
        for _,group in ipairs(groupOrder) do
            local children={}; for _,page in ipairs(pages) do if page.group==group then children[#children+1]=page end end
            if #children>0 then
                local expansion=animate("nav:groupExpansion:"..group,st.group==group and 1 or 0,23,st.group==group and 1 or 0)
                navGroups[#navGroups+1]={name=group,children=children,expansion=expansion}
                navTotal=navTotal+31*s+#children*33*s*expansion
            end
        end
        st.navMax=max(0,navTotal-navH)
        st.navTarget=clamp(st.navTarget,0,st.navMax)
        st.navScroll=scrollToward(clamp(st.navScroll,0,st.navMax),st.navTarget)
        local navX,navYPhysical=point(x+14*s,navTop)
        st.regions.sidebar={x=navX,y=navYPhysical,w=dimension(side-28*s),h=dimension(navH),max=st.navMax,current=st.navScroll,target=st.navTarget,scale=s*drawScale}
        local navY=navTop-st.navScroll; local index=0
        for _,groupInfo in ipairs(navGroups) do
            local group,children,expansion=groupInfo.name,groupInfo.children,groupInfo.expansion
            if #children>0 then
                index=index+1; local gy=navY; navY=navY+31*s
                if gy>=navTop-.01 and gy+29*s<=navBottom then
                local groupHover=input and hit(x+14*s,gy,side-28*s,29*s)
                local ga=animate("nav:groupHover:"..group,groupHover and 1 or 0,22,0)
                if ga>.001 then rect(f,"nav:groupHover:"..index,x+14*s,gy,side-28*s,29*s,c.white,.065*ga,7*s,116) end
                text(f,"nav:group:"..index,group,x+24*s,gy+7*s,theme.FontSize*s,c.text,st.group==group and .88 or .61,120,side-60*s,true)
                local ax,ay=x+side-27*s,gy+15*s
                line(f,"nav:groupDash:"..index,ax-4*s,ay,ax+4*s,ay,c.text,.62,120)
                if st.group~=group then line(f,"nav:groupPlus:"..index,ax,ay-4*s,ax,ay+4*s,c.text,.62,120) end
                if click and not st.popup and hit(x+14*s,gy,side-28*s,29*s) then st.group=st.group==group and "" or group end
                end
                if expansion>.001 then for _,page in ipairs(children) do
                    local py=navY; navY=navY+33*s*expansion; index=index+1
                    if expansion>.70 and py>=navTop-.01 and py+30*s<navBottom then
                        scopeOpacity=expansion; scopeDY=(1-expansion)*3*s
                        local over=input and st.group==group and expansion>.92 and hit(x+14*s,py,side-28*s,30*s); local selected=st.active==page
                        local hover=animate("nav:pageHover:"..page.title,over and 1 or 0,23,0)
                        local selection=animate("nav:pageSelected:"..page.title,selected and 1 or 0,23,selected and 1 or 0)
                        if selection>.001 or hover>.001 then rect(f,"nav:selected:"..index,x+14*s,py,side-28*s,30*s,mix(c.white,c.accent,selection),.16*selection+.065*hover,8*s,116) end
                        if selected then rect(f,"nav:marker:"..index,x+15*s,py+8*s,2*s,14*s,c.accent,.85,1*s,119) end
                        circle(f,"nav:icon:"..index,x+31*s,py+15*s,3*s,selected and c.accent or c.muted,selected and .9 or .43,120,not selected)
                        text(f,"nav:text:"..index,page.title,x+44*s,py+8*s,theme.FontSize*s,c.text,.66+.30*selection+.13*hover,121,side-67*s)
                        if click and over and not st.popup then
                            if st.active~=page then st.pageFade=theme.ReducedMotion and 1 or 0 end
                            st.active=page; st.popup=nil; st.edit=nil; st.capture=nil; st.drag=nil; st.regions.page=nil
                        end
                        scopeOpacity,scopeDY=1,0
                    end
                end end
            end
        end
        if st.navMax>0 then
            local sx,sy,sh=x+side-8*s,navTop+6*s,navH-12*s
            local th=max(24*s,sh*navH/navTotal); local ty=sy+(sh-th)*st.navScroll/st.navMax
            rect(f,"nav:scrollTrack",sx,sy,2*s,sh,c.white,.04,s,120)
            rect(f,"nav:scrollThumb",sx-s,ty,4*s,th,c.white,.23,2*s,122)
            if click and not st.popup and hit(sx-8*s,sy,16*s,sh) then
                st.drag={kind="navscroll",y=sy+th/2,h=sh-th,maximum=st.navMax}
                st.navTarget=clamp((st.my-st.drag.y)/st.drag.h,0,1)*st.navMax; st.navScroll=st.navTarget
            end
        end
        local page=st.active; local bx,by,bw,bh=x+side+22*s,y+125*s,w-side-44*s,h-171*s
        if page then
            scopeOpacity=st.pageFade; scopeDY=(1-st.pageFade)*4*s
            text(f,"content:title",page.title,bx+2*s,y+79*s,(theme.FontSize+7)*s,c.text,.96,121,bw-90*s,true)
            local count=0; local total=22*s
            for _,row in ipairs(page.rows) do if not row.hidden then total=total+rowHeight(row,s)+theme.Spacing*s; if row.kind~="Heading" and row.kind~="Label" then count=count+1 end end end
            text(f,"content:subtitle",page.interface and (page.title=="Background" and "Atmosphere and motion" or "Your interface, your preferences") or tostring(count).." controls",bx+2*s,y+106*s,12*s,c.text,.55,121,bw-10*s)
            scopeOpacity,scopeDY=1,0
            rect(f,"content:body",bx,by,bw,bh,mix(c.tint,c.black,.23),animate("glass:bodyOpacityAnimation",theme.BodyOpacity,24,theme.BodyOpacity),10*s,111)
            rect(f,"content:edge",bx,by,bw,bh,c.white,.09+theme.Bevel*.16,12*s,114,true)
            line(f,"content:reflection",bx+12*s,by+s,bx+bw-12*s,by+s,c.white,theme.Specular*.19,115)
            local maxScroll=max(0,total-bh)
            page.targetScroll=clamp(page.targetScroll or 0,0,maxScroll)
            if input and not st.edit and not st.capture and not st.popup then
                if hit(x+14*s,navTop,side-28*s,navH) then
                    if key(34) then st.navTarget=min(st.navMax,st.navTarget+dt*430*s) end
                    if key(33) then st.navTarget=max(0,st.navTarget-dt*430*s) end
                    st.regions.sidebar.target=st.navTarget
                else
                    if key(34) then page.targetScroll=min(maxScroll,page.targetScroll+dt*430*s) end
                    if key(33) then page.targetScroll=max(0,page.targetScroll-dt*430*s) end
                end
            end
            page.scroll=scrollToward(clamp(page.scroll,0,maxScroll),page.targetScroll)
            local pageX,pageY=point(bx,by)
            st.regions.page={x=pageX,y=pageY,w=dimension(bw),h=dimension(bh),max=maxScroll,current=page.scroll,target=page.targetScroll,scale=s*drawScale,page=page}
            local ry=by+10*s-page.scroll
            scopeOpacity=st.pageFade; scopeDY=(1-st.pageFade)*4*s
            for _,row in ipairs(page.rows) do if not row.hidden then
                local rh=rowHeight(row,s)
                -- Native Drawing has no scissor: show complete rows inside the content bounds.
                if ry>=by+4*s and ry+rh<=by+bh-4*s then
                    drawRow(f,row,bx+5*s,ry,bw-20*s,s,c,click,input,y+h-43*s)
                    if not st.alive then return end
                else row.bounds=nil end
                ry=ry+rh+theme.Spacing*s
            else row.bounds=nil end end
            if maxScroll>0 then
                local sx,sy,sh=bx+bw-8*s,by+12*s,bh-24*s; local th=max(25*s,sh*bh/total); local ty=sy+(sh-th)*page.scroll/maxScroll
                rect(f,"scroll:track",sx,sy,2*s,sh,c.white,.045,s,120); rect(f,"scroll:thumb",sx-s,ty,4*s,th,c.white,.25,2*s,122)
                if click and not st.popup and hit(sx-8*s,sy,16*s,sh) then
                    st.drag={kind="scroll",y=sy+th/2,h=sh-th,maximum=maxScroll}
                    page.targetScroll=clamp((st.my-st.drag.y)/st.drag.h,0,1)*maxScroll; page.scroll=page.targetScroll
                end
            end
            drawPopup(f,c,s,click,input)
            if not st.alive then return end
            scopeOpacity,scopeDY=1,0
        end
        local contextualHint=st.edit and "Enter to apply  /  Esc to cancel" or st.capture and "Press a key  /  Esc to cancel" or st.tip
        if contextualHint then text(f,"footer:hint",contextualHint,x+side+24*s,y+h-27*s,10*s,c.text,.39,121,w-side-65*s) end
        text(f,"footer:brand",tostring(ctx.footer or "THALASSAR UI"),x+24*s,y+h-27*s,10*s,c.text,.3,120,side-40*s)
        line(f,"resize:A",x+w-21*s,y+h-9*s,x+w-9*s,y+h-21*s,c.white,.24,124)
        line(f,"resize:B",x+w-15*s,y+h-9*s,x+w-9*s,y+h-15*s,c.white,.18,124)
        if click and not st.popup and hit(x+w-27*s,y+h-27*s,24*s,24*s) then st.drag={kind="resize",dx=x+w-st.mx,dy=y+h-st.my} end
        finish(f)
    end
    local tab=ui.AddTab("Interface")
    local appearance=tab:Section("Appearance",{Group="Settings",Interface=true})
    local background=tab:Section("Background",{Group="Settings",Interface=true})
    local settings=tab:Section("Interface settings",{Group="Settings",Interface=true})
    ui.profileSection=settings; ui.SettingsSection=settings; ui.BackgroundSection=background
    local function bind(name,row)
        settingRows[name]=row
        row.callback=function(value,alpha)
            theme[name]=row.kind=="Color" and colorValues(value,alpha) or value
            safe(ctx.onAppearanceChanged,ui.exportAppearance())
        end
        return row
    end
    appearance:Heading("Glass")
    bind("Opacity",appearance:SliderFloat("thalassar_opacity","Window opacity",.35,1,theme.Opacity,"%.2f"))
    bind("BodyOpacity",appearance:SliderFloat("thalassar_body_opacity","Content opacity",.05,.95,theme.BodyOpacity,"%.2f"))
    bind("Rounding",appearance:SliderInt("thalassar_rounding","Corner radius",0,28,theme.Rounding))
    bind("Specular",appearance:SliderFloat("thalassar_specular","Glass reflection",0,1,theme.Specular,"%.2f"))
    bind("Bevel",appearance:SliderFloat("thalassar_bevel","Glass edge depth",0,1,theme.Bevel,"%.2f"))
    appearance:Heading("Palette")
    local palettes={{tint={29,32,35,255},accent={147,171,182,255},text={237,239,240,255}},
        {tint={35,33,31,255},accent={176,165,144,255},text={242,239,232,255}},
        {tint={27,33,38,255},accent={149,176,180,255},text={236,241,242,255}},
        {tint={48,48,47,255},accent={178,183,172,255},text={243,244,240,255}}}
    appearance:Combo("thalassar_palette","Preset",{"Graphite","Warm charcoal","Deep slate","Soft stone"},0,function(index)
        local p=palettes[index+1]; for _,name in ipairs({"Tint","Accent","Text"}) do set(settingRows[name],true,p[string.lower(name)]) end
    end)
    bind("Tint",appearance:ColorPicker("thalassar_tint",29,32,35,255,nil,"Glass tint"))
    bind("Accent",appearance:ColorPicker("thalassar_accent",147,171,182,255,nil,"Accent"))
    bind("Text",appearance:ColorPicker("thalassar_text",237,239,240,255,nil,"Text color"))
    appearance:Heading("Typography and layout")
    bind("Scale",appearance:SliderFloat("thalassar_scale","Interface scale",.75,1.5,theme.Scale,"%.2f"))
    bind("FontSize",appearance:SliderInt("thalassar_font_size","Text size",11,18,theme.FontSize))
    bind("Spacing",appearance:SliderInt("thalassar_spacing","Control spacing",0,12,theme.Spacing))
    local fontCodes={fonts.System or 1,fonts.Clean or 0,fonts.SoftBold or 11,fonts.Monospace or 5}
    local fontRow=appearance:Combo("thalassar_font","Font",{"System","Clean UI","Soft bold","Monospace"},0,function(index) theme.Font=fontCodes[index+1]; safe(ctx.onAppearanceChanged,ui.exportAppearance()) end)
    settingRows.Font={kind="FontSetting",callback=function(value)
        local index=0; for i,v in ipairs(fontCodes) do if v==value then index=i-1 end end; set(fontRow,true,index)
    end}
    background:Heading("Surface")
    bind("Grain",background:Toggle("thalassar_grain","Fine glass grain",theme.Grain))
    bind("GrainStrength",background:SliderFloat("thalassar_grain_strength","Grain intensity",0,.5,theme.GrainStrength,"%.2f"))
    bind("Glow",background:Toggle("thalassar_glow","Soft edge glow",theme.Glow))
    bind("GlowStrength",background:SliderFloat("thalassar_glow_strength","Glow intensity",0,1,theme.GlowStrength,"%.2f"))
    bind("Vignette",background:Toggle("thalassar_vignette","Inner edge shade",theme.Vignette))
    bind("VignetteStrength",background:SliderFloat("thalassar_vignette_strength","Shade intensity",0,.4,theme.VignetteStrength,"%.2f"))
    background:Heading("Motion")
    bind("Particles",background:Toggle("thalassar_particles","Drifting light specks",theme.Particles))
    bind("ParticleAmount",background:SliderInt("thalassar_particles_amount","Speck amount",1,24,theme.ParticleAmount))
    bind("ParticleSpeed",background:SliderFloat("thalassar_particles_speed","Drift speed",0,1,theme.ParticleSpeed,"%.2f"))
    bind("ReducedMotion",background:Toggle("thalassar_reduced_motion","Reduced motion",theme.ReducedMotion))
    bind("AnimationSpeed",background:SliderFloat("thalassar_animation_speed","Interaction speed",.5,2,theme.AnimationSpeed,"%.2f"))
    settings:Heading("Window")
    bind("MenuKey",settings:Keybind("thalassar_menu_key","Show / hide shortcut",theme.MenuKey))
    settings:Button("thalassar_reset_appearance","Restore interface defaults",ui.resetAppearance)
    settings:Label("thalassar_scroll_hint","Mouse wheel scrolls the hovered panel.")
    settings:Label("thalassar_close_hint","The dash minimizes. X closes this interface.")
    if ctx.appearance then ui.importAppearance(ctx.appearance) end
    safe(ctx.onVisibility,st.open)
    return ui
end
return createThalassarUI

end)()

local createThalassarBackgroundEffects = (function()
-- Thalassar UI: calm, configurable effects painted inside the glass window.
-- The caller owns the renderer, frame connection, and native Drawing cleanup.
local function createThalassarBackgroundEffects()
    local min, max, floor, abs = math.min, math.max, math.floor, math.abs
    local sin, sqrt, exp, pi = math.sin, math.sqrt, math.exp, math.pi
    local function clamp(v,lo,hi) return min(max(v,lo),hi) end
    local function number(v,fallback,lo,hi)
        v=tonumber(v)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return clamp(v,lo,hi)
    end
    local modes={"None","Rain","Snow","Fireflies","Bubbles","Ripples"}
    local defaults={Effect=2,Intensity=.32,Speed=.35,Wind=.12,Opacity=.56,Color={236,240,243,255}}
    local settings={Effect=2,Intensity=.32,Speed=.35,Wind=.12,Opacity=.56,Color={236,240,243,255}}
    local controls, elapsed, windOffset, activeMode, envelope = {}, 0, 0, settings.Effect, 1
    local module={}

    -- A fixed seed gives stable placement; changing a slider does not reshuffle particles.
    local seed,particles=19071995,{}
    local function random()
        seed=(seed*48271)%2147483647
        return seed/2147483647
    end
    for i=1,64 do
        particles[i]={x=random(),y=random(),size=random(),speed=random(),phase=random()*2*pi,depth=random()}
    end

    local function colorBytes(value,alpha)
        local r,g,b,a
        if type(value)=="table" or type(value)=="userdata" then
            local ok,red,green,blue=pcall(function() return value.R,value.G,value.B end)
            if ok and type(red)=="number" then
                r,g,b=red*255,green*255,blue*255
                a=number(alpha,1,0,255); if a<=1 then a=a*255 end
            elseif type(value)=="table" then
                r,g,b,a=value[1],value[2],value[3],value[4] or alpha or 255
            end
        end
        return {number(r,236,0,255),number(g,240,0,255),number(b,243,0,255),number(a,255,0,255)}
    end
    local function effectIndex(value)
        if type(value)=="string" then
            for i,name in ipairs(modes) do if string.lower(value)==string.lower(name) then return i-1 end end
            return settings.Effect
        end
        return floor(number(value,settings.Effect,0,#modes-1)+.5)
    end
    local function sync()
        for key,row in pairs(controls) do
            if type(row.SetValue)=="function" then
                if key=="Color" then row:SetValue(settings.Color)
                else row:SetValue(settings[key]) end
            end
        end
    end

    function module.install(section)
        assert(section and type(section.Combo)=="function" and type(section.SliderFloat)=="function","Background effects need a Thalassar settings section")
        if next(controls) then return module end
        if type(section.Heading)=="function" then section:Heading("Weather and ambient effects") end
        controls.Effect=section:Combo("thalassar_bg_effect","Background effect",modes,settings.Effect,function(value)
            settings.Effect=effectIndex(value)
        end)
        controls.Intensity=section:SliderFloat("thalassar_bg_intensity","Effect intensity",0,1,settings.Intensity,"%.2f",function(value)
            settings.Intensity=number(value,settings.Intensity,0,1)
        end)
        controls.Speed=section:SliderFloat("thalassar_bg_speed","Effect speed",0,1,settings.Speed,"%.2f",function(value)
            settings.Speed=number(value,settings.Speed,0,1)
        end)
        controls.Wind=section:SliderFloat("thalassar_bg_wind","Wind",-1,1,settings.Wind,"%.2f",function(value)
            settings.Wind=number(value,settings.Wind,-1,1)
        end)
        controls.Opacity=section:SliderFloat("thalassar_bg_opacity","Effect opacity",0,1,settings.Opacity,"%.2f",function(value)
            settings.Opacity=number(value,settings.Opacity,0,1)
        end)
        if type(section.ColorPicker)=="function" then
            local c=settings.Color
            controls.Color=section:ColorPicker("thalassar_bg_color",c[1],c[2],c[3],c[4],function(color,alpha)
                settings.Color=colorBytes(color,alpha)
            end,"Effect color")
        end
        if type(section.Tip)=="function" then section:Tip("Effects stay inside the window. Reduced motion freezes their movement.") end
        return module
    end

    function module.export()
        return {Version=1,Effect=modes[settings.Effect+1],Intensity=settings.Intensity,Speed=settings.Speed,
            Wind=settings.Wind,Opacity=settings.Opacity,Color={settings.Color[1],settings.Color[2],settings.Color[3],settings.Color[4]}}
    end
    function module.import(saved)
        if type(saved)~="table" then return false end
        if saved.Effect~=nil then settings.Effect=effectIndex(saved.Effect) end
        if saved.Intensity~=nil then settings.Intensity=number(saved.Intensity,settings.Intensity,0,1) end
        if saved.Speed~=nil then settings.Speed=number(saved.Speed,settings.Speed,0,1) end
        if saved.Wind~=nil then settings.Wind=number(saved.Wind,settings.Wind,-1,1) end
        if saved.Opacity~=nil then settings.Opacity=number(saved.Opacity,settings.Opacity,0,1) end
        if saved.Color~=nil then settings.Color=colorBytes(saved.Color) end
        sync(); return true
    end
    function module.reset() return module.import(defaults) end

    -- Signed distance to a rounded box. An inset test also keeps entire circles inside it.
    local function roundedDistance(x,y,b)
        local qx=abs(x-(b.x+b.w*.5))-(b.w*.5-b.r)
        local qy=abs(y-(b.y+b.h*.5))-(b.h*.5-b.r)
        local dx,dy=max(qx,0),max(qy,0)
        return sqrt(dx*dx+dy*dy)+min(max(qx,qy),0)-b.r
    end
    local function inside(x,y,b,margin) return roundedDistance(x,y,b)<=-(margin or 0)-.001 end
    local function clippedLine(x1,y1,x2,y2,b)
        local a,c=inside(x1,y1,b,.8),inside(x2,y2,b,.8)
        if not a and not c then return end
        if a and c then return x1,y1,x2,y2 end
        -- The rounded window is convex, so binary search from its inside endpoint is sufficient.
        local ix,iy,ox,oy=x1,y1,x2,y2
        if not a then ix,iy,ox,oy=x2,y2,x1,y1 end
        local lo,hi=0,1
        for _=1,10 do
            local t=(lo+hi)*.5
            if inside(ix+(ox-ix)*t,iy+(oy-iy)*t,b,.8) then lo=t else hi=t end
        end
        local ex,ey=ix+(ox-ix)*lo,iy+(oy-iy)*lo
        if a then return ix,iy,ex,ey else return ex,ey,ix,iy end
    end
    local function wrapped(value,size) return value-floor(value/size)*size end

    function module.draw(api)
        if type(api)~="table" or type(api.circle)~="function" or type(api.line)~="function" then return 0 end
        local w,h=number(api.w,0,0,10000),number(api.h,0,0,10000)
        if w<8 or h<8 then return 0 end
        local scale=number(api.scale,1,.1,4)
        local dt=number(api.dt,1/60,0,.1)
        if not api.reducedMotion then
            local motion=dt*settings.Speed*2.4
            elapsed=elapsed+motion; windOffset=windOffset+motion*settings.Wind
        end
        if api.reducedMotion then
            activeMode=settings.Effect; envelope=activeMode==0 and 0 or 1
        else
            local target=settings.Effect==activeMode and activeMode~=0 and 1 or 0
            envelope=envelope+(target-envelope)*(1-exp(-dt*12))
            if settings.Effect~=activeMode and envelope<.02 then activeMode=settings.Effect; envelope=0 end
        end
        local opacity=number(api.opacity,1,0,1)*settings.Opacity*(settings.Color[4]/255)*envelope
        if activeMode==0 or settings.Intensity<=0 or opacity<.002 then return 0 end
        local b={x=number(api.x,0,-10000,10000),y=number(api.y,0,-10000,10000),w=w,h=h,
            r=number(api.radius,0,0,min(w,h)*.5)}
        local color
        local c=settings.Color
        local ok,result=pcall(function()
            if activeMode==3 and c[1]==236 and c[2]==240 and c[3]==243 then return Color3.fromRGB(244,232,203) end
            return Color3.fromRGB(c[1],c[2],c[3])
        end)
        if ok then color=result else color=api.colors and (api.colors.white or api.colors.accent) end
        if not color then return 0 end
        local count,shapes,t=0,0,elapsed
        local function circle(id,x,y,r,alpha,outline,z)
            if r>.05 and alpha>.002 and inside(x,y,b,r+.65) then
                api.circle("background:"..id,x,y,r,color,clamp(alpha,0,1),z or 107,outline==true)
                shapes=shapes+1
            end
        end
        if activeMode==1 then
            count=floor(64*settings.Intensity+.5)
            local velocity=150*scale
            local wind=settings.Wind*42*scale
            for i=1,count do
                local p=particles[i]
                local phase=p.y+t*velocity*(.72+p.speed*.56)/h
                local x=b.x+wrapped(p.x*w+windOffset*42*scale,w)
                local y=b.y+wrapped(phase*h,h)
                local length=(8+p.size*12)*scale
                local x1,y1,x2,y2=clippedLine(x-wind/velocity*length,y-length,x,y,b)
                if x1 then
                    api.line("background:rain:"..i,x1,y1,x2,y2,color,opacity*(.38+p.depth*.4),107)
                    shapes=shapes+1
                end
                if i<=8 then
                    local q=phase-floor(phase)
                    if q>.86 then
                        local f=(q-.86)/.14
                        circle("particle:"..i,x,b.y+h-11*scale,(2+6*f)*scale,opacity*.28*(1-f),true,108)
                    end
                end
            end
        elseif activeMode==2 then
            count=floor(64*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local drift=sin(t*.25+p.phase)*12*scale
                local x=b.x+wrapped(p.x*w+windOffset*20*scale+drift,w)
                local y=b.y+wrapped(p.y*h+t*18*(.6+p.speed*.6)*scale,h)
                circle("particle:"..i,x,y,(.7+p.size*1.35)*scale,opacity*(.36+p.depth*.55),false)
            end
        elseif activeMode==3 then
            count=floor(32*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local x=b.x+wrapped(p.x*w+windOffset*10*scale+sin(t*.17+p.phase)*17*scale,w)
                local y=b.y+wrapped(p.y*h+sin(t*.2+p.phase)*13*scale,h)
                local pulse=.35+.65*(.5+.5*sin(t*.85+p.phase))
                local radius=(.85+p.size*.8)*scale
                circle("halo:"..i,x,y,radius*(3+p.depth*2),opacity*pulse*.12,false)
                circle("particle:"..i,x,y,radius,opacity*pulse*(.6+p.depth*.3),false,108)
            end
        elseif activeMode==4 then
            count=floor(36*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local x=b.x+wrapped(p.x*w+sin(t*.22+p.phase)*13*scale+windOffset*12*scale,w)
                local y=b.y+h-wrapped(p.y*h+t*18*(.6+p.speed*.6)*scale,h)
                circle("particle:"..i,x,y,(2+p.size*7)*scale,opacity*(.22+p.depth*.35),true)
            end
        elseif activeMode==5 then
            count=floor(16*settings.Intensity+.5)
            for i=1,count do
                local p=particles[i]
                local phase=p.y+t*.18*(.8+p.speed*.5)
                local f=phase-floor(phase)
                local x=b.x+(.1+p.x*.8)*w
                local y=b.y+(.1+p.depth*.8)*h
                circle("particle:"..i,x,y,(3+f*(24+p.size*48))*scale,opacity*.72*(1-f)^1.5,true)
            end
        end
        return shapes
    end
    return module
end
return createThalassarBackgroundEffects

end)()

local createWheelBridge = (function()
-- Matcha exposes no wheel-read event. A scoped local helper supplies actual detents.
local function createWheelBridge(prefix)
    prefix=prefix or "Thalassar-UI"
    local leasePath=prefix..".wheel-lease.txt"
    local eventPath=prefix..".wheel.txt"
    local function monotonic() return type(tick)=="function" and tick() or os.clock() end
    -- Matcha tick() is system uptime. Anchor it to Unix time for the helper lease.
    local timeOrigin, clockOrigin=os.time(),monotonic()
    local function now() return timeOrigin+(monotonic()-clockOrigin) end
    local session="thalassar-"..tostring(now()).."-"..tostring(math.random(100000,999999))
    local menu, closed, lastRead, nextLease, previousSequence, previousTotal
    local latestEvent,previousGeneration=0,nil
    local bridge={}
    previousSequence,previousTotal,lastRead,nextLease=0,0,0,0
    function bridge.update(force)
        if closed or not menu then return end
        local time=now()
        if not force and time<nextLease then return end
        nextLease=time+.5
        local appearance=menu.exportAppearance()
        local window=appearance.Window
        local scale=appearance.Scale or 1
        local text=table.concat({"run",session,menu.isInteracting() and "1" or "0",
            tostring(window[1]),tostring(window[2]),tostring(window[3]*scale),
            tostring(window[4]*scale),tostring(time+10)},"|")
        pcall(writefile,leasePath,text)
    end
    function bridge.setUI(value) menu=value; bridge.update(true) end
    function bridge.consume()
        if closed then return 0 end
        local time=now()
        if time-lastRead<.025 then return 0 end
        lastRead=time
        local existsOK,exists=pcall(isfile,eventPath)
        if not existsOK or not exists then return 0 end
        local ok,text=pcall(readfile,eventPath)
        if not ok or type(text)~="string" then return 0 end
        local id,generation,seq,total,x,y,stamp=text:match("^2|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
        if not id then id,seq,total,x,y,stamp=text:match("^1|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)$") end
        if id~=session then return 0 end
        seq,total,x,y,stamp=tonumber(seq),tonumber(total),tonumber(x),tonumber(y),tonumber(stamp)
        if not seq or not total or not x or not y or not stamp then return 0 end
        -- A generation token survives a missed startup packet. Count the first
        -- event from a restarted helper from zero, even if its sequence is lower.
        if generation and generation~=previousGeneration then
            if math.abs(time-stamp)>1 or stamp<latestEvent then return 0 end
            previousGeneration,previousSequence,previousTotal=generation,0,0
            latestEvent=stamp
        end
        -- A restarted companion publishes sequence zero before new wheel events.
        if seq==0 and previousSequence>0 and stamp>latestEvent and math.abs(time-stamp)<=1 then
            previousSequence,previousTotal,latestEvent=0,total,stamp
            return 0
        end
        if seq<=previousSequence then return 0 end
        local delta=total-previousTotal
        previousSequence,previousTotal,latestEvent=seq,total,stamp
        if time-stamp>1 or stamp-time>1 then return 0 end
        return math.clamp(delta,-32,32),x,y
    end
    function bridge.status()
        return {session=session,sequence=previousSequence,total=previousTotal,
            latestEvent=latestEvent,generation=previousGeneration,closed=closed==true,source="automatic local companion"}
    end
    function bridge.close()
        if closed then return end
        closed=true
        pcall(writefile,leasePath,"stop|"..session)
    end
    return bridge
end
return createWheelBridge

end)()

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

end)()
-- Neutral UI showcase. Load Library.lua first, or run the standalone Demo.lua.
local Library = assert(_G.ThalassarUI, "Load Thalassar UI before running the demo")
local state = {callbackCount = 0, lastAction = "Ready", closed = false, Controls = {}}
local Window
local summary, activity

local function refresh()
    if state.closed or not summary then return end
    local styles = {"Soft", "Balanced", "Bright"}
    summary:SetValue(string.format("Preview: %s · %d items · %s",
        Window:GetValue("enabled") and "on" or "off",
        Window:GetValue("amount"), styles[Window:GetValue("style") + 1]))
    state.Controls.amount:SetDisabled(not Window:GetValue("enabled"))
end

local function report(message)
    state.callbackCount = state.callbackCount + 1
    state.lastAction = message
    if activity then activity:SetValue("Last action: " .. message) end
    refresh()
end

Window = Library:CreateWindow({
    Title = "Thalassar UI · Demo",
    Footer = "THALASSAR UI",
    Visible = true,
    Appearance = {Opacity = 0.75},
    Background = {Effect = "Snow", Intensity = 0.22, Speed = 0.28, Opacity = 0.42},
    OnError = function(message)
        state.lastError = message
        print("Thalassar UI demo: " .. message)
    end,
    OnClose = function(reason)
        state.closed = true
        state.closeReason = reason
        if _G.ThalassarDemo == Window then _G.ThalassarDemo = nil end
    end,
})

local General = Window:Tab("General")
local Controls = General:Section("Controls")
Controls:Heading("Try the controls")
Controls:Label("Adjust values, open the color picker, or try a shortcut.")
summary = Controls:Label("demo_summary", "Preview: on · 50 items · Soft")
activity = Controls:Label("demo_activity", "Last action: Ready")

state.Controls.enabled = Controls:Toggle("enabled", "Enable preview", true, function(value)
    report(value and "Preview enabled" or "Preview paused")
end):Tip("Pausing the preview disables its amount slider.")

state.Controls.amount = Controls:SliderInt("amount", "Amount", 0, 100, 50, function(value)
    report("Amount set to " .. value)
end)

state.Controls.opacity = Controls:SliderFloat("opacity", "Window opacity", 0.2, 1, 0.75, "%.2f", function(value)
    Window:ImportConfig({Version = 1, Appearance = {Opacity = value}})
    report(string.format("Window opacity %.2f", value))
end)

state.Controls.style = Controls:Dropdown("style", "Glass style", {"Soft", "Balanced", "Bright"}, 0, function(index)
    local bodyOpacity = {0.10, 0.18, 0.24}
    Window:ImportConfig({Version = 1, Appearance = {BodyOpacity = bodyOpacity[index + 1]}})
    report("Glass style changed")
end)

state.Controls.accent = Controls:ColorPicker({
    Id = "accent", Title = "Accent color", Default = {147, 171, 182, 255},
    Callback = function(color, opacity)
        local bytes = {color.R * 255, color.G * 255, color.B * 255, opacity * 255}
        Window:ImportConfig({Version = 1, Appearance = {Accent = bytes}})
        report("Accent color changed")
    end,
})

state.Controls.name = Controls:InputText({
    Id = "preview_name", Title = "Preview name", Default = "My preview",
    Callback = function(value) report("Name: " .. value) end,
})

state.Controls.shortcut = Controls:Keybind({
    Id = "shortcut", Title = "Preview shortcut", Default = 0x4B, Mode = "toggle",
    Callback = function(active, keyCode)
        report(string.format("Shortcut %s (key %d)", active and "on" or "off", keyCode))
    end,
}):Tip("Default: K. Try it while the menu is hidden with P.")

state.Controls.action = Controls:Button("run_preview", "Run preview action", function()
    report("Preview action complete")
end)

-- Enough rows to test smooth content scrolling immediately after opening.
Controls:Heading("Scrollable options")
for index = 1, 12 do
    Controls:Toggle("example_" .. index, "Example option " .. index, index % 2 == 0, function(value)
        report("Option " .. index .. (value and " enabled" or " disabled"))
    end)
end

local Workflow = Window:Tab("Workflow")
local Profiles = Workflow:Section("Profiles")
Profiles:Heading("Settings for this session")
Profiles:Label("Remember values, change them, then restore your snapshot.")
local savedConfig, initialConfig
state.Controls.export = Profiles:Button("export", "Remember settings", function()
    savedConfig = Window:ExportConfig()
    report("Settings remembered")
end)
state.Controls.restore = Profiles:Button("restore", "Restore remembered settings", function()
    if savedConfig then
        Window:ImportConfig(savedConfig, false)
        report("Settings restored")
    else
        report("Remember settings first")
    end
end)
state.Controls.reset = Profiles:Button("reset_demo", "Restore demo defaults", function()
    if initialConfig then Window:ImportConfig(initialConfig, false) end
    report("Demo defaults restored")
end)
Profiles:Label("Snapshots stay in memory. Your application owns file storage.")

local Navigation = Workflow:Section("Navigation")
Navigation:Heading("Window and navigation")
state.Controls.background = Navigation:Button("open_background", "Open background effects", function()
    report("Background settings opened")
    Window:SelectSection("Background")
end)
state.Controls.appearance = Navigation:Button("open_appearance", "Open appearance settings", function()
    report("Appearance settings opened")
    Window:SelectSection("Appearance")
end)
state.Controls.minimize = Navigation:Button("minimize_demo", "Minimize demo", function()
    report("Demo minimized; press P to reopen")
    Window:Hide()
end)
Navigation:Label("The title-bar dash minimizes. X releases this demo's resources.")

local About = General:Section("About")
About:Heading("Thalassar UI")
About:Label("Glass panels, animated controls, and a collapsible sidebar.")
About:Label("Settings contains fonts, colors, sizing, and motion options.")
About:Label("Background effects include rain, snow, bubbles, and more.")
About:Label("This demo only changes its own interface.")
About:Label("Source, examples, and the API reference are in the public repository.")

initialConfig = Window:ExportConfig()
Window:SelectSection("Controls")
refresh()
Window:Show()

-- Handles for host integration, diagnostics, and deterministic demo cleanup.
_G.ThalassarDemo = Window
_G.ThalassarDemoState = state
print("Thalassar UI demo ready. Explore General, Workflow, and Settings.")
