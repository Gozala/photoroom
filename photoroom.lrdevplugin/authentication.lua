local http = import("LrHttp")
local context = import("LrFunctionContext")
local dialogs = import("LrDialogs")
local prefs = import("LrPrefs").prefsForPlugin()

local handler = require("uri-handler")
local querystring = require("querystring")
local info = require("Info")

local postAsyncTaskWithContext = context.postAsyncTaskWithContext
local console = require("console")

return {
  authorize = function(domain, callback)
    console.log("start athorization")
    postAsyncTaskWithContext("Open Photo authorization", function(context)
      dialogs.attachErrorDialogToFunctionContext(context)

      local confirmation = dialogs.confirm(
        LOC "$$$/PhotoRoom/AuthRequestDialog/Message=Lightroom needs your permission to upload images to Open Photo.",
        LOC "$$$/PhotoRoom/AuthRequestDialog/HelpText=If you click Authorize, you will be taken to a web page in your web browser where you can log in and authorize Lightroom.",
        LOC "$$$/PhotoRoom/AuthRequestDialog/AuthButtonText=Authorize",
        LOC "$$$/LrDialogs/Cancel=Cancel" )

      if confirmation == "cancel" then
        return
      end

      local onAuth = function()
        console.log("pref change")
        prefs:removeObserver("auth", onAuth)
        callback(prefs.auth)
      end
      prefs:addObserver("auth", onAuth)

      local callback = "lightroom://" .. info.LrToolkitIdentifier .. "/"

      http.openUrlInBrowser("http://" ..
                            domain ..
                            "/v1/oauth/authorize?oauth_callback=" ..
                            querystring.urlencode(callback) ..
                            "&name=" ..
                            querystring.urlencode(info.LrPluginName))

    end)
  end
}
