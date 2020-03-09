local modname= ...
local M={}
_G[modname]=M
package.loaded[modname]=M


local http_request = require "http_request"
 
-- mal ip controller api --------
function M:switch()
   local method=http_request.get_req_param("method")

   if method == "query" then
       local percentage = lua_context.lua_conf_cache:get("switch:percentage")
       if not percentage then
        percentage = '0'
       end
       ngx.say(percentage)
       ngx.exit(ngx.HTTP_OK)
  
   end

   if method == "switch" then
      local  percentage = http_request.get_req_param("percentage")
      if percentage then
       lua_context.lua_conf_cache:set("switch:percentage", percentage)
       ngx.exit(ngx.HTTP_OK)
      end
   end
    --- force uid to aws
   if method == "force" then
    local  uid = http_request.get_req_param("uid")
    if uid then
     lua_context.lua_conf_cache:set("switch:uid", uid)
     ngx.exit(ngx.HTTP_OK)
    end
   end

      --- reset all
   if method == "reset" then
         lua_context.lua_conf_cache:delete("switch:uid")
         lua_context.lua_conf_cache:delete("switch:percentage")
         ngx.exit(ngx.HTTP_OK)
   end
end 
 
function M:get_percentage()
  local per =  lua_context.lua_conf_cache:get("switch:percentage")
  if not per then
    return 0
  else
   return tonumber(per)
  end
end

function M:get_force_uid()
  local uid = lua_context.lua_conf_cache:get("switch:uid")
  if uid then
    return tonumber(uid)
  else
    return nil
  end
end