ProductXmlImport = require('./lib/xmlimport').XmlImport

exports.process = function(msg, cfg, cb, snapshot) {
  config = {
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
    project_key: cfg.projectKey
  };
  var im = new ProductXmlImport({
    config: config
  });
  im.process(msg, cb);
}