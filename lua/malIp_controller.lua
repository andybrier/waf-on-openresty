local modname= ...
local M={}
_G[modname]=M
package.loaded[modname]=M

local cjson=require "cjson"
local http_request = require "http_request"


local cache=lua_context.mal_ip_cache
local redis_limit_ip=lua_context["redis_limit_ip"]


 
-- mal ip controller api --------
function M:mal_ip()
   local method=http_request.get_req_param("method")
   local ips=http_request.get_req_param("ips")
   local expire=http_request.get_req_param("expire")
   ngx.header["Content-type"]="application/json;charset=utf-8"
   if not method then
    ngx.say('{"code": 400, "msg": "params error!"}')
	 ngx.exit(ngx.HTTP_OK)
   end
   local exists={}
   if method == 'pubAdd' then
      local t={}
      t.ips=ips
      t.expire=expire
      t.type="add"
      redis_limit_ip:cmd("publish","mal_ips",cjson.encode(t))
   elseif  method == 'pubDel' then 
      local t={}
      t.ips=ips
      t.type="del"
      redis_limit_ip:cmd("publish","mal_ips",cjson.encode(t))
   elseif method == 'flushAll' then
      local t={}
      t.type="flush"
      redis_limit_ip:cmd("publish","mal_ips",cjson.encode(t))
   elseif method == 'queryAll' then
     local all_ips=cache:get_keys(0)
	  for i,v in pairs(all_ips) do
	    exists[#exists+1]=string.sub(v,8,string.len(v))
	  end
   else 
     for ip in string.gmatch(ips,"[^',']+") do
         if method == 'add' then
             local expire= (not expire) and 43200 or expire
             cache:set("yh:mip:" .. ip,"1",expire)
         elseif method == 'del' then
	         cache:delete("yh:mip:" .. ip)
         elseif method == 'exists' then 
             local res=cache:get("yh:mip:" .. ip)
             res= res and true or false
             exists[#exists+1]=tostring(res)
         end
     end 
   end
   local body=table.concat(exists,",")
   ngx.say('{"code": 200, "msg": "'.. body ..'"}')
   ngx.exit(ngx.HTTP_OK)
end 
