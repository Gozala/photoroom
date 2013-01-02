-- Lightroom SDK
local binding = import("LrBinding")
local view = import("LrView")

local auth = require("authentication")

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

return {
  exportPresetFields = {
    { key = "domain", default = "current.openphoto.me" },

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

    -- Clear login if it's a new connection.

    if not options.LR_editingExistingPublishConnection then
      options.username = nil
      options.nsid = nil
      options.auth_token = nil
    end

    -- Can't export until we've validated the login.

    options:addObserver("validAccount", function() updateCantExportBecause(options) end)
    updateCantExportBecause(options)

    -- Make sure we're logged in.

    -- require 'ServiceUser'
    -- ServiceUser.verifyLogin(options)
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
            action = function()
              options.accountStatus = LOC "$$$/PhotoRoom/AccountStatus/LoggingIn=Authorizing..."
              auth.authorize(options.domain, function(athorization)
                options.accountStatus = LOC "$$$/PhotoRoom/AccountStatus/LoggingIn=Authorized"
                options.validAccount = true
              end)
            end
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
