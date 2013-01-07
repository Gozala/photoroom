local stringUtils = import("LrStringUtils")

return {
  encode = stringUtils.encodeBase64,
  decode = stringUtils.decodeBase64
}
