/* ===========================================================
# sphere-product-xml-import - v0.3.2
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var parseString;

parseString = require('xml2js').parseString;

exports.xmlFix = function(xml) {
  if (!xml.match(/\<root\>/)) {
    xml = "<root>" + xml + "</root>";
  }
  if (!xml.match(/\?xml/)) {
    xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" + xml;
  }
  return xml;
};

exports.xmlTransform = function(xml, callback) {
  return parseString(xml, callback);
};

exports.xmlVal = function(elem, attribName, fallback) {
  if (elem[attribName]) {
    return elem[attribName][0];
  }
  return fallback;
};
