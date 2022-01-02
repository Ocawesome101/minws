#!/usr/bin/env lua
-- a simple no-frills webserver written in Lua and extensible in
-- almost any language

local socket = require("socket")
local fork = require("fork")
local server = socket.tcp()
assert(server:bind("0.0.0.0", tonumber((...)) or 80))
server:listen()

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
        break
      end
    else
      print("bad POST Content-Type: " .. (reqfields["Content-Type"] or "unknown"))
    end
  end
  conn:close()
end

server:close()
