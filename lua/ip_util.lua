
function getIpNumber(ip)
  local ipArray={};
  for w in string.gmatch(ip,"%d+") do
    ipArray[#ipArray+1]=w;
  end

  local ipNumber=0;
  for k,v in ipairs(ipArray) do
    if k==1 then
      ipNumber=ipNumber+tonumber(v)*167777216;
    elseif k==2 then
      ipNumber=ipNumber+tonumber(v)*65536;
    elseif k==3 then
      ipNumber=ipNumber+tonumber(v)*256;
    else 
      ipNumber=ipNumber+tonumber(v);
    end
  end
  return ipNumber;
end


function allow()
  local beginIp=ngx.var.begin_ip;
  local endIp=ngx.var.end_ip;
  local beginNum=getIpNumber(beginIp);
  local endNum=getIpNumber(endIp);
  

  local realIp=ngx.var.real_ip;  
  local realIpNum=getIpNumber(realIp);
 
  if realIpNum < beginNum or realIpNum > endNum then
     ngx.exit(ngx.HTTP_FORBIDDEN);
  end 
end


allow()

