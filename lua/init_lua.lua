local lrucache = require "resty.lrucache"

-- init redis configuration

local ip_limit_redis_config={host="redis.server",port="6379",auth="password",timeout=2000,max_idle_timeout=60000,pool_size=100}


local redis_util=require("redisutil")

local redis_limit_ip=redis_util:new(ip_limit_redis_config)

-- global variable
lua_context={}

lua_context["redis_limit_ip"]=redis_limit_ip


lua_context.mal_ip_cache=ngx.shared.malips
lua_context.lua_conf_cache=ngx.shared.ngxconf

lua_context.configs={}

ngx.shared.upstream:flush_all()
ngx.shared.upstream:flush_expired()
