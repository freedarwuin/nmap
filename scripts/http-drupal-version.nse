local http = require "http"
local nmap = require "nmap"
local shortport = require "shortport"
local stdnse = require "stdnse"
local string = require "string"

description = [[
Detects the drupal version by scraping the index page.
]]

---
--  @usage
--  nmap --script http-drupal-version <url>
--  nmap --script http-drupal-version drupal.org
--
--  @args http-drupal-version.url The url to scan.
--
--  @output
--    PORT   STATE SERVICE
--    80/tcp open  http
--    |_http-drupal-version: Version / Unable to retrieve the version
--

author = "Rewanth Cool"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"default", "discovery", "safe"}

-- Most probably checking port 443 isn't required.
-- If required enable the following command.
-- portrule = shortport.port_or_service( {80, 443}, {"http", "https"}, "tcp", "open")

portrule = shortport.port_or_service( {80}, {"http"}, "tcp", "open")

action = function(host, port)
  local resp, version, regex

  resp = http.get( host, port, "/" )
  regex = '<meta name="[G|g]enerator" content="Drupal ([0-9 .]*)'

  -- try and match version tags
  version = string.match(resp.body, regex)
  if( version ) then
    return version
  else
    return "Unable to retrieve the Drupal version."
  end
end
