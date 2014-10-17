function debug_log(...)
    if true or stun.debug_mode then
        print(...)
    end
end


-- 监视hosts文件变化
if uv.FsEvent then
    wc = uv.FsEvent.new()
    wc:start("/etc/", 0, function(path, event)
        if path == "hosts" then
            debug_log("/etc/hosts changed, clean dns cache!")
            _G.dns_cache = {}
        end
    end)
end

dns_cache = {}
coroutine.wrap(function()
    local now
    local timer = uv.Timer.new()
    while true do
        now = os.time()
        for k, v in pairs(dns_cache) do
            if v and now - v.t > 1800 then 
                dns_cache[k] = nil
            end
        end
        timer:sleep(60 * 1000)
    end
end)()

function resolve(domain, tcp)
    --域名绑定
    local t, err, ip
    if _G.hosts and hosts[domain] then
        debug_log(domain, "resovle from hosts", hosts[domain])
        return hosts[domain]
    end
    --DNS缓存
    if dns_cache[domain] then
        debug_log(domain, "resovle from cache", dns_cache[domain].ip)
        return dns_cache[domain].ip
    end
    if tcp then
        t,err = TcpDns.resolve(domain)
        if type(t) == 'table' and table.maxn(t) > 0 then
            local ip = t[1]
            dns_cache[domain] = {["ip"]=ip,["t"]=os.time()}
            return ip
        end
    else
        t,err = uv.Dns.getaddrinfo(domain, "80", {["family"]=uv.SockAddr.AF_INET,
            ["protocol"]=uv.SockAddr.IPPROTO_TCP
            })
        if type(t) == 'table' and table.maxn(t) > 0 then
            local ip,err = t[1].addr:host()
            dns_cache[domain] = {["ip"]=ip,["t"]=os.time()}
            return ip
        end
    end
    debug_log(domain, "can't resolve", err)
    return nil
end

tcp_resovle_support = false

function safe_resolve(domain)
    if dns_cache[domain] then
        return dns_cache[domain].ip
    end
    local list = nil
    local timer = uv.Timer.new()
    while not list do
        if not stun.debug_mode then
            list = TcpDns.resolve(domain)
        end
        -- 有些用户的网络无法进行tcp dns查询
        -- 改用普通的udp方式
        if not list then
            list = udp_resolve(domain)
        else
            _G.tcp_resovle_support = true
        end
        -- 开机启动时网络可能没有就绪
        if not list then
            timer:sleep(2 * 1000)
        end
    end

    if table.maxn(list) then
        dns_cache[domain] = {["ip"]=list[1],["t"]=os.time()}
    end

    return list[1]
end


function udp_resolve(name)
    local t,err = uv.Dns.getaddrinfo(name, "80", {["family"]=uv.SockAddr.AF_INET,
        ["protocol"]=uv.SockAddr.IPPROTO_TCP
        })
    if t then
        local ips = {}
        for k, v in pairs(t) do
            local ip,err = v.addr:host()
            ips[#ips + 1] = ip
        end
        if table.maxn(ips) then
            return ips
        else
            return nil
        end
    else
        return nil
    end
end

--更新配置文件
function update_config(options)
    local result = {};
    result["continue"] = true;
    local url = string.format(
        "http://%s/get_cfg.php?os=%s&ver=%s&id=%s&server=%s&from=%s&node_id=%s",
        fish88_server,
        stun.os,
        stun.gui_version(),
        stun.device_id,
        current_server or "",
        options.from or "",
        options.node_id or ""
        )
    print(os.date("%Y-%m-%d %H:%M:%S"), url)
    local rt, obj = http_get_json(url)
    if not rt then
        result["error"] = "net_fail"
    else
        if obj.server then
            _G.current_server = obj.server
            print('get server ok:', current_server)
        end
        if type(obj.route) == 'string' then
            local route_func = loadstring(obj.route)
            if route_func then route_func() end
        end
        if obj["break"] then
            result["continue"] = false
        end
        if obj.alert and _G.gui_alert then
            gui_alert(obj.alert)
        end
        if type(obj.notify) == "table"  and _G.gui_notify then
            gui_notify(obj.notify)
        end
        if type(obj.nodes) == 'table' and _G.gui_render_nodes then
            gui_render_nodes(obj.nodes)
        end
    end
    return result
end

-- 选择服务器
function gui_select_node(node_id)
    debug_log("select node", node_id)
coroutine.wrap(function()
    local options = {}  
    options["node_id"]  = node_id
    options["from"]     = "gui"
    update_config(options)
end)()
end

-- 定时更新客户端配置文件
coroutine.wrap(function()
    local timer = uv.Timer.new()
    local options = {}
    options["from"] = "cron"
    while true do
        local rt = update_config(options)
        if rt["error"] then
            timer:sleep(10 * 1000)
        elseif rt["continue"] then
            if stun.debug_mode then
                timer:sleep(60 * 1000)
            else
                timer:sleep(300 * 1000)
            end
        else
            debug_log("stop update config")
            break 
        end
    end
end)()

-- 定时检测服务器的丢包率，延迟
coroutine.wrap(function()
    local loss, avg
    local url
    local timer = uv.Timer.new()
    -- 等待网络就绪
    timer:sleep(2 * 60 * 1000)
    while true do
        if current_server then
            debug_log("start ping test", current_server)
            loss, avg = connect_test(current_server)
            url = string.format("http://%s/health_report.php?os=%s&ver=%s&id=%s&server=%s&loss=%d&rt=%d",
            fish88_server,
            stun.os, stun.gui_version(),
            stun.device_id, current_server or '', loss or 0, avg or -1) 
            debug_log(url)
            http_get_text(url)
        end
        --每20分钟检测一次
        if stun.debug_mode then
            timer:sleep(2 * 60 * 1000)
        else
            timer:sleep(20 * 60 * 1000)
        end
    end
end)()

-- 定时检测到服务器的路由
coroutine.wrap(function()
    local route
    local url
    local timer = uv.Timer.new()
    -- 等待网络就绪
    timer:sleep(2 * 60 * 1000)
    while true do
        if current_server then
            debug_log("start route test", current_server)
            route = route_test(current_server)
            url = string.format("http://%s/route_report.php?os=%s&ver=%s&id=%s&server=%s&route=%s",
            fish88_server,
            stun.os, stun.gui_version(),
            stun.device_id, current_server or '', escape(route or '')) 
            debug_log(url)
            http_get_text(url)
        end
        --1小时检测一次
        if stun.debug_mode then
            timer:sleep(2 * 60 * 1000)
        else
            timer:sleep(60 * 60 * 1000)
        end
    end
end)()


function route(tun, cb)
coroutine.wrap(function()
    local host = tun.to_host
    local ip
    if host == 'ybb01.com' or host == 'ybb02.com' then
        ip = safe_resolve(host)
    else
        ip = resolve(host)
    end
    debug_log(host, ip)
    if ip == "127.0.0.1" 
        and (tun.to_port == s5_port or tun.to_port == http_port) then
        cb("deny")
        return
    end
    if ip then
        cb("local", ip)
    else
        cb("local")
    end
end)()
end

