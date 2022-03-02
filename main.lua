#!/usr/bin/env lua
-- a simple no-frills webserver written in Lua and extensible in
-- almost any language.  does *not* support HTTPS.

-- handler calling convention:
  -- the file must be under api/{REQUEST_TYPE}/{PATH}, e.g. api/POST/login, and must be executable.
  -- if the path is "/", then api/{REQUEST_TYPE}/index will be used.
  -- any request parameters will be split into lines on every ? and &, and written to the handler's
  --  standard input.
  -- response data is read from the handler's standard output.

local socket = require("socket")
local server = socket.tcp()
assert(server:bind("0.0.0.0", tonumber((...)) or 80))
server:listen()

math.randomseed(os.time())
while true do
  print("A")
  local conn = assert(server:accept())
  local reqfields = {data = ""}
  repeat
    local data = conn:receive("*l")
    if #data > 0 then
      local key, val = data:match("(.-): (.+)")
      if not (key and val) then
        reqfields.data = reqfields.data .. data .. "\n"
      else
        reqfields[key] = val
      end
    end
  until data == ""
  local rt, pt = reqfields.data:match("^([A-Z]+) ([^ ]+)")
  -- do this here *before forking* to avoid collisions
  local tmpfname = tostring(math.random(1, 999999))
  local pid = 0-- fork.fork()
  if pid == 0 then -- child process
    local reqdata = ""
    while conn:dirty() do
      reqdata = reqdata .. conn:receive(1)
    end
    local cont
    if rt == "POST" then
      if reqfields["Content-Type"] == "application/x-www-form-urlencoded" then
        print("RECIEVE POST DATA")
        print("POST", reqdata)
        if reqdata == "shutdown=1" then
          server:close()
          break
        end
        cont = true
      else
        print("bad POST Content-Type: " ..
          (reqfields["Content-Type"] or "unknown"))
      end
    elseif rt == "GET" then
      if pt:find("[&?]") then
        pt, reqdata = pt:match("([^&%?]+)(.+)")
      end
      cont = true
    end
    if pt == "/" then pt = "index" end
    print(rt, pt)
    if cont then
      local lines = {}
      for field in reqdata:gmatch("[^%?&]+") do
        lines[#lines+1] = field .. "\n"
      end
      local handle, err = io.open("api/"..rt.."/"..pt, "r")
      if handle then
        handle:close()
        handle, err
          = io.popen("api/"..rt.."/"..pt.." > /tmp/"..tmpfname, "w")
      end
      if not handle then
        print("\27[97;101m" .. err .. "\27[39;49m")
        conn:send("HTTP/1.1 404 Not Found\r\nContent-Type: text/html\r\n\r\n<html><body>minws: 404 Not Found</body></html>\r\n")
      else
        conn:send("HTTP/1.1 200 OK\r\n")
        handle:write(table.concat(lines))
        handle:close()
        local input = io.open("/tmp/"..tmpfname, "r")
        local data = input:read("*a")
        -- add Content-Type header, if it's missing
        if data:sub(1, 12) ~= "Content-Type" then
          data = "Content-Type: text/html\r\n\r\n" .. data
        end
        input:close()
        os.remove("/tmp/"..tmpfname)
        conn:send(data)
      end
    end
    conn:close()
  elseif pid == -1 then
    print("\27[97;101mfailed creating child process!\27[39;49m")
    conn:close()
  else
    print("forked child process " .. pid)
  end
end

server:close()
os.exit()
