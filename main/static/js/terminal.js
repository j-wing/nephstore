(function() {
  var COMMANDS, CommandStack, Events, SUPPORTED_SERVICES, Terminal, User, WELCOME_MESSAGE,
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
      "help": "Usage: cp SOURCE TARGET [-R]\nCopies a file or directory from `source` to `target`."
    },
    "mkdir": {
      "args": [1, 2],
      "help": "Usage: mkdir NAME\nCreates a directory 'NAME' in the current working directory."
    },
    "upload": {
      "args": [0],
      "help": "Usage: upload\nBrings up the upload dialog box."
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
      "help": "View and enable or disable storage methods.\nUsage: storage [enable or disable] [SERVICE]\nWhere SERVICE is either \"dropbox\" or \"drive\"."
    },
    "login": {
      "args": [0, 1],
      "help": "Usage: login [SERVICE] \nBrings up the authentication and authorization dialog for SERVICE.\nIf SERVICE is not specified, defaults to Google, if enabled."
    },
    "logout": {
      "args": [0, 1],
      "help": "Usage: logout [SERVICE]\nLogs you out of SERVICE."
    }
  };

  SUPPORTED_SERVICES = ["dropbox", "google"];

  WELCOME_MESSAGE = "<div class=\"welcome-message\">\nWelcome to NephStore.\n\nTo begin, login via OpenID to a Google account. Click the link below to do so. \n- Once the terminal is available, use the `storage` command to enable and disable storage services. By default, no service is enabled. \n- Once you've enabled a service(s), use `login <service name>` for each service you enable to authorize Nephstore to access your account.\n- Then, you can navigate the filesystem using standard Unix terminal commands, as well as use the `upload` and `download <path>` commands.\n</div>";

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

  CommandStack = (function() {

    function CommandStack() {
      this.stack = [];
      this.index = -1;
    }

    CommandStack.prototype.reset = function() {
      return this.index = -1;
    };

    CommandStack.prototype.empty = function(reset) {
      this.stack = [];
      if (reset || !(reset != null)) return this.reset();
    };

    CommandStack.prototype.push = function(command) {
      return this.stack.splice(0, 0, command);
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
        if (e.which === 13) {
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
      return div[0].scrollIntoViewIfNeeded();
    };

    Terminal.prototype.createEntryElement = function() {
      var span;
      span = $(document.createElement("span"));
      return span.attr("id", "active-entry");
    };

    Terminal.prototype.createCursor = function() {
      var span;
      span = $(document.createElement("span"));
      span.html("&nbsp;");
      return span.attr("id", "cursor");
    };

    Terminal.prototype.blinkCursor = function() {
      $("#cursor").toggleClass("hidden");
      return setTimeout(this.blinkCursor.bind(this), 750);
    };

    Terminal.prototype.processCurrentLine = function() {
      var args, command, input, returnValue, _ref, _ref2;
      input = $("#entry").val().trim();
      if (input === "") return this.newLine();
      this.stack.push(input);
      _ref = input.split(" "), command = _ref[0], args = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
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

    Terminal.prototype.output = function(html, keepNewLines) {
      var div;
      div = $(document.createElement("div")).addClass("output");
      if (keepNewLines || typeof html !== "string") {
        div.html(html);
      } else {
        div.html(html.replace(/\n/g, "<br />"));
      }
      return $("#active-line").after(div);
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
      return $(".welcome-message").after($("<span>OpenID Login: <a target=\"_blank\" href=\"" + this.user.loginURL + "\">" + this.user.loginURL + "</a></span>"));
    };

    Terminal.prototype.do_cd = function(path) {
      if (!path) path = "/";
      return this.path = path;
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
      this.output("...");
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

    return Terminal;

  })();

  $(document).ready(function() {
    return new Terminal();
  });

}).call(this);
