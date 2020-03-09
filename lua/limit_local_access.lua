local modname= ...
local M={}
_G[modname]=M
package.loaded[modname]=M

-- author: chunhua.zhang
-- only allow request from local ip and nat ip
-- depends on param: [ngx.var.real_ip], which should be setted up by 'setup.lua'
local iptool=require "iptool" 
local http_request = require "http_request"

-- you may need change the local cidr which can be accessed.
local local_cidr = {
    "10.1.0.0/16",
    "192.168.0.0/16",
    "172.31.0.0/16",
    "127.0.0.1",
}

local function get_ip() 
  local realIp = ngx.var.remote_addr;
  return realIp;
end

 -- check if ip is local
 -- depends on $real_ip which setup by  setup.lua
function M:check_local_access()
    
    local ip= get_ip()

    local is_local_ip = false
    for i = 1, #local_cidr do
      local is_in_cidr = iptool:pcall_check_ip_in_ipblock(ip, local_cidr[i],false)
      if is_in_cidr then
        is_local_ip = true
        break
      end
    end
    
    return is_local_ip
end


