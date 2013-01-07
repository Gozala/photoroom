-- In lightroom environment require for standard library does not seems to
-- work instead `_G.*` seems to be available. There for proxy modules are
-- created to avoid rewrites of third party libraries.
return _G.math
