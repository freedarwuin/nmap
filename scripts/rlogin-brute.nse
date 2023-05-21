local brute = require "brute"
local creds = require "creds"
local math = require "math"
local nmap = require "nmap"
local shortport = require "shortport"
local stdnse = require "stdnse"

description=[[
Performs brute force password auditing against the classic UNIX rlogin (remote
login) service.  This script must be run in privileged mode on UNIX because it
must bind to a low source port number.
]]

---
-- @usage
-- nmap -p 513 --script rlogin-brute <ip>
--
-- @output
-- PORT    STATE SERVICE
-- 513/tcp open  login
-- | rlogin-brute:
-- |   Accounts
-- |     nmap:test - Valid credentials
-- |   Statistics
-- |_    Performed 4 guesses in 5 seconds, average tps: 0
--
-- @args rlogin-brute.timeout  socket timeout for connecting to rlogin (default 10s)

-- Version 0.1
-- Created 11/02/2011 - v0.1 - created by Patrik Karlsson <patrik@cqure.net>


author = "Patrik Karlsson"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"brute", "intrusive"}

portrule = shortport.port_or_service(513, "login", "tcp")

-- The rlogin Driver, check the brute.lua documentation for more details
Driver = {

  -- creates a new Driver instance
  -- @param host table as received by the action function
  -- @param port table as received by the action function
  -- @return o instance of Driver
  new = function(self, host, port, options)
    local o = { host = host, port = port, timeout = options.timeout }
    setmetatable(o, self)
    self.__index = self
    return o
  end,

  -- connects to the rlogin service
  -- it sets the source port to a random value between 512 and 1023
  connect = function(self)

    local status

    self.socket = brute.new_socket()
    -- apparently wee need a source port below 1024
    -- this approach is not very elegant as it causes address already in
    -- use errors when the same src port is hit in a short time frame.
    -- hopefully the retry count should take care of this as a retry
    -- should choose a new random port as source.
    for i = 1, 10, 1 do
      local resvport = math.random(512, 1023)
      self.socket:set_timeout(self.timeout)
      status, err = self.socket:bind(nil, resvport)
        if status then
          status, err = self.socket:connect(host, port)
          if status or err == "TIMEOUT" then break end
          self.socket:close()
        end
      end

    if ( status ) then
      local lport, _
      status, _, lport = self.socket:get_info()
      if (not(status) ) then
        return false, "failed to retrieve socket status"
      end
    else
      self.socket:close()
    end
    if ( not(status) ) then
      stdnse.debug3("ERROR: failed to connect to server")
    end
    return status
  end,

  login = function(self, username, password)
    local data = ("\0%s\0%s\0vt100/9600\0"):format(username, username)
    local status, err = self.socket:send(data)

    status, data = self.socket:receive()
    if (not(status)) then
      local err = brute.Error:new("Failed to read response from server")
      err:setRetry( true )
      return false, err
    end
    if ( data ~= "\0" ) then
      stdnse.debug2("ERROR: Expected null byte")
      local err = brute.Error:new( "Expected null byte" )
      err:setRetry( true )
      return false, err
    end

    status, data = self.socket:receive()
    if (not(status)) then
      local err = brute.Error:new("Failed to read response from server")
      err:setRetry( true )
      return false, err
    end
    if ( data ~= "Password: " ) then
      stdnse.debug2("ERROR: Expected password prompt")
      local err = brute.Error:new( "Expected password prompt" )
      err:setRetry( true )
      return false, err
    end

    status, err = self.socket:send(password .. "\r")
    status, data = self.socket:receive()
    if (not(status)) then
      local err = brute.Error:new("Failed to read response from server")
      err:setRetry( true )
      return false, err
    end

    status, data = self.socket:receive()
    if (not(status)) then
      local err = brute.Error:new("Failed to read response from server")
      err:setRetry( true )
      return false, err
    end

    if ( data:match("[Pp]assword") or data:match("[Ii]ncorrect") ) then
      return false, brute.Error:new( "Incorrect password" )
    end

    return true, creds.Account:new(username, password, creds.State.VALID)
  end,

  disconnect = function(self)
    return self.socket:close()
  end,
}

local arg_timeout = stdnse.parse_timespec(stdnse.get_script_args(SCRIPT_NAME .. ".timeout"))
arg_timeout = (arg_timeout or 10) * 1000

action = function(host, port)

  if ( not(nmap.is_privileged()) ) then
    stdnse.verbose1("Script must be run in privileged mode. Skipping.")
    return stdnse.format_output(false, "rlogin-brute needs Nmap to be run in privileged mode")
  end

  local options = {
    timeout = arg_timeout
  }

  local engine = brute.Engine:new(Driver, host, port, options)
  engine.options.script_name = SCRIPT_NAME
  local status, result = engine:start()
  return result
end
