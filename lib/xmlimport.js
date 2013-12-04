/* ===========================================================
# sphere-product-xml-import - v0.3.0
# ==============================================================
# Copyright (c) 2013 Hajo Eichler
# Licensed under the MIT license.
*/
var Config, Q, Rest, Sync, parseString, _;

_ = require('underscore')._;

parseString = require('xml2js').parseString;

Config = require('../config');

Rest = require('sphere-node-connect').Rest;

Sync = require('sphere-product-sync').Sync;

Q = require('q');

exports.XmlImport = function(options) {
  this._options = options;
  this.sync = new Sync(Config);
  this.rest = this.sync._rest;
};

exports.XmlImport.prototype.process = function(data, callback) {
  var k, v, _ref, _results,
    _this = this;
  if (!_.isObject(data)) {
    throw new Error('JSON Object required');
  }
  if (!_.isFunction(callback)) {
    throw new Error('Callback must be a function');
  }
  if (data.attachments) {
    _ref = data.attachments;
    _results = [];
    for (k in _ref) {
      v = _ref[k];
      _results.push(this.transform(this.getAndFix(v), function(data) {
        return _this.createOrUpdate(data, callback);
      }));
    }
    return _results;
  } else {
    return this.returnResult(false, 'No products given', callback);
  }
};

exports.XmlImport.prototype.returnResult = function(positiveFeedback, msg, callback) {
  var d;
  d = {
    message: {
      status: positiveFeedback,
      msg: msg
    }
  };
  if (!positiveFeedback) {
    console.log('Error occurred: %j', d);
  }
  return callback(d);
};

exports.XmlImport.prototype.createOrUpdate = function(data, callback) {
  var p, query, _i, _len, _ref, _results,
    _this = this;
  _ref = data.products;
  _results = [];
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    p = _ref[_i];
    query = encodeURIComponent("masterData(current(masterVariant(sku=\"" + p.masterVariant.sku + "\")))");
    _results.push(this.rest.GET("/products?where=" + query, function(error, response, body) {
      var diff, json, p2;
      if (response.statusCode === 200) {
        json = JSON.parse(body);
        if (json.total === 1) {
          p.id = json.results[0].id;
          p.version = json.results[0].version;
          p2 = json.results[0].masterData.staged;
          p2.id = json.results[0].id;
          p2.version = json.results[0].version;
          diff = _this.sync.buildActions(p, p2);
          return diff.update(function(error, response, body) {
            if (response.statusCode === 200) {
              if (body === null) {
                return _this.returnResult(true, 'Nothing updated', callback);
              } else {
                return _this.returnResult(true, 'Product updated', callback);
              }
            } else {
              return _this.returnResult(false, 'Problem on updating existing product.' + body, callback);
            }
          });
        } else {
          return _this.rest.POST('/products', JSON.stringify(p), function(error, response, body) {
            if (response.statusCode === 201) {
              return _this.returnResult(true, 'New product created', callback);
            } else {
              return _this.returnResult(false, 'Problem on creating new product.' + body, callback);
            }
          });
        }
      } else {
        return _this.returnResult(false, 'Problem on fetching existing product via sku', callback);
      }
    }));
  }
  return _results;
};

exports.XmlImport.prototype.getAndFix = function(raw) {
  return "<?xml?><root>" + raw + "</root>";
};

exports.XmlImport.prototype.transform = function(xml, callback) {
  var _this = this;
  return parseString(xml, function(err, result) {
    if (err) {
      _this.returnResult(false, 'Error on parsing XML:' + err, callback);
    }
    return _this.mapProducts(result.root, callback);
  });
};

exports.XmlImport.prototype.mapProducts = function(xmljs, callback) {
  var allIds, images, products, variants,
    _this = this;
  products = [];
  variants = {};
  images = {};
  allIds = Q.all([this.productType(), this.taxCategory(), this.customerGroup()]);
  return allIds.spread(function(productTypeId, taxCategoryId, customerGroupId) {
    var d, img, k, n, p, parentId, row, uid, v, _i, _len, _ref;
    _ref = xmljs.row;
    for (k in _ref) {
      row = _ref[k];
      v = {
        id: 0,
        sku: _this.val(row, 'uid')
      };
      _this.mapCategories(row, v);
      _this.mapAttributes(row, v);
      _this.mapPrices(row, v, customerGroupId);
      img = _this.mapImages(row);
      if (_this.isVariant(row)) {
        parentId = row.basisUidartnr;
        if (!variants[parentId]) {
          variants[parentId] = [];
        }
        v.id = variants[parentId].length + 2;
        variants[parentId].push(v);
        images[parentId].push(img);
      } else {
        v.id = 1;
        n = _this.val(row, 'descriptionVariant', _this.val(row, 'name'));
        p = {
          productType: {
            typeId: 'product-type',
            id: productTypeId
          },
          taxCategory: {
            typeId: 'tax-category',
            id: taxCategoryId
          },
          name: _this.lang(n),
          slug: _this.lang(_this.slugify(n)),
          description: _this.lang(_this.val(row, 'description', '')),
          masterVariant: v,
          variants: []
        };
        _this.mapCategories(row, p);
        products.push(p);
        images[row.uid] = [];
        images[row.uid].push(img);
      }
    }
    for (_i = 0, _len = products.length; _i < _len; _i++) {
      p = products[_i];
      uid = p.masterVariant.attributes[0].value;
      if (variants[uid]) {
        p.variants = variants[uid];
      }
    }
    d = {
      products: products,
      images: images
    };
    return callback(d);
  });
};

exports.XmlImport.prototype.mapImages = function(row) {
  var i;
  return i = [
    {
      url: "http://s7g1.scene7.com/is/image/DemoCommercetools/" + row.uid
    }
  ];
};

exports.XmlImport.prototype.val = function(row, name, fallback) {
  if (row[name]) {
    return row[name][0];
  }
  return fallback;
};

exports.XmlImport.prototype.lang = function(v) {
  var l;
  return l = {
    de: v
  };
};

exports.XmlImport.prototype.slugify = function(str) {
  str = str.replace(/^\s+|\s+$/g, '').toLowerCase();
  return str.replace(/[^a-z0-9 -]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-');
};

exports.XmlImport.prototype.mapCategories = function(row, j) {
  return j.categories = [];
};

exports.XmlImport.prototype.mapAttributes = function(row, j) {
  var attribs, d, enums, n, numbers, orig, trans, v, _i, _len, _results;
  j.attributes = [];
  attribs = {
    uid: '',
    size: '',
    codeMaterial: '',
    descriptionMaterial: '',
    codecolorname: 'codeColorname',
    descriptionColorname: '',
    codeFilterColor: '',
    descriptionFilterColor: '',
    codeStyle: '',
    descriptionFilterStyle: '',
    codeFabrication: '',
    descriptionFabrication: '',
    CodeSerie: 'codeSerie',
    descriptionSerie: '',
    Theme: 'theme',
    ean: ''
  };
  for (orig in attribs) {
    trans = attribs[orig];
    if (!(trans.length > 0)) {
      trans = orig;
    }
    v = this.val(row, orig, '');
    if (!(v.length > 0)) {
      continue;
    }
    d = {
      name: trans,
      value: v
    };
    j.attributes.push(d);
  }
  numbers = ['hight', 'length', 'wide'];
  for (_i = 0, _len = numbers.length; _i < _len; _i++) {
    n = numbers[_i];
    v = this.val(row, n, '');
    if (!(v.length > 0)) {
      continue;
    }
    d = {
      name: n,
      value: parseInt(v, 10)
    };
    j.attributes.push(d);
  }
  enums = {
    bulkygoods: '',
    specialpriceflag: 'salesprice',
    Highlight: 'highlighted'
  };
  _results = [];
  for (orig in enums) {
    trans = enums[orig];
    if (!(trans.length > 0)) {
      trans = orig;
    }
    v = 'NO';
    if (this.val(row, orig, '') === '1') {
      v = 'YES';
    }
    d = {
      name: trans,
      value: v
    };
    _results.push(j.attributes.push(d));
  }
  return _results;
};

exports.XmlImport.prototype.mapPrices = function(row, j, customerGroupId) {
  var country, currency, p;
  j.prices = [];
  currency = 'EUR';
  country = 'DE';
  p = {
    value: {
      centAmount: this.getPrice(row, 'priceb2c'),
      currencyCode: currency
    }
  };
  j.prices.push(p);
  p = {
    value: {
      centAmount: this.getPrice(row, 'priceb2b'),
      currencyCode: currency
    },
    customerGroup: {
      typeId: 'customer-group',
      id: customerGroupId
    }
  };
  j.prices.push(p);
  if (this.val(row, 'specialpriceflag', '') === '0') {
    return;
  }
  p = {
    value: {
      centAmount: this.getPrice(row, 'specialprice'),
      currencyCode: currency
    },
    country: country
  };
  return j.prices.push(p);
};

exports.XmlImport.prototype.getPrice = function(row, name) {
  return parseInt(parseFloat(this.val(row, name, ''), 10) * 100);
};

exports.XmlImport.prototype.isVariant = function(row) {
  if (row.basisUidartnr === void 0) {
    return false;
  }
  if (row.basisUidartnr === row.uid) {
    return false;
  }
  return true;
};

exports.XmlImport.prototype.productType = function() {
  return this.getFirst('/product-types');
};

exports.XmlImport.prototype.taxCategory = function() {
  return this.getFirst('/tax-categories');
};

exports.XmlImport.prototype.customerGroup = function() {
  return this.getFirst('/customer-groups');
};

exports.XmlImport.prototype.getFirst = function(endpoint) {
  var deferred;
  deferred = Q.defer();
  this.rest.GET(endpoint, function(error, response, body) {
    var res;
    if (response.statusCode === 200) {
      res = JSON.parse(body).results;
      if (res.length > 0) {
        deferred.resolve(res[0].id);
      } else {

      }
      return deferred.reject(new Error("There are no entries at " + endpoint));
    } else {
      return deferred.reject(new Error("Problem on getting " + endpoint));
    }
  });
  return deferred.promise;
};
