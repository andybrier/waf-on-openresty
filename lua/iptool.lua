local modname= ...
local M={}
_G[modname]=M
package.loaded[modname]=M

local h2b = {
    ["0"] = "0000",
    ["1"] = "0001",
    ["2"] = "0010",
    ["3"] = "0011",
    ["4"] = "0100",
    ["5"] = "0101",
    ["6"] = "0110",
    ["7"] = "0111",
    ["8"] = "1000",
    ["9"] = "1001",
    ["A"] = "1010",
    ["B"] = "1011",
    ["C"] = "1100",
    ["D"] = "1101",
    ["E"] = "1110",
    ["F"] = "1111"
}

function M:split_ip(ip)
  if not ip or type(ip) ~="string" then
    return nil
  end

  local t={}

  for w in string.gmatch(ip,"([^'.']+)") do
      table.insert(t,tonumber(w))
  end
  return t
end


function M:ip_to_binary_str(ip)
  if not ip or type(ip)~="string" then
	return nil
  end
  local ip_table=self:split_ip(ip)
  if not ip_table then
	return nil
  end

  local ip_table_length=#ip_table
  if ip_table_length~=4 then
    return nil
  end

   local ip_str=""
   for i=1,ip_table_length do
	 local x=string.upper(string.format("%x",ip_table[i]))
	 local len=string.len(x)
	 if len==1 then
	   x="0" .. x
	 elseif len>2 then
	   return nil
	 end
	 local f=string.sub(x,1,1)
     local s=string.sub(x,2,2)
	 ip_str=ip_str .. h2b[f] .. h2b[s]
   end
   return ip_str
end


function M:check_ip_in_ipblock(ip,ipblock)
  if (not ip) or (not ipblock) then
    return false
  end
  local f,t=string.find(ipblock,"/")
  if f then
     local ipblock_head=string.sub(ipblock,0,f-1)
	 local ipblock_tail=string.sub(ipblock,f+1)
	 local ipblock_head_b=self:ip_to_binary_str(ipblock_head)
	 local ip_b=self:ip_to_binary_str(ip)
	 local mask_len=tonumber(ipblock_tail)
	 if (not mask_len)or mask_len> 32 or mask_len<0 or (not ip_b) or (not ipblock_head_b) then
	  return false
	 end
	 if string.sub(ipblock_head_b,0,mask_len) == string.sub(ip_b,0,mask_len) then
	   return true
	 end
  else
    if ipblock==ip then
	  return true
	end
  end
 return false
end

function M:pcall_check_ip_in_ipblock(ip,ipblock,default)
  local flag,res=pcall(self.check_ip_in_ipblock,self,ip,ipblock)
  if flag then
    return res
  end
 
  return default
end 

