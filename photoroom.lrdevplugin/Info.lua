return {

  LrSdkVersion = 3.0,
  LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

  LrToolkitIdentifier = "com.github.gozala.photoroom",
  LrPluginName = LOC "$$$/PhotoRoom/PluginName=Photo Room",
  LrPluginInfoUrl = "https://github.com/Gozala/photo-room",

  LrExportServiceProvider = {
    title = "Open photo", -- this string appears as the Export destination
    file = "publish.lua", -- the service definition script builtInPresetsDir = "myPresets", -- an optional subfolder for presets
  },

  LrMetadataProvider = "metadata.lua",
  URLHandler = "uri-handler.lua",

  VERSION = { major=0, minor=0, revision=1, build=0, }
}
