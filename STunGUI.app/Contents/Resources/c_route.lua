hot = {
    "google",
    "gstatic",
    "akamain",
    "blogspot",
    "openvpn",
    "gfw",
    "bbc.co.uk",
    "blogger.com",
    "appspot",
    "chrome",
    "wordpress",
    "amazon",
    "youtube",
    "ytimg.com",
    "facebook",
    "fbcdn.net",
    "twitter",
    "twimg.com",
    "wikipedia",
    "wikimedia",
    "feedburner.com",
    "stackoverflow.com",
    "slideshare.net",
    "instagram.com",
    "goo.gl",
    "uxengine.net",
    "sourceforge.net",
    "4sq.com",
    "foursquare",
    "4sqi.net",
    "github.com",
    "t66y.com",
    "yimg.com",
    "blogblog.com",
    "flickr.com",
    "bit.ly"
}

dns_cache = {}
coroutine.wrap(function()
    local now
    while true do
        now = os.time()
        for k, v in pairs(dns_cache) do
            if v and now - v.t > 1800 then 
                dns_cache[k] = nil
            end
        end
        uv.sleep(60 * 1000)
    end
end)()

function resolve(n)
    if dns_cache[n] then
        return dns_cache[n].ip
    end
    local t = uv.getaddrinfo(n, "80", nil)
    for k, v in pairs(t) do
        if v.family == uv.SockAddr.AF_INET then
            local ip = v.addr:host()
            dns_cache[n] = {["ip"]=ip,["t"]=os.time()}
            return ip
        end
    end
    return nil
end

proxy_port=8888
server_groups = nil
current_server = nil

coroutine.wrap(function()
    while true do
        local list = uv.tcp_resolve("list.fish88.neto3.com")
        server_groups = list
        if list then
            local found = false
            for k,v in ipairs(list) do
                NSLog("get server " .. v)
                if v == current_server then
                    found = true
                end
            end
            if not found then
                current_server = nil
                NSLog("renew current server")
            else
                NSLog("find current server")
            end
        end
        uv.sleep(300 * 1000)
    end
end)()

function randomport()
    return math.random(8880, 8888)
end

function randomrelay()
    if not server_groups then
        return nil
    else
        if not current_server then
            current_server = server_groups[math.random(1, #server_groups)]
        end 
        return current_server
    end
end

function route(tun, cb)
coroutine.wrap(function()
    local host = tun.to_host
    local ip

    if host == "127.0.0.1" or host == "localhost" then
        if tun.to_port == s5_port or tun.to_port == http_port then
            cb("deny")
        else
            cb("local")
        end
        return
    end

    local relay = randomrelay()
    if not relay then
        cb("local")
        return
    end

    if tun.to_type == stun.AddressTypeIPV4 then
       ip = host 
    else
        for i, d in ipairs(hot) do
            t = string.find(host, d, 1, true)
            if t ~= nil then
                cb("gfw", relay, randomport(), username, password)
                gui_route_gfw();
                return
            end
        end
        ip = resolve(host)
    end

    if ip then
        if stun.is_china_ip(ip) or stun.is_wan_ip(ip) then
            cb("local", ip)
        else
            cb("gfw", relay, randomport(), username, password)
            gui_route_gfw();
        end
    else
        cb("local")
    end
end)()
end

