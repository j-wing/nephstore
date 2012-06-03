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

}).call(this);
