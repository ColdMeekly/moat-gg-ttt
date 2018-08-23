
NET_LIMITS = NET_LIMITS or {}
local LIMITS = NET_LIMITS
local time = SysTime

net.ReceiveNoLimit = net.ReceiveNoLimit or net.Receive
function net.Receive( name, _func )
    LIMITS[name] = {}
    local LIMITS = LIMITS[name]

    local function func(len, p)
        local limit = LIMITS[p]
        local now = time()
        local s,e
        if (not limit) then
            limit = {
                starttime = now,
                lasttime = 0,
                cputime = 0,
                errors = 0,
                calls = 0,
                starttick = engine.TickCount()
            }
            LIMITS[p] = limit
        elseif (limit.lasttime + 0.000000001 > now) then
            return
        -- reset at 2
        elseif (limit.lasttime + 2 < now) then
            limit.starttime = now
            limit.cputime = 0
            limit.errors = 0
            limit.starttick = engine.TickCount()
            limit.notified = false
        -- calculate if this person is hogging the cpu with this request
        elseif (limit.calls > 10 and (engine.TickCount() - limit.starttick + 1) * engine.TickInterval() / (now - limit.starttime) < 1.2) then
            if (not limit.notified) then
                print(string.format("%s <%s> triggered net limiter for %s", p:Nick(), p:IPAddress(), name))
                limit.notified = true
            end
            goto endpoint
        end

        s, e = xpcall(_func, function(err)
            return {p, err, debug.getinfo(3).source, nil, nil, debug.traceback()}
        end, len, p)

        if (not s) then
            limit.errors = limit.errors + 1
            hook.Run("LuaError", e[1], e[2], e[3], e[4], e[5], e[6])
        end

::endpoint::

        local finished = time()

        limit.calls = limit.calls + 1
        limit.cputime = limit.cputime + finished - now
        limit.lasttime = finished
    end

    net.ReceiveNoLimit(name, func)
end

if (CLIENT) then
    error("SHOULD NOT BE ON CLIENT")
end