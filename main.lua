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
local url = require("socket.url")
local fork = require("fork")
local server = socket.tcp()
assert(server:bind("0.0.0.0", tonumber((...)) or 80))
server:listen()

math.randomseed(os.time())
while true do
  print("A")
  local conn = assert(server:accept())
  local reqfields = {data = ""}
  local l0 = true
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
  print(rt, pt)
  -- do this here *before forking* to avoid collisions
  local tmpfname = tostring(math.random(1, 999999))
  local pid = 0-- fork.fork()
  if pid == 0 then -- child process
    if rt == "GET" then
      conn:send("got " .. rt .. ", " .. pt .. "\r\n")
    elseif rt == "POST" then
      if reqfields["Content-Type"] == "application/x-www-form-urlencoded" then
        print("RECIEVE POST DATA")
        local postdata = ""
        while conn:dirty() do
          postdata = postdata .. conn:receive(1)
        end
        print("POST", postdata)
        if postdata == "shutdown=1" then
          server:close()
          break
        else
          local lines = {}
          for field in postdata:gmatch("[^%?&]") do
            lines[#lines+1] = field .. "\n"
          end
          if pt == "/" then pt = "index" end
          local handle, err = io.popen("api/POST/"..pt.." > /tmp/"..tmpfname, "w")
          if not handle then
            print("\27[97;101m" .. err .. "\27[39;49m")
          else
            handle:write(table.concat(lines))
            handle:close()
            local input = io.open("/tmp/"..tmpfname, "r")
            local data = input:read("a")
            input:close()
            os.remove("/tmp/"..tmpfname)
            conn:send(data)
          end
        end
      end
    else
      print("bad POST Content-Type: " .. (reqfields["Content-Type"] or "unknown"))
    end
    conn:close()
    os.exit()
  elseif pid == -1 then
    print("\27[97;101mfailed creating child process!\27[39;49m")
    conn:close()
  else
    print("forked child process " .. pid)
  end
end
