local http_request = require "http_request"
local switch_controller = require "switch_controller"
local iptool=require "iptool" 

 
function do_direct(redirectPath)
        local uri = ngx.var.uri 
        if nil == ngx.req.get_uri_args() then
            return ngx.exec(redirectPath ..uri);
        else
            return ngx.exec(redirectPath ..uri, ngx.req.get_uri_args());
        end
end
 

---- function read request body
function init_read_body()
        if ngx.var.request_method=="POST"  and  ngx.var.content_type and string.match(ngx.var.content_type,"application/x%-www%-form%-urlencoded.*") then
          ngx.req.read_body()
        end
end


function get_redirect_url()
        local redirectPath = "/u1" 
        local grayPath = "/u2"
        
        -- get uid
        local uid = 0
        local str_uid = http_request.get_req_param("uid") 
        if str_uid and str_uid ~= '' then
            uid = tonumber(str_uid)
        end
       
        --- hash percentage
        local percentage = switch_controller.get_percentage()
        if percentage >= 1 then
             local hash =  uid % 100
             if uid > 0 and hash <= percentage then
                return grayPath
             end
        end
        return redirectPath
end

---- main
function main()
  init_read_body()
   local status, ret = pcall(get_redirect_url)
   if not status then
        ngx.log(ngx.ERR, "call method [get_redirect_url] failed.", ret)
        ret = "/u1" 
   end
   do_direct(ret)
end

------ run ------- 
main()