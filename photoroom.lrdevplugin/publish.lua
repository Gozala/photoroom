local LrDialogs = import("LrDialogs")

local export = require("export")
local extend = require("extend")

return extend(export, {
  small_icon = "logo.png",
  publish_fallbackNameBinding = "fullname",
  titleForPublishedCollection = LOC "$$$/PhotoRoom/TitleForPublishedCollection=Album",
  titleForPublishedCollection_standalone = LOC "$$$/PhotoRoom/TitleForPublishedCollection/Standalone=Album",
  titleForPublishedCollectionSet = LOC "$$$/PhotoRoom/TitleForPublishedCollectionSet=Album",
  titleForPublishedCollectionSet_standalone = LOC "$$$/PhotoRoom/TitleForPublishedCollectionSet/Standalone=Album",
  titleForPublishedSmartCollection = LOC "$$$/PhotoRoom/TitleForPublishedSmartCollection=Smart Album",
  titleForPublishedSmartCollection_standalone = LOC "$$$/PhotoRoom/TitleForPublishedSmartCollection/Standalone=Smart Album",

  titleForGoToPublishedCollection = LOC "$$$/PhotoRoom/TitleForGoToPublishedCollection=Show in OpenPhoto",
  titleForGoToPublishedPhoto = LOC "$$$/PhotoRoom/TitleForGoToPublishedCollection=Show in OpenPhoto",
  titleForPhotoRating = LOC "$$$/PhotoRoom/TitleForPhotoRating=Favorites",


  supportsCustomSortOrder = true,

  getCollectionBehaviorInfo = function(publishSettings)
    return {
      defaultCollectionName = LOC "$$$/PhotoRoom/DefaultCollectionName/Photostream=Gallery",
      defaultCollectionCanBeDeleted = false,
      canAddCollection = true,
      maxCollectionSetDepth = 0
    }
  end,

  deletePhotosFromPublishedCollection = function(publishSettings, arrayOfPhotoIds, deletedCallback)
    for i, photoId in ipairs( arrayOfPhotoIds ) do
      FlickrAPI.deletePhoto( publishSettings, { photoId = photoId, suppressErrorCodes = { [ 1 ] = true } } )

      deletedCallback( photoId )
    end
  end,

  metadataThatTriggersRepublish = function( publishSettings )
    return {

      default = false,
      title = true,
      caption = true,
      keywords = true,
      gps = true,
      dateCreated = true,

      -- also (not used by Flickr sample plug-in):
        -- customMetadata = true,
        -- com.whoever.plugin_name.* = true,
        -- com.whoever.plugin_name.field_name = true,

    }
  end,

  shouldReverseSequenceForPublishedCollection = function(publishSettings, collectionInfo)
    return false
  end,


    canAddCommentsToService = function(publishSettings)
    -- TODO: One can check connection to a server here, but so far
    -- we just return false so that comment panel will appear disabled.
    return false
  end,

  addCommentToPublishedPhoto = function(settings, id, commentText)
    -- TODO: Implement comment publishing
  end,

  deletePhotosFromPublishedCollection = function(settings, ids, callback, collectionId)
    -- TODO: Delete each photo from `ids` and call a callback with an ID
    -- of each deleted photo
  end,

  deletePublishedCollection = function(settings, info)
    -- TODO: Delete photo album with it photos.
  end,

})
