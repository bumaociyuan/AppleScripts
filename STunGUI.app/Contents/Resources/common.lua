function shell_exec(command)
    local P = uv.Process
    local out,err = uv.Pipe.new()
    if err then
        debug_log(err)
        return
    end
    local process,err = uv.Process.spawn{
        args=command,
        stdio={{P.IGNORE}, {P.CREATE_PIPE + P.WRITABLE_PIPE, out}}}
    if err then
        debug_log(err)
        return
    end
    local output = "";
    local nread, buf
    repeat
        nread, buf = out:read()
        if nread and nread > 0 then
            output = output .. buf
        end
    until nread and nread < 0 
    return output
end

function connect_test(host)
    local output    = shell_exec({"/sbin/ping", "-c", "10", "-t", "10", "-q", host})
    local loss      = output:match("(%d+%.%d+)%% packet loss")
    local avg       = output:match("stddev = %d+%.%d+/(%d+%.%d+)/%d+%.%d+/%d+%.%d+ ms")
    if loss and avg then 
        return tonumber(loss), tonumber(avg)
    end
end

function route_test(host)
    local output = shell_exec({"/usr/sbin/traceroute", "-I", host})
    return output
end

function http_get_text(path)
    local comp  = parse_url(path)
    local host  = comp.host
    local ip    = safe_resolve(host)
    comp.host   = ip
    path        = build(comp)
    debug_log(path)
    return Http.get(path, {["User-Agent"]="Fish88 Client",["Host"]=host})
end

function http_get_json(path)
    local response, err = http_get_text(path)
    if err then
        debug_log(err)
        return nil, err
    end
    --debug_log(response.response_text)
    return pcall(cjson.decode, response.response_text)
end
