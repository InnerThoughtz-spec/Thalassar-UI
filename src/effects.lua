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
