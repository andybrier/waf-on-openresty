local http_request = require "http_request"

--- setup variable: 
-- 1. ngx.var.request_api_method
-- 2. ngx.var.request_udid
-- 3. ngx.var.request_uid
ngx.var.request_api_method= http_request.get_method()
ngx.var.request_udid = http_request.get_req_param("udid")
ngx.var.request_uid = http_request.get_req_param("uid")