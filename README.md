# waf-on-openresty
web application firewall based on openresty


# lua files
 - tools 
   - `ip_util.lua`
   - `iptool.lua`
   - `redisutil.lua`
   - `http_request.lua`

- functions
  - `short url`: short url service based on redis 
     - `short_url_generate.lua`
     - `short_url_redirectl.lua`
  - `customer nginx log files`:  add customer params to log files
    -  `set_log_params.lua`
  - `dynamic upstream management`: add or remove an upstream server by http request
    - `upstream.lua`
  - `limit local access`:  limit request must come from local ip
    - `limit_local_access.lua`
  - `request limits`:  limit request by method or ip .
    - `init_lua.lua`
    - `init_config_worker.lua`
    - `limit_api_flow.lua`

  - `redirct request by uid`
    - `switch_controller.lua`
    - `redirect.lua`



# functions

## request limits

### cofiguration

```yaml

lua_golbal_switch: true

# switch  rate limit ,true:open ,false:close
open_limit_flow: true

# default rate limit value,rate for two seconds
default_rate_limit: 200

# frist variable: rate in  two seconds ,second variable: error code, third variable:error message
api_rate_limit:
    - app.Shopping.submit: "100,9999992,Please wait later"
    - app.Buynow.submit: "100,9999992, Please try later"

#switch true:open,false:close
is_open: true
# white ip list use ip or ip and subnet mask,eg."172.16.6.230,172.16.6.230/16".
white_ips: 
    - "172.31.0.0/16"
    - "10.66.0.0/16"

# requests for degraded methods will get http 200 response from nginx directly without passing the request to backend servers.
degrade_methods:
 - "method_need_be_degrade"

```

### nginx config

```bash

http{

 server server1{
   access_by_lua_file:  'conf/lua/limit_api_flow.lua';

     location / {
        rewrite_by_lua_file conf/redirect.lua;
    }

      location  /u1{
        internal;
        proxy_redirect off;
        proxy_pass  http://u1/;
      }

      location  /u2{
        internal;
        proxy_redirect off;
        proxy_pass  http://u2/;
      }
 }

}

```

## redirect request by uid

nginx.conf

```bash

http{

 server server1{
    
     location / {
        rewrite_by_lua_file conf/redirect.lua;
    }

      location  /u1{
        internal;
        proxy_redirect off;
        proxy_pass  http://u1/;
      }

      location  /u2{
        internal;
        proxy_redirect off;
        proxy_pass  http://u2/;
      }
 }

}
```

## limit local access

```bash

http{
    server {
        access_by_lua '
        local local_limit =  require "limit_local_access"
        local  is_local = local_limit:check_local_access()
        
            if not is_local then
                ngx.exit(403)
            end
        ';

        location / {
            return 200;
        }
    }
}

```

## dynamic upstream management

nginx.conf

```bash

http{
 
  upstream demo{
      server 1.2.3.4;
      server 1.2.3.5;
  }

  server {
      server_name  upstream_change.domain;
      location = /upstreams {
       content_by_lua_file  "conf/lua/upstream.lua";
      }
  }

}

```

How to use ?
 -  Find all upstreams: `http://upstream_change.domain/upstream/method=list&upstream=demo`
 - Up or down a upstream's server:  `http://upstream_change.domain/upstreams?method=down&upstream=demo&id=1`



## customer nginx log files

`nginx.conf`

```bash
http
{
    #custom log format
    log_format info '$remote_addr|$http_x_forwarded_for|[$time_local]|$http_host|$request|''$status|$body_bytes_sent|$request_time|$upstream_response_time|$request_api_method|$request_uid|$request_udid';

  server {
    # the customer params
	set $request_api_method "-";
    set $request_udid "-";
    set $request_uid "-";

    # set params by lua file
    log_by_lua_file  conf/lua/set_log_params.lua;
  }
}
```

## short url 

```bash
## generate short url and redirect short url 
## you need to change g.com to your domain.
server {
	listen       80 ;
	server_name   g.com ; 
    
    #generate
    location = /gs {
        include ./local.access.conf;
        
	    default_type application/json;
        content_by_lua_file conf/lua/short_url_generate.lua;
    } 
    #redirect
    location / {
        content_by_lua_file conf/lua/short_url_redirect.lua;
    }
}

```

