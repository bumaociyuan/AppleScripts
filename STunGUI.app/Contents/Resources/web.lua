function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

math.randomseed(os.time())
function realrandom(maxlen)
    local tbl = {}
    local num = tonumber(string.sub(tostring(tbl), 8))
    if maxlen ~= nil then
        num = num % maxlen
    end
    return num
end

function string.random(length,pattern)
    local length = length or 11
    local pattern = pattern or '%a%d'
    local rand = ""
    local allchars = ""
    for loop=0, 255 do
        allchars = allchars .. string.char(loop)
    end
    local str=string.gsub(allchars, '[^'..pattern..']','')
    while string.len(rand) ~= length do
        local randidx = realrandom(string.len(str))
        local randbyte = string.byte(str, randidx)
        rand = rand .. string.char(randbyte or 63)
    end

    return rand
end

web_token = string.random(10)

function shell_exec(command)
    local P = uv.Process
    local out = uv.Pipe.new()
    local process = uv.Process.spawn{
        args=command,
        stdio={{P.IGNORE}, {P.CREATE_PIPE + P.WRITABLE_PIPE, out}}}
    out:startRead()
    local output = "";
    local nread, buf
    repeat
        nread, buf = out:read()
        if nread and nread > 0 then
            output = output .. buf:toString(1, nread)
        end
    until nread and nread < 0 
    out:close()
    process:wait()
    return output
end

function html_header(response)
    response:write("HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/html\r\n\r\n");
    response:write([[<!doctype html>
    <html>
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Super Tunnel</title>
    </head>
    <body>]]);
end

function html_footer(response)
    response:write("</body></html>");
    response:close()
end

pages = {}

pages["/other"] = function(url, reqeust, response)
    local html = {}

    if s5_enable == 1 then
        table.insert(html, "sock5代理:127.0.0.1:" .. s5_port .. "<br />")
    end

    if http_enable == 1 then
        table.insert(html, "http代理:127.0.0.1:" .. http_port .. "<br />")
    end

    table.insert(html, "请手工设置您的浏览器代理")

    html_header(response)
    response:write(table.concat(html))
    html_footer(response)
end


pages["/global"] = function(url, reqeust, response)
    html_header(response)

    local html = {}

    local is_on, addr, port= stun.sys_current_s5_proxy()
    if is_on == nil then
        table.insert(html, "<center><h3>代理获取失败:" .. addr .. "</h3></center>")
    elseif is_on == 1 and port == s5_port then
        table.insert(html,
            string.format(
                [[<center><h3>
                科学上网已启用!
                </h3></center>
                <ul>
                <li><a target="_blank" href="http://www.twitter.com">立刻访问twitter,测试下</a></li>
                <li><a href="/global_proxy_off?token=%s">停止科学上网</a></li>
                </ul>
                ]],
                web_token
            )
        )

    else
        table.insert(html, 
            string.format(
                [[<center><h3>
                科学上网未启用,<a href="/global_proxy_on?token=%s">点击启用</a>
                </h3></center>
                ]],
                web_token
            )
        )
    end

    response:write(table.concat(html))
    html_footer(response)
end

pages["/firefox"] = function(url, reqeust, response)
coroutine.wrap(function()
    html_header(response)
    local html = {}
    local output =  shell_exec({"/bin/sh", stun.exepath .. "/mac_firefox_proxy_status.sh"})
    output = trim(output)

    if output == "on" then
        table.insert(html, "<center><h3>科学上网已开启!</h3></center>")
        table.insert(html, 
            string.format(
                [[
                <ul>
                <li><a target="_blank" href="http://www.twitter.com">立刻访问twitter,测试下</a></li>
                <li><a href="/firefox_proxy_off?token=%s">停止科学上网</a>(会重启浏览器!)</li>
                </ul>
                ]],
                web_token
            )
        )
    elseif output == "off" then
        table.insert(html, 
            string.format(
                [[
                <center><h3>
                    科学上网未启用<a href="/firefox_proxy_on?token=%s">点击启用</a>(会重启浏览器!)
                </h3></center>
                ]],
                web_token
            )
        )
    else
        table.insert(html, "<center><h3>出错了:" .. output .. "</h3></center>")
    end
    response:write(table.concat(html))
    html_footer(response)
end)()
end


pages["/index"] = function(url, reqeust, response)
    html_header(response)
    response:write([[
<script>
var ua = window.navigator.userAgent;
if (ua.indexOf('AppleWebKit') !== -1) {
    window.location.href = '/global';
} else if (ua.indexOf('Firefox') !== -1) {
    window.location.href = '/firefox';
} else {
    window.location.href = '/other';
}
</script>
    ]])
    html_footer(response)
end


--开启firefox代理
pages["/firefox_proxy_on"] = function(url, request, response)
    local query = parse_query(url.query or "")
    if query.token ~= web_token then
        html_header(response)
        response:write("非法操作");
        html_footer(response)
        return
    end
coroutine.wrap(function()
    local output =  shell_exec({"/bin/sh", stun.exepath .. "/mac_firefox_proxy_on.sh"})
    html_header(response)
    response:write(output)
    html_footer(response)
end)()
end

--关闭firefox代理
pages["/firefox_proxy_off"] = function(url, request, response)
    local query = parse_query(url.query or "")
    if query.token ~= web_token then
        html_header(response)
        response:write("非法操作");
        html_footer(response)
        return
    end
coroutine.wrap(function()
    local output =  shell_exec({"/bin/sh", stun.exepath .. "/mac_firefox_proxy_off.sh"})
    html_header(response)
    response:write(output)
    html_footer(response)
end)()
end

--开启全局代理
pages["/global_proxy_on"] = function(url, request, response)
    local query = parse_query(url.query or "")
    if query.token ~= web_token then
        html_header(response)
        response:write("非法操作");
        html_footer(response)
        return
    end
    stun.sys_enable_s5_proxy("127.0.0.1", s5_port)
    response:write("HTTP/1.1 302 Rediect\r\nConnection: close\r\nLocation: /\r\n\r\n");
    response:close()
end

--关闭全局代理
pages["/global_proxy_off"] = function(url, request, response)
    local query = parse_query(url.query or "")
    if query.token ~= web_token then
        html_header(response)
        response:write("非法操作");
        html_footer(response)
        return
    end
    stun.sys_disable_s5_proxy()
    response:write("HTTP/1.1 302 Rediect\r\nConnection: close\r\nLocation: /\r\n\r\n");
    response:close()
end

--Http入口路由
function http(request, response)
    local url = parse_url(request.url)
    local path = url.path
    local page = pages[path]
    if type(page) == "function" then
        page(url, reqeust, response)
    elseif path == "/" or path == "" then
        pages["/index"](url, reqeust, response)
    else
        response:write("HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n");
        response:close()
    end
end
