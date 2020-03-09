-- short url redirect
local redis=lua_context["redis_limit_ip"]
local cache=lua_context.lua_conf_cache


function redirect_url()
   
   local uri=ngx.var.request_uri

   if not uri then
     ngx.redirect("https://www.google.com")
   end
   -- acquire the short uri 
   local short_uri = string.sub(ngx.var.request_uri,2,#ngx.var.request_uri) 
   local key= "yh:short_uri:" .. short_uri
   local value = cache:get(key)  
   if not value then
     value = redis:cmd("get",key)  
     if value and value ~= ngx.null then
       cache:set(key,value,3600)  
    end
   end
   
   if value and value ~= ngx.null then
     ngx.redirect(value,301)
   else
     ngx.redirect("https://www.google.com")
   end    
end

redirect_url()
