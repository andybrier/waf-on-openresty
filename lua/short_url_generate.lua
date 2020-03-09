local redis = lua_context["redis_limit_ip"]
local chars = {"G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"}
local cjson = require "cjson"

function generate_short_url()
         
 -- acquire full uri from request
  ngx.req.read_body()
  local args, err = ngx.req.get_post_args()
  local uri = args['uri']
  local schema = args['schema']
        
  -- calculate the short uri
  local short_uri;
  local res, err = redis:cmd("incr","yh:short_uri:incr_key")
  if not err  then
    if res > 268435453 then 
      redis:cmd("set","yh:short_uri:incr_key",1)
    end
    local key = string.format("%07X",res)
    local s = {}
    for i=1,#key do
      local c=string.sub(key,i,i)
      if c == "0" then
          table.insert(s,chars[math.random(1,#chars)])
      else
          table.insert(s,c)
      end
    end
    short_uri=string.reverse(table.concat(s))
    -- add to redis 
    local res, err = redis:cmd("set","yh:short_uri:" .. short_uri,uri) 
    if err then
      return 
    end
    -- use http or https
    local full_short_uri= (schema == 'https') and ("https://g.com/" .. short_uri) or ("http://yhurl.com/" .. short_uri )
      return full_short_uri
    end
end

local uri=generate_short_url()
local res={}
if uri then
 res["code"]=200
 res["uri"]= uri
 ngx.say(cjson.encode(res))
else
 res["code"]=500
 res["uri"]= uri 
 ngx.say(cjson.encode(res))
end 

