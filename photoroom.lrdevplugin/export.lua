-- Lightroom SDK
local binding = import("LrBinding")
local view = import("LrView")
local dialogs = import("LrDialogs")

local prefs = import("LrPrefs").prefsForPlugin()

local auth = require("authentication")
local OAuth = require("oauth")
local partial = require("partial")

local console = require("console")

local context = import("LrFunctionContext")
callWithContext = context.callWithContext

-- Common shortcuts
local bind = view.bind
local share = view.share

local function updateCantExportBecause(propertyTable)
  if not propertyTable.validAccount then
    propertyTable.LR_cantExportBecause = LOC "$$$/PhotoRoom/ExportDialog/NoLogin=You haven't logged in to OpenPhoto yet."
    return
  end

  propertyTable.LR_cantExportBecause = nil
end

local displayNameForTitleChoice = {
  filename = LOC "$$$/PhotoRoom/ExportDialog/Title/Filename=Filename",
  title = LOC "$$$/PhotoRoom/ExportDialog/Title/Title=IPTC Title",
  empty = LOC "$$$/PhotoRoom/ExportDialog/Title/Empty=Leave Blank",
}

function makeClient(options)
  return OAuth.new(options.auth.oauth_consumer_key,
                   options.auth.oauth_consumer_secret, {
    RequestToken = "http://" .. options.domain .. "/v1/oauth/token/request",
    AccessToken = "http://" .. options.domain .. "/v1/oauth/token/access"
  },
  {
    OAuthToken = options.auth.oauth_token,
    OAuthTokenSecret = options.auth.oauth_token_secret,
    OAuthVerifier = options.auth.oauth_verifier
  })
end

function authorizationFailed(options)
  options.accountStatus = LOC "$$$/PhotoRoom/AccountStatus/LoggingIn=Not authorized"
  options.LR_cantExportBecause = LOC "$$$/PhotoRoom/ExportDialog/NoLogin=Failed to login to OpenPhoto."
end

function authorize(options)
  console.log("authorizing...")

  options.auth = nil
  options.isAuthorized = false

  options.accountStatus = LOC "$$$/PhotoRoom/AccountStatus/LoggingIn=Authorizing..."
  local callback = partial(authorized, options)
  auth.authorize(options.domain, callback)
end

function authorized(options, authorization)
  console.log("authorized...")
  -- Function is invoked once authorization flow has being complete.

  options.auth = authorization
  local client = makeClient(options)
  OAuth.accessToken(client, function(error, response)
    console.log({
      type = "accessToken",
      error = error,
      response = response
    })

    if error then
      authorizationFailed(options)
    else
      options.isAuthorized = true
      options.accountStatus = LOC "$$$/PhotoRoom/AccountStatus/LoggingIn=Authorized"
      validate(options)
    end
  end)
end

function validate(options)
  console.log("validating...")

  local client = makeClient(options)
  OAuth.request(client, "GET", "http://" .. options.domain .. "/hello.json", {
    auth = true
  }, partial(validated, options))
end

function validated(...) --options, error, response)
  local result = {...}
  local options, error, response = ...

  console.log({
    type = "validated",
    count = #result,
    error = error,
    response = response
  })

  if error then
    console.log(error)
    authorizationFailed(options)
  else
    options.validAccount = true
  end
end

return {
  exportPresetFields = {
    { key = "domain", default = "current.openphoto.me" },
    { key = "isAuthorized", default = false },
    { key = "auth", default = nil },

    { key = "loginButtonTitle", default = "Authorize" },
    { key = 'accountStatus', default = "Not authorized" },

    { key = 'privacy', default = 'public' },
    { key = 'privacy_family', default = false },
    { key = 'privacy_friends', default = false },

    { key = 'safety', default = 'safe' },
    { key = 'hideFromPublic', default = false },
    { key = 'type', default = 'photo' },
    { key = 'addToPhotoset', default = false },
    { key = 'photoset', default = '' },

    { key = 'titleFirstChoice', default = 'title' },
    { key = 'titleSecondChoice', default = 'filename' },
    { key = 'titleRepublishBehavior', default = 'replace' },
  },

  -- Hide photoroom from exports dialog and hide `video` panel since
  -- video is not supported.
  hideSections = { 'exportLocation', 'video' },
  -- Display photoroom in a publish dialog only.
  supportsIncrementalPublish = 'only',

  -- Allow all possible file formats
  allowFileFormats = nil,
  -- Allow all possible color spaces
  allowColorSpaces = nil,

  -- Open Photo does not supports video.
  canExportVideo = false,

  -- Method called when user selects plugin in the "Publishing Manager".
  startDialog = function(options)

    options:addObserver("validAccount",
                         partial(updateCantExportBecause, options))
    updateCantExportBecause(options)

    if options.isAuthorized then
      validate(options)
    end
  end,

  -- Method is called when user selects plugin in the "Publishing Manager".
  -- It can create new sections that appear above all of the built-in sections
  -- in the panel (except for the Publish Service section in the Publish
  -- dialog, which always appears at the very top).
  -- See: /Lightroom SDK 4/API Reference/modules/SDK - Export service provider.html#exportServiceProvider.sectionsForTopOfDialog
  sectionsForTopOfDialog = function(view, options)
    return {
      {
        title = LOC "$$$/PhotoRoom/ExportDialog/Account=Open Photo Account",

        synopsis = bind("accountStatus"),

        view:row({
          view:static_text({
            title = bind("accountStatus"),
            fill_horizontal = 1,
            alignment = "center"
          }),

          view:push_button({
            title = bind("loginButtonTitle"),
            action = partial(authorize, options)
          })
        })
      },

      {
        title = LOC("$$$/PhotoRoom/ExportDialog/Title=Use your own domain"),

        view:row({
          view:static_text({
            title = LOC "$$$/PhotoRoom/ExportDialog/Login/URLTitle=Your own OpenPhoto Server:"
          }),

          view:edit_field({
            value = bind "domain",
            fill_horizontal = 1
            -- TODO: implement url validation
          })
        })
      },

      {
        title = LOC("$$$/PhotoRoom/ExportDialog/Title=Open Photo Title"),

        synopsis = function(props)
          if props.titleFirstChoice == 'title' then
            return LOC("$$$/PhotoRoom/ExportDialog/Synopsis/TitleWithFallback=IPTC Title or ^1", displayNameForTitleChoice[props.titleSecondChoice])
          else
            return props.titleFirstChoice and displayNameForTitleChoice[props.titleFirstChoice] or ''
          end
        end,

        view:column({
          spacing = view:control_spacing(),

          view:row({
            spacing = view:label_spacing(),

            view:static_text({
              title = LOC "$$$/PhotoRoom/ExportDialog/ChooseTitleBy=Set Open Photo Title Using:",
              alignment = 'right',
              width = share 'photoroomTitleSectionLabel',
            }),

            view:popup_menu({
              value = bind 'titleFirstChoice',
              width = share 'photoroomTitleLeftPopup',
              items = {
                { value = 'filename', title = displayNameForTitleChoice.filename },
                { value = 'title', title = displayNameForTitleChoice.title },
                { value = 'empty', title = displayNameForTitleChoice.empty }
              }
            }),

            view:spacer({ width = 20 }),

            view:static_text({
              title = LOC "$$$/PhotoRoom/ExportDialog/ChooseTitleBySecondChoice=If Empty, Use:",
              enabled = binding.keyEquals('titleFirstChoice', 'title', options),
            }),

            view:popup_menu({
              value = bind 'titleSecondChoice',
              enabled = binding.keyEquals('titleFirstChoice', 'title', options),
              items = {
                { value = 'filename', title = displayNameForTitleChoice.filename },
                { value = 'empty', title = displayNameForTitleChoice.empty },
              },
            }),
          }),

          view:row({
            spacing = view:label_spacing(),

            view:static_text({
              title = LOC "$$$/PhotoRoom/ExportDialog/OnUpdate=When Updating Photos:",
              alignment = 'right',
              width = share 'photoroomTitleSectionLabel',
            }),

            view:popup_menu({
              value = bind 'titleRepublishBehavior',
              width = share 'photoroomTitleLeftPopup',
              items = {
                { value = 'replace', title = LOC "$$$/PhotoRoom/ExportDialog/ReplaceExistingTitle=Replace Existing Title" },
                { value = 'leaveAsIs', title = LOC "$$$/PhotoRoom/ExportDialog/LeaveAsIs=Leave Existing Title" }
              }
            }),
          }),
        }),
      }
    }
  end,

  processRenderedPhotos = function(functionContext, exportContext)
  end
}
