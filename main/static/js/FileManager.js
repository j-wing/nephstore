(function() {
  var Entry, EntryList;

  EntryList = (function() {

    function EntryList(files) {
      var entry, file, _i, _len, _ref;
      this.files = files;
      this.entries = [];
      this.element = this.createElement();
      _ref = this.files;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        file = _ref[_i];
        entry = new Entry(file);
        this.entries.push(entry);
        this.element.append(entry.element);
      }
    }

    EntryList.prototype.createElement = function() {
      return $(document.createElement("ul")).addClass("file-entry-sub");
    };

    return EntryList;

  })();

  Entry = (function() {

    function Entry(fileInfo) {
      var _this;
      this.fileInfo = fileInfo;
      this.name = this.fileInfo.name;
      this.is_file = this.fileInfo.is_file;
      if (this.is_file) this.ext = this.name.split(".")[-1];
      if (!this.is_file) this.entries = new EntryList(this.fileInfo.entries);
      this.element = this.createElement();
      this.element.text(this.name);
      if (!this.is_file) this.element.append(this.entries.element);
      _this = this;
      this.element.click(function(e) {
        if (!_this.is_file && e.target === this) {
          return _this.element.toggleClass("expanded");
        }
      });
    }

    Entry.prototype.createElement = function() {
      var elem;
      elem = $(document.createElement("li")).addClass("file-tree-entry");
      if (this.is_file) {
        return elem.addClass("file-entry");
      } else {
        return elem.addClass("directory");
      }
    };

    return Entry;

  })();

  window.FileManager = (function() {

    function FileManager(files, element) {
      var rootEntry;
      this.files = files;
      this.element = element;
      if (!this.element) {
        this.element = $(document.createElement("div")).addClass("file-tree");
      }
      if (this.files.toString() === !"[object Object]") {
        this.files = JSON.parse(files);
      }
      rootEntry = new Entry({
        "name": "/",
        "is_file": false,
        "entries": this.files
      });
      this.element.append(rootEntry.element);
    }

    return FileManager;

  })();

}).call(this);
