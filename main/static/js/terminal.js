(function() {
  var COMMANDS, CommandStack, Events, LocalStorage, OVER_QUOTA_MSG, Options, SUPPORTED_SERVICES, Terminal, User, WELCOME_MESSAGE,
    __slice = Array.prototype.slice,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  COMMANDS = {
    "ls": {
      "args": [0, 1],
      "help": "Usage: ls [DIRECTORY]\nList information about DIRECTORY (the current directory by default)."
    },
    "mv": {
      "args": [2],
      "help": "Usage: mv [SOURCE] [DEST]\nor:    mv [SOURCE] [DIRECTORY]\nRename SOURCE to DEST, or move SOURCE(s) to DIRECTORY."
    },
    "cd": {
      "args": [0, 1],
      "help": "Usage: cd [PATH]\nChanges the current working directory to PATH."
    },
    "cp": {
      "args": [2, 3],
      "help": "Usage: cp SOURCE TARGET [-R]\nCopies a file or directory from `source` to `target`.\n-R, -r: Copy SOURCE recursively."
    },
    "rm": {
      "args": [1, 2],
      "help": "Usage: rm [-rf] FILE\nRemoves FILE.\n-R, -r: Removes FILE recursively, removing all files within FILE if it is a directory.\n-f: Never prompt for confirmation"
    },
    "mkdir": {
      "args": [1, 2],
      "help": "Usage: mkdir NAME\nCreates a directory 'NAME' in the current working directory."
    },
    "upload": {
      "args": [1, 2, 3],
      "help": "Usage: upload TARGET_PATH [--services=dropbox,google] [--overwrite]\nBrings up the upload dialog box to upload a file.\nTARGET_PATH: Path of the resulting file on the target services.\n-s, --services: Comma-separated list of services to upload the file to.\n-o, --overwrite: Overwrite an existing file of the same.",
      "options": {
        "overwrite": {
          "type": "bool",
          "longForm": "overwrite",
          "shortForm": "o",
          "default": false
        },
        "services": {
          "type": "list",
          "longForm": "services",
          "shortForm": "s",
          "default": ["dropbox", "google"]
        }
      }
    },
    "download": {
      "args": [1],
      "help": "Usage: download PATH\nDownloads the file or directory at PATH from an enabled storage service."
    },
    "help": {
      "args": [0, 1],
      "help": "Usage: help [COMMAND]\nI'm just here to help, bro."
    },
    "storage": {
      "args": [0, 2],
      "help": "Usage: storage [enable or disable] [SERVICE]\nView and enable or disable storage methods. SERVICE should be one of: \"dropbox\", \"google\""
    },
    "login": {
      "args": [0, 1],
      "help": "Usage: login [SERVICE] \nBrings up the authentication and authorization dialog for SERVICE.\nIf SERVICE is not specified, defaults to Google, if enabled."
    },
    "logout": {
      "args": [0, 1],
      "help": "Usage: logout\nLogs you out NephStore. You will need log back in via OpenID to continue using NephStore. "
    }
  };

  SUPPORTED_SERVICES = ["dropbox", "google"];

  WELCOME_MESSAGE = "<div class=\"welcome-message\">\nWelcome to NephStore.\n\nTo begin, login via OpenID to a Google account. Click the link below to do so. \n- Once the terminal is available, use the `storage` command to enable and disable storage services. By default, no service is enabled. \n- Once you've enabled a service(s), use `login <service name>` for each service you enable to authorize Nephstore to access your account.\n- Then, you can navigate the filesystem using standard Unix terminal commands, as well as use the `upload` and `download <path>` commands.\n</div>";

  OVER_QUOTA_MSG = ": Cannot perform requested operation: Over Quota";

  Events = (function() {

    function Events() {}

    Events.prototype.hook = function(name, handler) {
      if (this._events == null) this._events = {};
      if (this._events[name] == null) this._events[name] = [];
      return this._events[name].push(handler);
    };

    Events.prototype.fire = function() {
      var args, handler, name, _i, _len, _ref, _results;
      name = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if ((this._events != null) && (this._events[name] != null)) {
        _ref = this._events[name];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          handler = _ref[_i];
          _results.push(handler.apply(null, args));
        }
        return _results;
      }
    };

    return Events;

  })();

  LocalStorage = (function() {

    function LocalStorage() {}

    LocalStorage.prototype.get = function(key) {
      var value;
      value = window.localStorage[key];
      if (!(value != null)) return null;
      return JSON.parse(value);
    };

    LocalStorage.prototype.set = function(key, value) {
      return window.localStorage[key] = JSON.stringify(value);
    };

    return LocalStorage;

  })();

  CommandStack = (function() {

    function CommandStack() {
      var stored;
      this.index = -1;
      this.storage = new LocalStorage();
      stored = this.storage.get("commands");
      if (stored != null) {
        this.stack = stored;
      } else {
        this.storage.set("commands", []);
        this.stack = [];
      }
    }

    CommandStack.prototype.reset = function() {
      return this.index = -1;
    };

    CommandStack.prototype.empty = function(reset) {
      this.stack = [];
      if (reset || !(reset != null)) this.reset();
      return this.storage.set("commands", []);
    };

    CommandStack.prototype.push = function(command) {
      var old;
      if (this.stack[0] !== command) {
        this.stack.splice(0, 0, command);
        old = this.storage.get("commands");
        old.splice(0, 0, command);
        if (old.length > 25) old.pop(-1);
        return this.storage.set("commands", old);
      }
    };

    CommandStack.prototype.getItem = function(index) {
      var item;
      item = this.stack[index];
      return item;
    };

    CommandStack.prototype.previous = function() {
      if (this.index + 1 < this.stack.length) {
        this.index++;
      } else {
        return null;
      }
      return this.getItem(this.index);
    };

    CommandStack.prototype.next = function() {
      if (this.index - 1 >= -1) this.index--;
      if (this.index < 0) {
        return "";
      } else {
        return this.getItem(this.index);
      }
    };

    return CommandStack;

  })();

  Options = (function() {
    /*
            Options parser class.
            
            Pass the expected arguments as an Object in the following format:
            For the possible arguments as follows:
            "--switchExample -s --var=bob --list=item1,item2"
            {
                "argName":{
                    "type":"bool",
                    "longForm":"switchExample",
                    "shortForm":"sE"
                    "default":false
                },
                "shortSwitch":{
                    "type":"bool",
                    "longForm":"short",
                    "shortForm":"s",
                    "default":false
                },
                "varExample":{
                    "type":"var",
                    "longForm":"var",
                    "shortForm":"v",
                    "default":"joe"
                },
                "listExample":{
                    "type":"list",
                    "longForm":"list",
                    "shortForm":"l",
                    "default":["item3", "item4"]
                }
            }
    */
    function Options(options) {
      this.options = options;
    }

    Options.prototype.stripArgs = function(args) {
      var arg;
      return ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = args.length; _i < _len; _i++) {
          arg = args[_i];
          if (arg.startswith("-")) _results.push(arg);
        }
        return _results;
      })()) || [];
    };

    Options.prototype._getSwitchIndex = function(long, short, args) {
      var i;
      i = args.indexOf("--" + long);
      if (i >= 0) {
        return i;
      } else {
        return args.indexOf("-" + short);
      }
    };

    Options.prototype._getAssignedArgIndex = function(long, short, args) {
      var i, _ref;
      for (i = 0, _ref = args.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
        if (args[i].startswith("--" + long) || args[i].startswith("-" + short)) {
          return i;
        }
      }
      return -1;
    };

    Options.prototype.processOptions = function(oargs) {
      var args, data, i, list, name, parsedIndices, _i, _len, _ref;
      args = this.stripArgs(oargs);
      parsedIndices = [];
      _ref = this.options;
      for (name in _ref) {
        data = _ref[name];
        switch (data.type) {
          case "bool":
            i = this._getSwitchIndex(data.longForm, data.shortForm, args);
            if (i >= 0) {
              parsedIndices.push(i);
              this[name] = !data["default"];
            } else {
              this[name] = data['default'];
            }
            break;
          case "list":
            i = this._getAssignedArgIndex(data.longForm, data.shortForm, args);
            if (i >= 0) {
              try {
                list = args[i].split("=")[1].split(",");
              } catch (e) {
                this[name] = data['default'];
                break;
              }
              this[name] = list;
              parsedIndices.push(i);
            } else {
              this[name] = data['default'];
            }
            break;
          case "var":
            i = this._getAssignedArgIndex(data.longForm, data.shortForm, args);
            if (i >= 0) {
              this[name] = args[i];
              parsedIndices.push(i);
            } else {
              this[name] = data['default'];
            }
        }
      }
      for (_i = 0, _len = parsedIndices.length; _i < _len; _i++) {
        i = parsedIndices[_i];
        oargs.splice(oargs.indexOf(args[i]), 1);
      }
      return oargs;
    };

    return Options;

  })();

  User = (function(_super) {

    __extends(User, _super);

    function User(uid, name, email) {
      this.uid = uid;
      this.name = name;
      this.email = email;
      if (this.uid) {
        this.authenticated = true;
      } else {
        this.authenticated = false;
      }
    }

    User.prototype.setUserInfo = function(uid, name, email) {
      this.uid = uid;
      this.name = name;
      this.email = email;
      return this.authenticated = true;
    };

    User.prototype.getFromServer = function() {
      $.ajax({
        url: "/user/get/",
        success: this._handleServerInfo.bind(this),
        async: true
      });
      return this;
    };

    User.prototype._handleServerInfo = function(data, textStatus, xhr) {
      var info;
      if (data.authenticated) {
        info = data.userInformation;
        this.setUserInfo(info.uid, info.first_name, info.email);
      } else {
        this.loginURL = data.loginURL;
      }
      return this.fire("userInfoReceived");
    };

    User.prototype.toString = function() {
      return this.email;
    };

    return User;

  })(Events);

  Terminal = (function() {

    function Terminal() {
      var entry,
        _this = this;
      this.element = $("#terminal");
      this.path = "/";
      this.stack = new CommandStack();
      this.output(WELCOME_MESSAGE);
      this.blinkCursor();
      this.user = new User().getFromServer();
      this.user.hook("userInfoReceived", function() {
        if (_this.user.authenticated) {
          return _this.newLine();
        } else {
          return _this.forceOpenIDLogin();
        }
      });
      entry = $("#entry");
      entry.focusout(function(e) {
        return setTimeout(function() {
          var val;
          val = entry.val();
          entry[0].focus();
          return entry.val(val);
        }, 50);
      });
      entry.keyup(function(e) {
        var interrupt;
        interrupt = e.which === 67 && e.ctrlKey;
        if (_this.promptHandler && !interrupt) {
          return _this.promptHandler(e);
        } else if (interrupt) {
          return _this.keyboardInterrupt();
        } else if (e.which === 13) {
          _this.processCurrentLine();
          return entry.val("");
        } else if (e.which === 38) {
          return _this.recallCommand(true);
        } else if (e.which === 40) {
          return _this.recallCommand(false);
        } else {
          return _this.setCommand(e.target.value);
        }
      });
    }

    Terminal.prototype.keyboardInterrupt = function() {
      this.newLine();
      throw new Error("KeyboardInterrupt");
    };

    Terminal.prototype.newLine = function() {
      var cursor, div, entry, text;
      $("#active-entry,#active-line").attr("id", "");
      $("#cursor").remove();
      entry = this.createEntryElement();
      text = "[" + (this.user.name.toLowerCase()) + "@nephstore]:" + this.path + "$ ";
      cursor = this.createCursor();
      div = $(document.createElement("div"));
      div.addClass("line").attr("id", "active-line").append(text).append(entry).append(cursor);
      $("#terminal").append(div);
      div[0].scrollIntoViewIfNeeded();
      this.setEntryEnabled(true);
      return this.promptHandler = null;
    };

    Terminal.prototype.createEntryElement = function() {
      var span;
      span = $(document.createElement("span"));
      return span.attr("id", "active-entry");
    };

    Terminal.prototype.createCursor = function() {
      var cdiv, div;
      div = $(document.createElement("div"));
      div.attr("id", "cursor-wrapper");
      cdiv = $(document.createElement("span")).html("&nbsp;").attr("id", "cursor").appendTo(div);
      return cdiv;
    };

    Terminal.prototype.blinkCursor = function() {
      $("#cursor").toggleClass("hidden");
      return setTimeout(this.blinkCursor.bind(this), 750);
    };

    Terminal.prototype.setEntryEnabled = function(enabled) {
      if (enabled) {
        return $("#entry").removeAttr("disabled");
      } else {
        return $("#entry").attr("disabled", "disabled");
      }
    };

    Terminal.prototype.processCurrentLine = function() {
      var args, command, input, returnValue, _ref, _ref2;
      this.setEntryEnabled(false);
      input = $("#entry").val().trim();
      if (input === "") return this.newLine();
      this.stack.push(input);
      _ref = input.splitUnescapedSpaces(), command = _ref[0], args = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
      if (command === "help") {
        this.do_help.apply(this, args);
      } else if (__indexOf.call(Object.keys(COMMANDS), command) < 0) {
        this.output("" + command + ": command not found");
      } else if (_ref2 = args.length, __indexOf.call(COMMANDS[command].args, _ref2) < 0) {
        this.output(COMMANDS[command].help.replace("\n", "<br />") || "Invalid syntax");
      } else {
        if (this["do_" + command] != null) {
          returnValue = this["do_" + command].apply(this, args);
        }
      }
      if (((returnValue != null) && returnValue) || (!(returnValue != null))) {
        this.newLine();
      }
      return this.stack.reset();
    };

    Terminal.prototype.output = function(html, append, keepNewLines) {
      var div;
      div = $(document.createElement("div")).addClass("output");
      if (keepNewLines || typeof html !== "string") {
        div.html(html);
      } else {
        div.html(html.replace(/\n/g, "<br />"));
      }
      if (append) {
        $("#terminal").append(html);
      } else {
        $("#active-line").after(div);
      }
      return $("#cursor").insertAfter(div);
    };

    Terminal.prototype.setCommand = function(command, copyToInput) {
      $("#active-entry").html(command.replace(/\s/g, "&nbsp;").replace(/</g, "&lt;"));
      if (copyToInput) return $("#entry").val(command);
    };

    Terminal.prototype.recallCommand = function(previous) {
      var command;
      command = previous ? this.stack.previous() : this.stack.next();
      if (command !== null) return this.setCommand(command, true);
    };

    Terminal.prototype.forceOpenIDLogin = function() {
      return $(".welcome-message").after($("<span>OpenID Login: <a href=\"" + this.user.loginURL + "\">" + this.user.loginURL + "</a></span>"));
    };

    Terminal.prototype.do_help = function(command) {
      var string;
      string = "Available commands: <span class=\"command-list\">" + (Object.keys(COMMANDS).join(" ")) + "</span>\nEnter `help COMMAND` for more information.";
      if (command != null) {
        string = COMMANDS[command] != null ? COMMANDS[command].help : "" + command + ": command not found\n" + string;
      }
      return this.output(string);
    };

    Terminal.prototype.do_login = function(service) {
      var login_success, request, url, win,
        _this = this;
      if (!(service != null)) service = "google";
      if (__indexOf.call(SUPPORTED_SERVICES, service) < 0) {
        return this.output("" + service + ": storage service not supported or disabled.\nAvailable storage services: <span class=\"command-list\">" + (SUPPORTED_SERVICES.join(" ")) + "</span>");
      }
      url = "/" + service + "_auth/";
      win = null;
      login_success = function(data, textStatus, xhr) {
        if (data.success && data.authorized) {
          _this.output("Successfully authorized for Dropbox.");
          return _this.newLine();
        } else if (data.success && data.auth_url) {
          if (!(win != null) || win.closed) win = window.open(data.auth_url);
          return $.getJSON(url, login_success.bind(_this));
        } else if (data.success && !data.authorized) {
          return setTimeout(function() {
            return $.getJSON(url, login_success.bind(_this));
          }, 1000);
        } else {
          if (!(win != null) || win.closed) win = window.open("/admin/");
          return setTimeout(function() {
            return $.getJSON(url, login_success.bind(_this));
          }, 1000);
        }
      };
      request = $.getJSON(url, login_success.bind(this));
      return false;
    };

    Terminal.prototype.sendCommand = function(command, data, callback) {
      data["command"] = command;
      return $.post("/command/", data, callback, "json");
    };

    Terminal.prototype.absolutePath = function(path) {
      if ((!path.startswith("/" || path.startswith("./"))) && !path.startswith("..")) {
        if (path.startswith("./")) path = path.slice(2);
        path = this.path.endswith("/") ? "" + this.path + path : "" + this.path + "/" + path;
      }
      return path;
    };

    Terminal.prototype.do_cd = function(path) {
      var absPath,
        _this = this;
      if (path === "..") {
        if (this.path !== "/") {
          this.path = this.path.split("/").slice(0, -1).join("/");
          if (this.path === "") this.path = "/";
        }
        return true;
      }
      if (!path) path = "/";
      absPath = this.absolutePath(path);
      this.sendCommand("cd", {
        path: absPath
      }, function(data, textStatus, xhr) {
        if (data.success) {
          _this.path = absPath;
        } else if (!data.is_dir) {
          _this.output("cd: " + path + ": Not a directory");
        } else if (!data.exists) {
          _this.output("cd: " + path + ": No such file or directory");
        } else {
          _this.output("cd: Unknown error: " + data.error);
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_mkdir = function(name) {
      var _this = this;
      this.sendCommand("mkdir", {
        "path": this.path,
        "name": name
      }, function(data, textStatus, xhr) {
        if (data.exists_already) {
          _this.output("mkdir: cannot create directory `" + name + "': File exists");
        } else if (data.error) {
          _this.output("mkdir: Unknown error: " + data.error);
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_ls = function(path) {
      var _this = this;
      path = path != null ? this.absolutePath(path) : this.path;
      this.sendCommand("ls", {
        "path": path
      }, function(data, textStatus, xhr) {
        var c, contents, elem, s, _i, _len, _ref;
        if (data.error) {
          _this.output("ls: Unknown error: " + data.error);
        } else {
          contents = [];
          elem = data.contents.length > 15 ? "div" : "span";
          _ref = data.contents;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            c = _ref[_i];
            if (c.is_dir) {
              s = "<" + elem + " class=\"directory\">";
            } else {
              s = "<" + elem + " class=\"file\">";
            }
            s += "" + (c.path.basename()) + "</span>";
            contents.push(s);
          }
          _this.output("<div class=\"command-list\">" + (contents.join("&nbsp;&nbsp;")) + "</div>");
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_mv = function(source, target) {
      var absSource, absTarget,
        _this = this;
      absSource = this.absolutePath(source);
      absTarget = this.absolutePath(target);
      this.sendCommand("mv", {
        "source": absSource,
        "target": absTarget
      }, function(data, textStatus, xhr) {
        if (!data.success) {
          if (!data.source_exists) {
            _this.output("mv: cannot stat `" + source + "': No such file or directory");
          } else if (data.over_quota) {
            _this.output("mv" + OVER_QUOTA_MSG);
          } else {
            _this.output("mv: Unknown error: " + data.error);
          }
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_cp = function() {
      var absSource, absTarget, args, i, index, recursive, source, target, _ref,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      recursive = false;
      if (args.length === 3) {
        index = null;
        for (i = 0, _ref = args.length; 0 <= _ref ? i < _ref : i > _ref; 0 <= _ref ? i++ : i--) {
          if (args[i].toLowerCase() === "-r") {
            recursive = true;
            index = i;
          }
        }
        args.splice(index, 1);
      }
      source = args[0];
      target = args[1];
      if (!source || !target) return this.output("cp: invalid source or target.");
      absSource = this.absolutePath(source);
      absTarget = this.absolutePath(target);
      this.sendCommand("cp", {
        "source": absSource,
        "target": absTarget,
        "recursive": recursive
      }, function(data, textStatus, xhr) {
        if (!data.success) {
          if (data.over_quota) {
            _this.output("mv" + OVER_QUOTA_MSG);
          } else if (!data.source_exists) {
            _this.output("cp: Cannot stat `" + source + "': No such file or directory");
          } else if (data.source_is_dir) {
            _this.output("cp: Omitted directory `" + source + "'");
          } else {
            _this.output("cp: Unknown error: " + data.error);
          }
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_rm = function() {
      var absPath, args, force, options, path, possible, recursive, _ref, _ref2, _ref3,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      _ref = [false, false], recursive = _ref[0], force = _ref[1];
      if (args.length === 2) {
        possible = ["-r", "-f", "-rf", "-fr"];
        options = (_ref2 = args[0].toLowerCase(), __indexOf.call(possible, _ref2) >= 0) ? args.shift() : args.pop();
        switch (options.toLowerCase()) {
          case "-r":
            recursive = true;
            break;
          case "-f":
            force = true;
            break;
          case "-rf":
          case "-fr":
            _ref3 = [true, true], recursive = _ref3[0], force = _ref3[1];
        }
      }
      path = args[0];
      absPath = this.absolutePath(path);
      this.sendCommand("rm", {
        "force": force,
        "recursive": recursive,
        "path": absPath
      }, function(data, textStatus, xhr) {
        if (!data.success) {
          if (!data.target_exists) {
            _this.output("rm: cannot remove `" + path + "': No such file or directory");
          } else if (data.is_dir) {
            _this.output("rm: cannot remove `" + path + "': is a directory; use -R to remove.");
          } else {
            _this.output("rm: Unknown error: " + data.error);
          }
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_download = function(path) {
      var absPath,
        _this = this;
      absPath = this.absolutePath(path);
      this.sendCommand("download", {
        path: absPath
      }, function(data, textStatus, xhr) {
        if (data.success) {
          window.open(data.url);
        } else if (!data.exists) {
          _this.output("download: cannot download " + path + ": No such file or directory");
        } else {
          _this.output("download: Unknown error: " + data.error);
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_storage = function(op, service) {
      var _this = this;
      if (!(op != null) && !(service != null)) {
        op = "get";
      } else {
        if (op !== "enable" && op !== "disable") return this.do_help("storage");
        if (__indexOf.call(SUPPORTED_SERVICES, service) < 0) {
          return this.output("storage: Service not supported: `" + service + "'");
        }
      }
      this.sendCommand("storage", {
        "action": op,
        "service": service
      }, function(data, textStatus, xhr) {
        if (!data.success) {
          _this.output("storage: Unknown error: " + data.error);
        } else if (data.success && op === "enable") {
          _this.output("Successfully enabled " + service + ".\nUse `login `" + service + "' to authorize this app to access your account.");
        } else if (data.services) {
          _this.output("Enabled services: <span class=\"command-list\">" + (data.services.join(" ")) + "</span>\nAvailable services: <span class=\"command-list\">" + (SUPPORTED_SERVICES.join(" ")) + "</span>\nUse `storage disable &lt;service>` to disable.");
        }
        return _this.newLine();
      });
      return false;
    };

    Terminal.prototype.do_logout = function() {
      return window.location.href = "/logout/";
    };

    Terminal.prototype._uploadFile = function(fileInput, successHandler) {
      var data, hashes, percent, terminal, xhr,
        _this = this;
      data = fileInput.dataset;
      xhr = new XMLHttpRequest();
      terminal = $("#terminal");
      percent = $(document.createElement("span")).addClass("upload-percent").html("0%&nbsp;").appendTo(terminal);
      hashes = $(document.createElement("span")).addClass("upload-hashes").appendTo(terminal);
      xhr.upload.addEventListener("progress", function(e) {
        var p;
        if (e.lengthComputable) {
          p = Math.round((e.loaded * 100) / e.total);
          percent.html("" + p + "%&nbsp;");
          return hashes.text("#".repeat(p));
        }
      });
      xhr.addEventListener("load", function(e) {
        percent.html("100%&nbsp;");
        hashes.text("#".repeat(100));
        _this.output("<br />Complete.<br />", true);
        return successHandler(e);
      });
      xhr.open("POST", "/upload/?overwrite=" + data.overwrite + "&services=" + data.services + "&target=" + data.target, true);
      xhr.setRequestHeader("X-CSRFToken", $.cookie('csrftoken'));
      return xhr.send(fileInput.files[0]);
    };

    Terminal.prototype.do_upload = function() {
      var args, options, service, successHandler, target, _i, _len, _ref,
        _this = this;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      options = new Options(COMMANDS.upload.options);
      target = options.processOptions(args)[0];
      if (!target) return this.outputError("upload: Invalid target path");
      _ref = options.services;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        service = _ref[_i];
        if (__indexOf.call(SUPPORTED_SERVICES, service) < 0) {
          return this.outputError("upload: service not supported: `" + service + "'");
        }
      }
      this.setEntryEnabled(true);
      successHandler = function(e) {
        var json, result, results, s, _j, _len2, _ref2;
        json = JSON.parse(e.target.responseText);
        if (json.success) {
          results = [];
          _ref2 = json.results;
          for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
            result = _ref2[_j];
            s = "" + (result.service.capitalize()) + ": ";
            if (result.result.success) {
              s += "Successful.";
            } else {
              s += "Failed: " + result.result.error;
            }
            results.push(s);
          }
          _this.output(results.join("<br />"), true);
        } else {
          _this.output("upload: Failed to upload: " + json.error);
        }
        return _this.newLine();
      };
      this.promptHandler = function(e) {
        var lastUpload;
        if (e.which === 13) {
          lastUpload = $(".file-upload").slice(-1)[0];
          return _this._uploadFile(lastUpload, successHandler);
        }
      };
      this.output("Select the file to upload below, then hit enter:\n<input type=\"file\" name=\"file\" class=\"file-upload\" data-overwrite=\"" + options.overwrite + "\" data-services=\"" + (options.services.join(",")) + "\" data-target=\"" + target + "\" />\n");
      $(".file-upload").change(function(e) {
        return $("#entry")[0].focus();
      });
      return false;
    };

    return Terminal;

  })();

  $(document).ready(function() {
    return new Terminal();
  });

}).call(this);
