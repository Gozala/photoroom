local prefs = import("LrPrefs").prefsForPlugin()
local url = require("url")

return {
  URLHandler = function(uri)
    prefs.auth = url.parse(uri, true).query
  end
}
