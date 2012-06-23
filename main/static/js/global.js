(function() {

  String.prototype.startswith = function(string) {
    return this.slice(0, string.length) === string;
  };

  String.prototype.endswith = function(string) {
    return this.slice(-string.length) === string;
  };

  String.prototype.basename = function() {
    return this.split("/").splice(-1);
  };

  String.prototype.capitalize = function() {
    var i, split, _ref;
    split = this.split(" ");
    for (i = 0, _ref = split.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
      split[i] = split[i][0].toUpperCase() + split[i].slice(1);
    }
    return split.join(" ");
  };

  String.prototype.splitUnescapedSpaces = function() {
    var i, prev, resp, spaces, _ref;
    spaces = this.split(" ");
    resp = [];
    for (i = 0, _ref = spaces.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
      if (spaces.slice(i - 1)[0] && spaces.slice(i - 1)[0].endswith("\\")) {
        prev = resp.pop();
        resp.push("" + (prev.slice(0, -1)) + " " + spaces[i]);
      } else {
        resp.push(spaces[i]);
      }
    }
    return resp;
  };

  String.prototype.repeat = function(num) {
    return new Array(num + 1).join(this);
  };

  window.normpath = function(path) {
    var comp, comps, dot, initial_slashes, new_comps, slash, _i, _len, _ref;
    _ref = ['/', '.'], slash = _ref[0], dot = _ref[1];
    if (path === '') return path;
    initial_slashes = path.startswith('/');
    if (initial_slashes && path.startswith('//') && !path.startswith('///')) {
      initial_slashes = 2;
    }
    comps = path.split('/');
    new_comps = [];
    for (_i = 0, _len = comps.length; _i < _len; _i++) {
      comp = comps[_i];
      if (comp === '' || comp === '.') continue;
      if (comp !== '..' || (!initial_slashes && !new_comps) || (new_comps && new_comps.slice(-1) === '..')) {
        new_comps.push(comp);
      } else if (new_comps) {
        new_comps.pop();
      }
    }
    comps = new_comps;
    path = comps.join(slash);
    if (initial_slashes) path = slash.repeat(initial_slashes) + path;
    return path || dot;
  };

}).call(this);
