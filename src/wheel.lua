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
