local http = require "resty.http"
local cjson = require "cjson"

local rate_limit_conf_url="http://config.server/config.yaml"
local limit_ip_access_url="http://config.server/config.yaml"
local nginx_common_conf_url="http://config.server/config.yaml"
local limit_ip_redis=lua_context["redis_limit_ip"]

local  upstream_cache=ngx.shared.upstream
local  upstream = require "ngx.upstream"

function split_str_list(str,spliter,limit)
    local ips={}
    if not str then
      return ips
    end
    string.gsub(str,'[^' .. spliter ..']+',function(w) table.insert(ips, w) end )
    if limit and limit>0 and limit<#ips then
      local str=table.concat(ips,spliter,limit,#ips)
      table.insert(ips,limit,str)
      for i=1,#ips-limit do
        table.remove(ips)
      end
    end
    return ips
end

function  toboolean(str,default)
  if str == nil then
   return default
  end

  if str == "true" then
   return true
  else
   return false
  end
end

local query_common_conf=function()
  local httpc = http:new()

   local ok, code, headers, status, body  = httpc:request{
     url=nginx_common_conf_url,
     method="GET",
	 timeout=120000
   }
   if ok then
    local rate_limit_conf=cjson.decode(body)
    local property=rate_limit_conf["propertySources"] 
    if property then
       local property=property[1]
       if property then
          local source=property["source"]
          if source then
            local common_conf={}
            common_conf.lua_golbal_switch=source["lua_golbal_switch"]
            lua_context.lua_conf_cache:set("common_conf",cjson.encode(common_conf))
          end 
       end
     end
   else
    ngx.log(ngx.ERR, "request error:" .. tostring(code))
  end
end

-->>begin: query rate limit config function definition
local query_rate_limit_conf=function()
   local httpc = http:new()

   local ok, code, headers, status, body  = httpc:request{
     url=rate_limit_conf_url,
     method="GET",
	 timeout=120000
   }
   
  if ok then
    local rate_limit_conf=cjson.decode(body)
    local property=rate_limit_conf["propertySources"] 
    if property then
       local property=property[1]
       if property then
          local api_rate_limit_conf={api_rate_limit={}}
          local source=property["source"]
          api_rate_limit_conf["is_open"]=source["open_limit_flow"]
          api_rate_limit_conf["default_rate_limit"]=tonumber(source["default_rate_limit"])
          for k,v in pairs(source) do
            if string.find(k,"^api_rate_limit*") then
              local t=split_str_list(k,".")
              table.remove(t,1)
              local key=table.concat(t,".")	
              local vals=split_str_list(v,",",3)			  
              api_rate_limit_conf.api_rate_limit[key]={tonumber(vals[1]),tonumber(vals[2]),vals[3]}
            end
          end
          lua_context.lua_conf_cache:set("api_rate_limit_conf",cjson.encode(api_rate_limit_conf))
       end
    end
  else
    ngx.log(ngx.ERR, "request error:" .. tostring(code))
  end
end 
--<<end: query rate limit config function definition


-->>begin: query limit ip access config function definition
local query_limit_ip_access_conf=function()
   local httpc = http:new()

   local ok, code, headers, status, body  = httpc:request{
     url=limit_ip_access_url,
     method="GET",
	 timeout=120000
   }
   
  if ok then
    --ngx.log(ngx.ERR, ">>>>>>>>>>>>>>" .. tostring(body))
    local rate_limit_conf=cjson.decode(body)
    local property=rate_limit_conf["propertySources"] 
    if property then
       local property=property[1]
       if property then
         local source=property["source"]
         if source then
            local limit_ip_access={ degrades = {} }      

            limit_ip_access["is_open"]=source["is_open"] 
 
            local white_ips={}    
            for k,v in pairs(source) do
               if string.find(k,"^white_ips%[*") then
                  table.insert(white_ips,v)    
               elseif string.find(k,"^degrade_methods%[*") then
                 if v and  v ~= '' then     
                   d_method = split_str_list(v, ",", 2)
                   local e_code = d_method[2]
                   if e_code == nil then  e_code = 9999991 end
                   limit_ip_access.degrades[d_method[1]] = e_code
                 end
               end
            end
            limit_ip_access["white_ips"]=white_ips
            lua_context.lua_conf_cache:set("limit_ip_access",cjson.encode(limit_ip_access))
         end
       end
    end 
  else
    ngx.log(ngx.ERR, "request error:" .. tostring(code))
  end

end 
--<<end: query limit ip access config function definition



-->>begin: subscribe ip blacklist event
local cache=lua_context.mal_ip_cache
local subscribe_mal_ips=function()
  if ngx.worker.id() ~= 0 then
    return false
  end
  local connect=limit_ip_redis:getConnect()
  if not connect then
    ngx.log(ngx.ERR,"subscribe blacklist ip get connection err" ) 
    return false 
  end

  local res, err=connect:subscribe("mal_ips")
  if not res then
     connect:close()
     ngx.log(ngx.ERR,"subscribe blacklist ip connection subscribe err:" .. tostring(err)) 
     return false
  end

  connect:set_timeout(86400000)
  while true do 
    local res, err = connect:read_reply()
    if res then
       if res[3] then
         local t=cjson.decode(res[3])
         local ips=t.ips
         local expire=tonumber((not t.expire) and 43200 or t.expire)
		 if t.type == "add" then
		   for ip in string.gmatch(ips,"[^',']+") do
             cache:set("yh:mip:" .. ip,"1",expire)
             ngx.log(ngx.INFO,"nginx subscribe add mal ip:" .. tostring(ip) .. ":" .. tostring(expire))
           end
		 elseif t.type == "del" then 
		   for ip in string.gmatch(ips,"[^',']+") do
             cache:delete("yh:mip:" .. ip)
             ngx.log(ngx.INFO,"nginx subscribe del mal ip:" .. tostring(ip) .. ":" .. tostring(expire))
           end
		 elseif t.type == "flush" then
		    cache:flush_all()
			ngx.log(ngx.INFO,"nginx subscribe flush all mal ip")
		 end
         
       end
    elseif err ~= "timeout" then
      connect:close()
      ngx.log(ngx.ERR,"subscribe blacklist ip socket timeout") 
      return false
    end 
    if ngx.worker.exiting() then 
      connect:close()
      ngx.log(ngx.ERR,"subscribe blacklist ip ngx worker exit") 
      return false 
    end 
  end
  return false
end
--<< end: subscribe ip blacklist event
function subscribe_mal_ips_loop()
  if ngx.worker.id() ~= 0 then
    return
  end 
  local b = ture
  while true do
    local res,err=pcall(subscribe_mal_ips)
    if not res then
      ngx.log(ngx.ERR,"subscribe blacklist ip ngx err:" .. tostring(err))
    end
    -- subscribe error sleep 10 seconds and then retry 
    ngx.sleep(10)
    if ngx.worker.exiting() then 
      return 
    end 
  end 
end


-->>begin: timer at fix rate call function.
local timer_handler
timer_handler=function(premature,t,f,id)
   if id then 
     if ngx.worker.id() == id then
        local b,errinfo=pcall(f)
        if not b then
          ngx.log(ngx.ERR, "task request error:" .. tostring(errinfo))
        end
     end
   else 
    local b,errinfo=pcall(f)
    if not b then
      ngx.log(ngx.ERR, "task request error:" .. tostring(errinfo))
    end
   end
   ngx.timer.at(t,timer_handler,t,f)
end
--<<end: timer at fix rate call function.

-- subscribe mal ips task
ngx.timer.at(2,subscribe_mal_ips_loop)

timer_handler(true,20,query_rate_limit_conf,0)
timer_handler(true,25,query_limit_ip_access_conf,0)
timer_handler(true,30,query_common_conf,0)


-- every worker read global configs from share cache into local cache
function rate_limit_conf_to_worker()
    local t=lua_context.lua_conf_cache:get("api_rate_limit_conf")
    if t then
      local  r=cjson.decode(t)
      if r then 
       lua_context.configs["api_rate_limit_conf"]=r
       --ngx.log(ngx.INFO,"++++++++++++++" .. cjson.encode(r.api_rate_limit["web.passport.getUserVerifyInfo"]))
      end
    end
end


function limit_ip_access_conf_to_worker()
    local t=lua_context.lua_conf_cache:get("limit_ip_access")
    if t then
      local  r=cjson.decode(t)
      if r then
        lua_context.configs["limit_ip_access"]=r
      --ngx.log(ngx.INFO,"++++++++++++++" .. cjson.encode(lua_context.configs["limit_ip_access"]))
      end
    end
end

function query_common_conf_to_worker()
  local t=lua_context.lua_conf_cache:get("common_conf")
  if t then
    local  r=cjson.decode(t)
    if r then 
     lua_context.configs["common_conf"]=r
    end
  end
end

timer_handler(true,2,rate_limit_conf_to_worker)
timer_handler(true,2,limit_ip_access_conf_to_worker)
timer_handler(true,2,query_common_conf_to_worker)


--- broadcast set_peer_down to all workers.
--- using version to ignore repeated working
local  stream_ctx={}
function updownstream()
  local keys=upstream_cache:get_keys()
  
  for _,k in ipairs(keys) do
   if string.sub(k,1,1)=="d" then 
     
     local vKey="v" .. string.sub(k,2)
     local version=upstream_cache:get(vKey)
 
     local value=upstream_cache:get(k)
     local v=cjson.decode(value)
 
     if ( not stream_ctx[vKey] ) or stream_ctx[vKey] < version then
       local ok,err=upstream.set_peer_down(v["upstream"],v["backup"],v["id"],v["value"])  
       if not ok then
         ngx.log(ngx.ERR,"up or down stream err:",ngx.worker.id(),value,err)
       else 
          stream_ctx[vKey]=version
       end
     end
 
   end
  end
end

timer_handler(true,2,updownstream)