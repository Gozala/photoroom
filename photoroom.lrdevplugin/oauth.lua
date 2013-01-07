-- Adaptation of [LuaOAuth](https://github.com/ignacio/LuaOAuth) client
-- library to a Lightroom environment.

local md5 = import("LrMD5")
local http = import("LrHttp")
local context = import("LrFunctionContext")

local Base64 = require("base64")
local querystring = require("querystring")
local math = require("math")
local table = require("table")
local string = require("string")
local os = require("os")
local sha1 = require("sha1")
local reduce = require("reduce")

local console = require("console")

local m_valid_http_methods = {
  GET = true,
  HEAD = true,
  POST = true,
  PUT = true,
  DELETE = true
}

-- each instance has this fields
-- m_supportsAuthHeader
-- m_consumer_secret
-- m_signature_method
-- m_oauth_verifier
-- m_endpoints
-- m_oauth_token
-- m_oauth_token_secret


--
-- Joins table t1 and t2
local function merge(t1, t2)
  assert(t1)
  if not t2 then return t1 end
  for k,v in pairs(t2) do
    t1[k] = v
  end
  return t1
end

--
-- Generates a unix timestamp (epoch is 1970, etc)
local function generate_timestamp()
  return tostring(os.time())
end

--
-- Generates a nonce (number used once).
-- I'm not base64 encoding the resulting nonce because some providers rejects them (i.e. echo.lab.madgex.com)
local function generate_nonce()
  local nonce = tostring(math.random()) .. "random" .. tostring(os.time())
  return md5.digest(nonce)
end

--
-- Like URL-encoding, but following OAuth's specific semantics
local function oauth_encode(val)
  return val:gsub('[^-._~a-zA-Z0-9]', function(letter)
    return string.format("%%%02x", letter:byte()):upper()
  end)
end

--
-- Given a url endpoint, a valid Http method, and a table of key/value args, build the query string and sign it,
-- returning the oauth_signature, the query string and the Authorization header (if supported)
--
-- The args should also contain an 'oauth_token_secret' item, except for the initial token request.
-- See: http://dev.twitter.com/pages/auth#signing-requests
--
function Sign(self, httpMethod, baseUri, arguments, oauth_token_secret, authRealm)
  assert(m_valid_http_methods[httpMethod], "method '" .. httpMethod .. "' not supported")

  local consumer_secret = self.m_consumer_secret
  local token_secret = oauth_token_secret or ""

  -- oauth-encode each key and value, and get them set up for a Lua table sort.
  local keys_and_values = { }

  --print("'"..consumer_secret.."'")
  --print("'"..token_secret.."'")
  for key, val in pairs(arguments) do
    table.insert(keys_and_values, {
            key = oauth_encode(key),
            val = oauth_encode(tostring(val))
          })
  end

  -- Sort by key first, then value
  table.sort(keys_and_values, function(a,b)
            if a.key < b.key then
              return true
            elseif a.key > b.key then
              return false
            else
              return a.val < b.val
            end
          end)

  -- Now combine key and value into key=value
  local key_value_pairs = { }
  for _, rec in pairs(keys_and_values) do
    --print("'"..rec.key.."'", "'"..rec.val.."'")
    table.insert(key_value_pairs, rec.key .. "=" .. rec.val)
  end

  -- Now we have the query string we use for signing, and, after we add the signature, for the final as well.
  local query_string_except_signature = table.concat(key_value_pairs, "&")

  -- Don't need it for Twitter, but if this routine is ever adapted for
  -- general OAuth signing, we may need to massage a version of the url to
  -- remove query elements, as described in http://oauth.net/core/1.0a#rfc.section.9.1.2
  --
  -- More on signing:
  --   http://www.hueniverse.com/hueniverse/2008/10/beginners-gui-1.html
  --
  local signature_base_string = httpMethod .. '&' .. oauth_encode(baseUri) .. '&' .. oauth_encode(query_string_except_signature)
  --print( ("Signature base string: %s":format(signature_base_string) )
  local signature_key = oauth_encode(consumer_secret) .. '&' .. oauth_encode(token_secret)
  --print( ("Signature key: %s"):format(signature_key) )

  -- Now have our text and key for HMAC-SHA1 signing
  local hmac_binary = sha1.hmac_sha1_binary(signature_key, signature_base_string)

  -- Base64 encode it
  local hmac_b64 = Base64.encode(hmac_binary)

  local oauth_signature = oauth_encode(hmac_b64)

  local oauth_headers
  -- Build the 'Authorization' header if the provider supports it
  if self.m_supportsAuthHeader then
    oauth_headers = { ([[OAuth realm="%s"]]):format(authRealm or "") }
    for k,v in pairs(arguments) do
      if k:match("^oauth_") then
        table.insert(oauth_headers, k .. "=\"" .. oauth_encode(v) .. "\"")
      end
    end
    table.insert(oauth_headers, "oauth_signature=\"" .. oauth_signature .. "\"")
    oauth_headers = table.concat(oauth_headers, ", ")
  end

  return oauth_signature, query_string_except_signature .. '&oauth_signature=' .. oauth_signature, oauth_headers
end

--
-- Performs the actual http request, using LuaSocket or LuaSec (when using an https scheme)
-- @param url is the url to request
-- @param method is the http method (GET, POST, etc)
-- @param headers are the supplied http headers as a table
-- @param arguments is an optional table with whose keys and values will be encoded as "application/x-www-form-urlencoded"
--   or a string (or something that can be converted to a string). In that case, you must supply the Content-Type.
-- @param post_body is a string with all parameters (custom + oauth ones) encoded. This is used when the OAuth provider
--   does not support the 'Authorization' header.
-- @param callback is only required if running under LuaNode. It is a function to be called when the response is available.
local function PerformRequestHelper (self, url, method, headers, arguments, post_body, callback)
    -- Remove oauth_related arguments
  if type(arguments) == "table" then
    for k,v in pairs(arguments) do
      if type(k) == "string" and k:match("^oauth_") then
        arguments[k] = nil
      end
    end
    if not next(arguments) then
      arguments = nil
    end
  end

  context.postAsyncTaskWithContext("http.request", function(context)
    console.log("curl -v -H 'Authorization:" ..
                headers.Authorization ..
                "' " ..
                url .. "?" .. post_body)

    local requestHeaders = reduce(headers, function(result, value, field)
      table.insert(result, { field = field, value = value })
      return result
    end, {})

    context:addFailureHandler(function(error, message)
      console.log("FUCK")
      callback(error or message)
    end)

    local body, head

    if method == "GET" then
      body, head = http.get(url .. "?" .. post_body, requestHeaders)
    else
      body, head = http.post(url, post_body, requestHeaders, method)
    end

    local response = {
      code = head.status,
      headers = head.headers,
      body = body
    }

    console.log({
      type = "<< PerformRequestHelper",
      response = response
    })

    callback(nil, response)
  end)
end



---
-- Requests an Unauthorized Request Token (http://tools.ietf.org/html/rfc5849#section-2.1)
-- @param arguments is an optional table with whose keys and values will be encoded as "application/x-www-form-urlencoded"
--  (when doing a POST) or encoded and sent in the query string (when doing a GET).
-- @param headers is an optional table with http headers to be sent in the request
-- @param callback is only required if running under LuaNode. It is a function to be called with a table with the
--   obtained token or [false, http status code, http response headers, http status line and the response body] in case
--   of an error. The callback is mandatory when running under LuaNode.
-- @return nothing if running under LuaNode (the callback will be called instead). Else it will return a
--   table containing the returned values from the server if succesfull or throws an error otherwise.
--
function RequestToken(self, arguments, headers, callback)

  if type(arguments) == "function" then
    callback = arguments
    arguments, headers = nil, nil
  elseif type(headers) == "function" then
    callback = headers
    headers = nil
  end

  local args = {
    oauth_consumer_key = self.m_consumer_key,
    oauth_nonce = generate_nonce(),
    oauth_signature_method = self.m_signature_method,
    oauth_timestamp = generate_timestamp(),
    oauth_version = "1.0"	-- optional mi trasero!
  }
  args = merge(args, arguments)

  local endpoint = self.m_endpoints.RequestToken

  local oauth_signature, post_body, authHeader = Sign(self, endpoint.method, endpoint.url, args)

  local headers = merge({}, headers)
  if self.m_supportsAuthHeader then
    headers["Authorization"] = authHeader
  end

  local oauth_instance = self

  PerformRequest(self, endpoint.url, endpoint.method, headers, arguments, post_body,
    function(error, response)
      if (error) then
        callback(error)
      else
        local values = {}
        for key, value in string.gmatch(response.body, "([^&=]+)=([^&=]*)&?" ) do
          values[key] = querystring.urldecode(value)
        end

        oauth_instance.m_oauth_token_secret = values.oauth_token_secret
        oauth_instance.m_oauth_token = values.oauth_token

        callback(nil, values)
      end
    end)
end

--
-- Requests Authorization from the User (http://tools.ietf.org/html/rfc5849#section-2.2)
-- Builds the URL used to issue a request to the Service Provider's User Authorization URL
-- @param arguments is an optional table whose keys and values will be encoded and sent in the query string.
-- @return the fully constructed URL, with oauth_token and custom parameters encoded.
function BuildAuthorizationUrl(self, arguments)
  local args = { }
  args = merge(args, arguments)
  args.oauth_token = (arguments and arguments.oauth_token) or self.m_oauth_token or error("no oauth_token")

  -- oauth-encode each key and value
  local keys_and_values = { }
  for key, val in pairs(args) do
    table.insert(keys_and_values, {
            key = oauth_encode(key),
            val = oauth_encode(tostring(val))
          })
  end

  -- Now combine key and value into key=value
  local key_value_pairs = { }
  for _, rec in pairs(keys_and_values) do
    table.insert(key_value_pairs, rec.key .. "=" .. rec.val)
  end
  local query_string = table.concat(key_value_pairs, "&")

  local endpoint = self.m_endpoints.AuthorizeUser
  return endpoint.url .. "?" .. query_string
end

--[=[ This seems to be unnecesary
--
-- Requests Authorization from the User (6.2) http://oauth.net/core/1.0a/#auth_step2
-- Builds and issues the request
-- @param arguments is an optional table with whose keys and values will be encoded as "application/x-www-form-urlencoded"
--  (when doing a POST) or encoded and sent in the query string (when doing a GET).
-- @param headers is an optional table with http headers to be sent in the request
-- @return the http status code (a number), a table with the response headers and the response itself
function Authorize(self, arguments, headers)
  local args = {
    oauth_consumer_key = self.m_consumer_key,
    oauth_nonce = generate_nonce(),
    oauth_signature_method = self.m_signature_method,
    oauth_timestamp = generate_timestamp(),
    oauth_version = "1.0"
  }
  args = merge(args, arguments)
  args.oauth_token = (arguments and arguments.oauth_token) or self.m_oauth_token or error("no oauth_token")

  local endpoint = self.m_endpoints.AuthorizeUser

  local oauth_signature, post_body, authHeader = Sign(self, endpoint.method, endpoint.url, args)

  local headers = merge({}, headers)
  if self.m_supportsAuthHeader then
    headers["Authorization"] = authHeader
  end

  local ok, response_code, response_headers, response_status_line, response_body = PerformRequestHelper(self, url, endpoint.method, headers, arguments, post_body)

  return response_code, response_headers, response_body
end
--]=]


---
-- Exchanges a request token for an Access token (http://tools.ietf.org/html/rfc5849#section-2.3)
-- @param arguments is an optional table with whose keys and values will be encoded as "application/x-www-form-urlencoded"
--  (when doing a POST) or encoded and sent in the query string (when doing a GET).
-- @param headers is an optional table with http headers to be sent in the request
-- @param callback is only required if running under LuaNode. It is a function to be called with a table with the
--   obtained token or [false, http status code, http response headers, http status line and the response body] in case
--   of an error. The callback is mandatory when running under LuaNode.
-- @return nothing if running under LuaNode (the callback will be called instead). Else, a table containing the returned
--   values from the server if succesfull or nil plus the http status code (a number), a table with the response
--   headers, the status line and the response itself
function GetAccessToken(self, arguments, headers, callback)

  if type(arguments) == "function" then
    callback = arguments
    arguments, headers = nil, nil
  elseif type(headers) == "function" then
    callback = headers
    headers = nil
  end

  local args = {
    oauth_consumer_key = self.m_consumer_key,
    oauth_nonce = generate_nonce(),
    oauth_signature_method = self.m_signature_method,
    oauth_timestamp = generate_timestamp(),
    oauth_version = "1.0",
  }
  args = merge(args, arguments)
  args.oauth_token = (arguments and arguments.oauth_token) or self.m_oauth_token or error("no oauth_token")
  args.oauth_verifier = (arguments and arguments.oauth_verifier) or self.m_oauth_verifier -- or error("no oauth_verifier") -- twitter se banca que no venga esto, aunque el RFC dice MUST

  local endpoint = self.m_endpoints.AccessToken
  local oauth_token_secret = (arguments and arguments.oauth_token_secret) or self.m_oauth_token_secret or error("no oauth_token_secret")
  if arguments then
    arguments.oauth_token_secret = nil	-- this is never sent
  end
  args.oauth_token_secret = nil	-- this is never sent

  local oauth_signature, post_body, authHeader = Sign(self, endpoint.method, endpoint.url, args, oauth_token_secret)

  local headers = merge({}, headers)
  if self.m_supportsAuthHeader then
    headers["Authorization"] = authHeader
  end

  local oauth_instance = self

  PerformRequestHelper(self, endpoint.url, endpoint.method, headers, arguments, post_body,
    function(err, response)
      console.log({
        type = "<< GetAccessToken",
        error = err,
        response = response
      })

      if err then
        callback(err)
        return
      end

      if response.code ~= 200 then
        -- can't do much, the responses are not standard
        callback({
          status = response.code,
          headers = response.headers,
          status_line = response.status_line,
          body = response.body
        })
        return
      end

      local values = {}
      for key, value in string.gmatch(response.body, "([^&=]+)=([^&=]*)&?" ) do
        values[key] = querystring.urldecode(value)
      end

      oauth_instance.m_oauth_token_secret = values.oauth_token_secret
      oauth_instance.m_oauth_token = values.oauth_token

      callback(nil, values)
    end)
end


---
-- After retrieving an access token, this method is used to issue properly authenticated requests.
-- (see http://tools.ietf.org/html/rfc5849#section-3)
-- @param method is the http method (GET, POST, etc)
-- @param url is the url to request
-- @param arguments is an optional table whose keys and values will be encoded as "application/x-www-form-urlencoded"
--   (when doing a POST) or encoded and sent in the query string (when doing a GET).
-- @param headers is an optional table with http headers to be sent in the request
-- @param callback is only required if running under LuaNode. It is a function to be called with an (optional) error object and the result of the request.
-- @return nothing if running under Luanode (the callback will be called instead). Else, the http status code
--   (a number), a table with the response headers, the status line and the response itself.
--
function PerformRequest(self, method, url, arguments, headers, callback)
  assert(type(method) == "string", "'method' must be a string")
  method = method:upper()

  if type(arguments) == "function" then
    callback = arguments
    arguments, headers = nil, nil
  elseif type(headers) == "function" then
    callback = headers
    headers = nil
  end

  local headers, arguments, post_body = BuildRequest(self, method, url, arguments, headers)

  PerformRequestHelper(self, url, method, headers, arguments, post_body, function(error, response)

    console.log({
      type = "<< PerformRequest",
      error = error,
      response = response
    })

    if error then
      callback(error)
    elseif response.code ~= 200 then
      -- can't do much, the responses are not standard
      callback({
        message = "Status code is not OK",
        status = response.code,
        headers = response.headers,
        body = response.body
      })
    else
      callback(error, response)
    end
  end)
end


---
-- After retrieving an access token, this method is used to build properly authenticated requests, allowing the user
-- to send them with the method she seems fit.
-- (see http://tools.ietf.org/html/rfc5849#section-3)
-- @param method is the http method (GET, POST, etc)
-- @param url is the url to request
-- @param arguments is an optional table whose keys and values will be encoded as "application/x-www-form-urlencoded"
--  (when doing a POST) or encoded and sent in the query string (when doing a GET).
-- @param headers is an optional table with http headers to be sent in the request
-- @return a table with the headers, a table with the (cleaned up) arguments and the request body.
function BuildRequest(self, method, url, arguments, headers)
  assert(type(method) == "string", "'method' must be a string")
  method = method:upper()

  local args = {
    oauth_consumer_key = self.m_consumer_key,
    oauth_nonce = generate_nonce(),
    oauth_signature_method = self.m_signature_method,
    oauth_timestamp = generate_timestamp(),
    oauth_version = "1.0"
  }
  local arguments_is_table = (type(arguments) == "table")
  if arguments_is_table then
    args = merge(args, arguments)
  end
  args.oauth_token = (arguments_is_table and arguments.oauth_token) or self.m_oauth_token or error("no oauth_token")
  local oauth_token_secret = (arguments_is_table and arguments.oauth_token_secret) or self.m_oauth_token_secret or error("no oauth_token_secret")
  if arguments_is_table then
    arguments.oauth_token_secret = nil	-- this is never sent
  end
  args.oauth_token_secret = nil	-- this is never sent

  local oauth_signature, post_body, authHeader = Sign(self, method, url, args, oauth_token_secret)
  local headers = merge({}, headers)
  if self.m_supportsAuthHeader then
    headers["Authorization"] = authHeader
  end

  -- Remove oauth_related arguments
  if type(arguments) == "table" then
    for k,v in pairs(arguments) do
      if type(k) == "string" and k:match("^oauth_") then
        arguments[k] = nil
      end
    end
    if not next(arguments) then
      arguments = nil
    end
  end

  return headers, arguments, post_body
end

--
-- Sets / gets oauth_token
function SetToken(self, value)
  self.m_oauth_token = value
end
function GetToken(self)
  return self.m_oauth_token
end

--
-- Sets / gets oauth_token_secret
function SetTokenSecret(self, value)
  self.m_oauth_token_secret = value
end
function GetTokenSecret(self)
  return self.m_oauth_token_secret
end

--
-- Sets / gets oauth_verifier
function SetVerifier(self, value)
  self.m_oauth_verifier = value
end
function GetVerifier(self)
  return self.m_oauth_verifier
end

--
-- Builds a new OAuth client instance
-- @param consumer_key is the public key
-- @param consumer_secret is the private key
-- @param endpoints is a table containing the URLs where the Service Provider exposes its endpoints
--   each endpoint is either a string (its url, the method is POST by default) or a table, with the url in the array part and the method
--   in the 'method' field.
-- @param params is an optional table with additional parameters:
--    @field SignatureMethod indicates the signature method used by the server (PLAINTEXT, RSA-SHA1, HMAC-SHA1 (default) )
--    @field UseAuthHeaders indicates if the server supports oauth_xxx parameters to be sent in the 'Authorization' HTTP header (true by default)
-- @return the http status code (a number), a table with the response headers and the response itself
function new(consumer_key, consumer_secret, endpoints, params)
  params = params or {}
  local newInstance = {
    m_consumer_key = consumer_key,
    m_consumer_secret = consumer_secret,
    m_endpoints = {},
    m_signature_method = params.SignatureMethod or "HMAC-SHA1",
    m_supportsAuthHeader = true,
    m_oauth_token = params.OAuthToken,
    m_oauth_token_secret = params.OAuthTokenSecret,
    m_oauth_verifier = params.OAuthVerifier
  }

  if type(params.UseAuthHeaders) == "boolean" then
    newInstance.m_supportsAuthHeader = params.UseAuthHeaders
  end

  for k,v in pairs(endpoints or {}) do
    if type(v) == "table" then
      newInstance.m_endpoints[k] = { url = v[1], method = string.upper(v.method) }
    else
      newInstance.m_endpoints[k] = { url = v, method = "POST" }
    end
  end

  return newInstance
end

return {
  new = new,
  request = PerformRequest,
  accessToken = GetAccessToken,
  requestToken = RequestToken
}
