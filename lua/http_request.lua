local moduleName = ...
local M = {}
_G[moduleName] = M

---------- Helper functions --------------------


--- 获取请求headers---
local function get_http_header_param(key)
  local val= ngx.req.get_headers()[key]
  if type(val) == "table" then
    for k,v in pairs(val) do
      if v then
        return  v
      end 
    end
  else
  	return val
  end
end

--- 获取请求参数---
local function get_http_req_param(req_param)  
  local args = nil
  local err = nil
  local http_req_method = ngx.var.request_method
  if "GET" == http_req_method  then
      args, err = ngx.req.get_uri_args()
  elseif "POST" == http_req_method and ngx.var.content_type and string.match(ngx.var.content_type,"application/x%-www%-form%-urlencoded.*")  then
      args, err = ngx.req.get_post_args()
  end
  --- make sure this is some params
  if not args then
    ngx.log(ngx.INFO, "Can not find any params from GET & POST REQUEST ")
    return nil
  end

  -- the value may be table, like: /test?foo=bar&bar=baz&bar=blah
  local val=args[req_param]
  if type(val) == "table" then
    for k,v in pairs(val) do
      if v then
        return  v
      end 
    end
  else
  	return val
  end
end

---------- Module functions --------------------

function M.get_ua()
  return get_http_header_param('User-Agent')
end

function M.get_req_param(param_key)
  return get_http_req_param(param_key)
end

--- 获取请求的method
function M.get_method()
    -- if miniapp, then method is miniappBrandM1 or miniappBrandM2
    local business_line = get_http_req_param("business_line")
    if (business_line == "miniappBrandM1") or  (business_line == "miniappBrandM2") then
       return business_line
    end
    -- if method existed, return method in request params
    -- or method not existed , using PATH, for example:   /operations/resource/get
   local method = get_http_req_param("method")
   if method then
      return method
   else
     return string.gsub(ngx.var.request_uri, "?.*", "")
   end

end

return M

