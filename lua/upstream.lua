local upstream = require "ngx.upstream"
local json=require "cjson"

local get_servers = upstream.get_servers
local get_upstreams = upstream.get_upstreams
local cache=ngx.shared.upstream

-- get all peers for upstram: u
function list(u)
  
  local d={} 
  d["name"]=u    
  d["value"]={}

  -- get primary peers
  local peers,err = upstream.get_primary_peers(u)
  if err then
       ngx.say("failed to get primary servers in upstream ", u)
       return
  end
  for _,p in ipairs(peers) do 
      local s={}   
      s["id"]=p.id
      s["down"]=p.down and p.down or false
      s["name"]=p.name
      s["backup"]=false
      table.insert(d["value"],s) 
  end 

  -- get backup peers
  peers,err = upstream.get_backup_peers(u)
  if err then
       ngx.say("failed to get backup servers in upstream ", u)
       return
  end
  for _,p in ipairs(peers) do 
      local s={}   
      s["id"]=p.id
      s["down"]=p.down and p.down or false
      s["name"]=p.name
      s["backup"]=true
      table.insert(d["value"],s) 
  end 
  
  ngx.header["Content-type"]="application/json;charset=utf-8"  
  ngx.say(json.encode(d))
end


function upordown(upstream_name,is_backup,peer_id,down_value)
   local t={}
   t["upstream"]=upstream_name
   t["backup"]=is_backup
   t["id"]=peer_id
   t["value"]=down_value 
   local rKey=upstream_name .. ":" .. tostring(peer_id)  .. ":" .. tostring(is_backup)
   local key="d:" .. rKey
   local vKey="v:" .. rKey
   cache:add(vKey,0) 
   local v,err=cache:incr(vKey,1)
   if not v then
     return false
   end
   local suc=cache:set(key,json.encode(t))
   return suc
end

local args=ngx.req.get_uri_args()
local method=args["method"]

-- make sure upstream exist
local upstream = args["upstream"]
if  upstream == nil  or  upstream == '' then
  ngx.exit(400)
  ngx.log(ngx.ERR, "request params is error. upstream is null")
end

if method == "list" then
    list(upstream)
elseif(method=="down" or method=="up") then
  local backup=args["backup"]=="true" and true or false
  local id=tonumber(args["id"])
  local down= method=="down" and true or false
  local t={}
  ngx.header["Content-type"]="application/json;charset=utf-8"  
  if not id then
    ngx.exit(400)
    ngx.log(ngx.ERR, "request params is error. upstream or id is null")
  else
    local suc=upordown(upstream,backup,id,down)
    t["suc"]=suc
    ngx.say(json.encode(t))
  end
end
