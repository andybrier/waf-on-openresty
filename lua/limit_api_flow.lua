require "resty.core"

local cjson = require "cjson"
local http_request = require "http_request"
local iptool=require "iptool" 
local limit_local = require "limit_local_access"

local default_err_code=9999991
local default_err_msg="Plase try later!"
local default_max_qps=100
-- the minimal qps for per ip-method  per 2 seconds
local default_minimal_ip_method_qps=40

  -- read config
local common_config=lua_context.configs["common_conf"]
local limit_config=lua_context.configs["api_rate_limit_conf"]
local limit_ip_config=lua_context.configs["limit_ip_access"]
  
--- do limit using local cache
function limit(limit_key,max_limit,seconds)
  if not limit_key or not max_limit then
    return true
  end
  if not seconds then
    seconds=2   
  end
  
  lua_context.lua_conf_cache:safe_add(limit_key,0,seconds) 
  local limit,err=lua_context.lua_conf_cache:incr(limit_key,1)

  if limit then
    if tonumber(limit)>max_limit then
      ngx.log(ngx.ERR,"[REQUEST LIMITED] " , string.format("Method: %s, currentQPS:%d, maxQPS: %d", limit_key, limit, max_limit))
      return false
    else
      return true
    end
  end
  return true
end 
 
---- degrade 
function do_degrade()
  local method = http_request.get_method()    
  
  if  limit_ip_config and  limit_ip_config.degrades and limit_ip_config.degrades[method] then   
               --- ngx.log(ngx.ERR, "[Degraded]: ", method)       
                local err_code = limit_ip_config.degrades[method]     
                local err_msg = default_err_msg 
                ngx.header["Content-Type"]="application/json;charset=utf-8"
                local msg='{"code":' .. err_code .. ',"message":"'.. err_msg .. '"}'
                ngx.say(msg)
                ngx.exit(ngx.HTTP_OK)
  end
end


 

-------- function: doing rate limit by key[interface]-----
function rate_limit()

  if (not common_config) or (not limit_config) then
    return
  end 
  if not common_config.lua_golbal_switch then
     return 
  end

  -- get method
  local req_uri_method = http_request.get_method() 
  if (not limit_config.is_open) or (not req_uri_method) then
    return
  end
  
  -- get max QPS from config by method
  local api_rate_limit=limit_config.api_rate_limit
  local max_per_sencond=limit_config.default_rate_limit
  if api_rate_limit[req_uri_method] and api_rate_limit[req_uri_method][1] then
    max_per_sencond=api_rate_limit[req_uri_method][1]
  end
  if not max_per_sencond then
    max_per_sencond=default_max_qps
  end

  -- get error code & error message from config by method
  local err_code=default_err_code
  if api_rate_limit[req_uri_method] and api_rate_limit[req_uri_method][2] then
    err_code=api_rate_limit[req_uri_method][2]
  end
  local err_msg=default_err_msg
  if api_rate_limit[req_uri_method] and api_rate_limit[req_uri_method][3] then
    err_msg=api_rate_limit[req_uri_method][3]
  end
  
  -- do limit by method
  local flag= limit("yh:nginx:limitflow:" .. req_uri_method, max_per_sencond)
  if not flag then
    ngx.header["Content-Type"]="application/json;charset=utf-8"
    local msg='{"code":' .. err_code .. ',"message":"'.. err_msg .. '"}'
    ngx.say(msg)
    ngx.exit(ngx.HTTP_OK)
  end

  -- do limit by ip+method, max qps is [max_per_sencond / 10]
  local ip = ngx.var.real_ip
  if not ip then 
   return
  end
  local key = ip .. ":" .. req_uri_method
  local max_qps_ip = max_per_sencond / 10 
  if max_qps_ip <= default_minimal_ip_method_qps then
    max_qps_ip = default_minimal_ip_method_qps
  end 
  local ret = limit("yh:ngx:limitIP:" .. key, max_qps_ip)
  if not ret then
    ngx.header["Content-Type"]="application/json;charset=utf-8"
    local rsp_body = '{"code":' .. err_code .. ',"message":"'.. err_msg .. '"}'
    ngx.say(rsp_body)
    ngx.exit(ngx.HTTP_OK)
  end



end

  --check is in white ip list
function is_white()


  if  limit_ip_config then
    local white_ips_length=#limit_ip_config.white_ips
    if white_ips_length >0 then
      for i=1,white_ips_length do
        local is_in_white_ips=iptool:pcall_check_ip_in_ipblock(ngx.var.real_ip,limit_ip_config.white_ips[i],false)
        if is_in_white_ips then
          return true
        end
      end
    end
  end
  return false
end

----- check weather ip is in black list
--- be careful when change response(body & header). APP need those to pop up verify toast
function check_malIp()

   -- we must ignore mthod : whilte
   local method = http_request.get_method() 

  local cache=lua_context.mal_ip_cache
  local ip=ngx.var.real_ip
  local exist = cache:get("yh:mip:" .. ip)
  
  if exist then
    ngx.log(ngx.ERR, "[IP BLOCKED]:" .. ip )

    ngx.header["x-yoho-malicode"]="10011"
    local rsp ='{"code": 10011, "message": ""}'
    ngx.say(rsp)
    ngx.exit(ngx.HTTP_OK)
  end 
end
---------end check_malIp()-----------

 
 

 
---- function read request body
function init_read_body()
  if ngx.var.request_method=="POST"  and  ngx.var.content_type and string.match(ngx.var.content_type,"application/x%-www%-form%-urlencoded.*") then
    ngx.req.read_body()
  end
end

function helper_table_contains(t, value)
  if not t or not value or value == ''  then
    return false
  end

  for i, v in ipairs(t) do
     if v == value then return true end
  end
  return false
 end

 

--------------------- main -------------
function main()

  init_read_body()


  -- check white ip
  local ret = false
  status, ret = pcall(is_white);
  if not status then
    ngx.log(ngx.ERR, "call method [is_white] failed.")
  end
  if ret then
    return
  end
 
  -- check malIP and limit 
  status, errMsg =  pcall(check_malIp)
  if not status then
    ngx.log(ngx.ERR, "call method [check_malIp] failed.", errMsg)
  end

  status, errMsg = pcall(rate_limit)
  if not status then
    ngx.log(ngx.ERR, "call method [rate_limit] failed.", errMsg)
  end

end

----- running ---- 
main()

