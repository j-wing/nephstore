COMMANDS = 
    "ls":
        "args":[0,1]
        "help":"""
                Usage: ls [DIRECTORY]
                List information about DIRECTORY (the current directory by default).
                """
    "mv":
        "args":[2]
        "help":"""
                Usage: mv [SOURCE] [DEST]
                or:    mv [SOURCE] [DIRECTORY]
                Rename SOURCE to DEST, or move SOURCE(s) to DIRECTORY.
                """
    "cd":
        "args":[0,1]
        "help":"""Usage: cd [PATH]
                Changes the current working directory to PATH.
                """
    "cp":
        "args": [2, 3]
        "help":"""
                Usage: cp SOURCE TARGET [-R]
                Copies a file or directory from `source` to `target`.
                -R, -r: Copy SOURCE recursively.
                """
    "rm":
        "args":[1,2]
        "help":"""
        Usage: rm [-rf] FILE
        Removes FILE.
        -R, -r: Removes FILE recursively, removing all files within FILE if it is a directory.
        -f: Never prompt for confirmation
        """
    "mkdir":
        "args":[1,2]
        "help":"""
            Usage: mkdir NAME
            Creates a directory 'NAME' in the current working directory.
            """
    "upload":
        "args":[0]
        "help":"""
                Usage: upload
                Brings up the upload dialog box.
                """
    "download":
        "args":[1]
        "help":"""
                Usage: download PATH
                Downloads the file or directory at PATH from an enabled storage service.
                """
    "help":
        "args":[0,1]
        "help":"""
                Usage: help [COMMAND]
                I'm just here to help, bro.
                """
    "storage":
        "args":[0, 2]
        "help":"""
            Usage: storage [enable or disable] [SERVICE]
            View and enable or disable storage methods. SERVICE should be one of: "dropbox", "google"
            """
    "login":
        "args":[0, 1]
        "help":"""
                Usage: login [SERVICE] 
                Brings up the authentication and authorization dialog for SERVICE.
                If SERVICE is not specified, defaults to Google, if enabled.
                """
    "logout":
        "args":[0,1]
        "help":"""
            Usage: logout
            Logs you out of SERVICE.
            """
SUPPORTED_SERVICES = [
    "dropbox"
    "google"
]

WELCOME_MESSAGE = """
<div class="welcome-message">
Welcome to NephStore.

To begin, login via OpenID to a Google account. Click the link below to do so. 
- Once the terminal is available, use the `storage` command to enable and disable storage services. By default, no service is enabled. 
- Once you've enabled a service(s), use `login <service name>` for each service you enable to authorize Nephstore to access your account.
- Then, you can navigate the filesystem using standard Unix terminal commands, as well as use the `upload` and `download <path>` commands.
</div>
"""

OVER_QUOTA_MSG = ": Cannot perform requested operation: Over Quota"

class Events
    # Mixin to be used by other classes
    # Implements event hooking/firing
    
    hook:(name, handler)->
        @_events = {} unless @_events?
        @_events[name] = [] unless @_events[name]?
        
        @_events[name].push handler
    
    fire:(name, args...) ->
        handler(args...) for handler in @_events[name] if (@_events? and @_events[name]?)

class LocalStorage
    get:(key) ->
        value = window.localStorage[key]
        if not value?
            return null
        return JSON.parse value
    set:(key, value) ->
        window.localStorage[key] = JSON.stringify value
        
class CommandStack
    constructor:() ->
        @index = -1
        @storage = new LocalStorage()
        
        stored = @storage.get("commands")
        if stored?
            @stack = stored
        else
            @storage.set "commands", []
            @stack = []
    
    reset:() ->
        @index = -1
    
    empty:(reset) ->
        @stack = []
        @reset() if reset or not reset?
        @storage.set("commands", [])
    
    push:(command) ->
        if @stack[0] != command
            @stack.splice 0, 0, command
            old = @storage.get("commands")
            old.splice 0, 0, command
            if old.length > 25
                old.pop -1
            @storage.set("commands", old)
    
    getItem:(index) ->
        item = @stack[index]
        return item
        
    previous:() ->
        if @index+1 < @stack.length then @index++ else return null
        return @getItem @index
    
    next:() ->
        if @index-1 >= -1 then @index--
        if @index < 0 then return "" else return @getItem @index
        

class User extends Events
    constructor:(@uid, @name, @email) ->
        if @uid
            @authenticated = true
        else
            @authenticated = false
    
    setUserInfo:(uid,name,email) ->
        @uid = uid
        @name = name
        @email= email
        @authenticated = true
    
    getFromServer:() ->
        $.ajax
            url:"/user/get/"
            success:@_handleServerInfo.bind @
            async:true
        return @
    
    _handleServerInfo:(data, textStatus, xhr) ->
        if data.authenticated
            info = data.userInformation
            @setUserInfo info.uid, info.first_name, info.email
        else
            @loginURL = data.loginURL
        
        @fire "userInfoReceived"
    toString:() ->
        return @email
            
    
class Terminal
    constructor:() ->
        @element = $("#terminal")
        @path = "/"
        
        @stack = new CommandStack()

        @output WELCOME_MESSAGE
        @blinkCursor()
        @user = new User().getFromServer()
        @user.hook "userInfoReceived",() =>
            if @user.authenticated
                @newLine()
            else
                @forceOpenIDLogin()
        
        entry = $("#entry")
        
        entry.focusout (e) ->
            setTimeout(() ->
                val = entry.val()
                entry[0].focus()
                entry.val val
                
            , 50)
            
        entry.keyup (e) =>
            # Return key
            if e.which == 13
                @processCurrentLine()
                entry.val("")
            # Up arrow
            else if e.which == 38
                @recallCommand true
            # Down Arrow
            else if e.which == 40
                @recallCommand false
            else
                @setCommand e.target.value
    newLine:() ->
        $("#active-entry,#active-line").attr("id", "")
        $("#cursor").remove()
        
        entry = @createEntryElement()
        text = "[#{@user.name.toLowerCase()}@nephstore]:#{@path}$ "
        cursor = @createCursor()
        
        div = $ document.createElement "div" 
        div.addClass("line").attr("id", "active-line").append(text).append(entry).append(cursor)
        $("#terminal").append div
        div[0].scrollIntoViewIfNeeded()
        $("#entry").removeAttr("disabled")
    
    createEntryElement:()->
        span = $ document.createElement "span"
        span.attr("id", "active-entry")
    
    createCursor:() ->
        span =  $ document.createElement "span"
        span.html("&nbsp;")
        span.attr "id","cursor"
    
    blinkCursor:() ->
        $("#cursor").toggleClass("hidden")
        setTimeout @blinkCursor.bind(@),750
    
    processCurrentLine:()->
        $("#entry").attr("disabled", "disabled")
        input = $("#entry").val().trim()
        
        if input is ""
            return @newLine()
        
        @stack.push input
        
        #TODO Do not match escaped spaces!
        [command,args...] = input.splitUnescapedSpaces()
        if command is "help"
            @do_help(args...)
        else if command not in Object.keys COMMANDS
            @output "#{command}: command not found"
        else if args.length not in COMMANDS[command].args
            @output (COMMANDS[command].help.replace("\n", "<br />") or "Invalid syntax")
        
        else
            returnValue = @["do_#{command}"](args...) if @["do_#{command}"]?
        
        if (returnValue? and returnValue) or (not returnValue?)
            @newLine()
        @stack.reset()
    
    output:(html, keepNewLines) ->
        div = $(document.createElement("div")).addClass("output")
        if keepNewLines or typeof html != "string" then div.html html else div.html html.replace /\n/g, "<br />"
        $("#active-line").after div
    
    setCommand:(command, copyToInput) ->
        $("#active-entry").html command.replace(/\s/g,"&nbsp;").replace(/</g, "&lt;")
        $("#entry").val command if copyToInput
    
    recallCommand:(previous) ->
        command = if previous then @stack.previous() else @stack.next()
        if command != null
            @setCommand command,true
    
    forceOpenIDLogin:() ->
        $(".welcome-message").after $ """<span>OpenID Login: <a target="_blank" href="#{@user.loginURL}">#{@user.loginURL}</a></span>"""

    do_help:(command)->
        string = """
                Available commands: <span class="command-list">#{Object.keys(COMMANDS).join(" ")}</span>
                Enter `help COMMAND` for more information.
                """
        if command?
            string = if COMMANDS[command]? then COMMANDS[command].help else "#{command}: command not found\n#{string}"
            
        @output string
    
    do_login:(service) ->
        service = "google" if not service?
        if service not in SUPPORTED_SERVICES
            return @output """#{service}: storage service not supported or disabled.
                            Available storage services: <span class="command-list">#{SUPPORTED_SERVICES.join(" ")}</span>"""
        url = "/#{service}_auth/"
        win = null
        login_success = (data, textStatus, xhr) =>
            if data.success and data.authorized
                @output "Successfully authorized for Dropbox."
                @newLine()
            else if data.success and data.auth_url
                if not win? or win.closed
                    win = window.open data.auth_url
                $.getJSON url, login_success.bind @
            else if data.success and not data.authorized
                setTimeout () => 
                    $.getJSON url, login_success.bind @
                , 1000
            else
                if not win? or win.closed
                    win = window.open "/admin/"
                setTimeout () => 
                    $.getJSON url, login_success.bind @
                , 1000

        request = $.getJSON url,login_success.bind @

        return false
    
    sendCommand:(command, data, callback) ->
        data["command"] = command
        $.post "/command/", data, callback, "json"
    
    absolutePath:(path) ->
        if (not path.startswith "/" or path.startswith "./") and not path.startswith ".."
            path = path.slice 2 if path.startswith "./"
            path = if @path.endswith("/") then "#{@path}#{path}" else "#{@path}/#{path}"
        return path
    
                
    do_cd:(path) ->
        if path == ".."
            if @path != "/"
                @path = @path.split("/").slice(0, -1).join("/")
                @path = "/" if @path is ""
            return true
            
        path = "/" if not path
        absPath = @absolutePath path
        
        @sendCommand "cd", path:absPath, (data, textStatus, xhr) =>
            if data.success
                @path = absPath
            else if not data.is_dir
                @output "cd: #{path}: Not a directory"
            else if not data.exists
                @output "cd: #{path}: No such file or directory"
            else
                @output "cd: Unknown error: #{data.error}"
            @newLine()
        return false
    
    do_mkdir:(name)->
        @sendCommand "mkdir", {"path":@path,"name":name}, (data, textStatus, xhr) =>
            if data.exists_already
                @output "mkdir: cannot create directory `#{name}': File exists"
            else if data.error
                @output "mkdir: Unknown error: #{data.error}"
            @newLine()
        return false
   
    do_ls:(path) ->
        path = if path? then @absolutePath path else @path
        @sendCommand "ls", {"path":path}, (data, textStatus, xhr) =>
            if data.error
                @output "ls: Unknown error: #{data.error}"
            else
                contents = []
                for c in data.contents
                    if c.is_dir
                        s = """<span class="directory">"""
                    else
                        s = """<span class="file">"""
                    s += "#{c.path.basename()}</span>"
                    contents.push s
                @output """<div class="command-list">#{contents.join("&nbsp;&nbsp;")}</div>"""
            @newLine()
        return false
    
    do_mv:(source, target) ->
        absSource = @absolutePath source
        absTarget = @absolutePath target
        @sendCommand "mv", {"source":absSource, "target":absTarget}, (data, textStatus, xhr) =>
            if not data.success
                if not data.source_exists
                    @output "mv: cannot stat `#{source}': No such file or directory"
                else if data.over_quota
                    @output "mv#{OVER_QUOTA_MSG}"
                else
                    @output "mv: Unknown error: #{data.error}"
            @newLine()
        return false
    
    do_cp:(args...) ->
        recursive = false
        
        if args.length == 3
            index = null
            for i in [0...args.length]
                if args[i].toLowerCase() == "-r"
                    recursive = true
                    index = i
            args.splice index, 1
        source = args[0]
        target = args[1]
                    
        absSource = @absolutePath source
        absTarget = @absolutePath target
        
        @sendCommand "cp", {"source":absSource, "target":absTarget, "recursive":recursive}, (data, textStatus, xhr) =>
            if not data.success
                if data.over_quota
                    @output "mv#{OVER_QUOTA_MSG}"
                else if not data.source_exists
                    @output "cp: Cannot stat `#{source}': No such file or directory"
                else if data.source_is_dir
                    @output "cp: Omitted directory `#{source}'"
                else
                    @output "cp: Unknown error: #{data.error}"
            @newLine()
        return false
    
    do_rm:(args...) ->
        [recursive, force] = [false, false]
        if args.length is 2
            possible = ["-r", "-f", "-rf", "-fr"]
            options = if args[0].toLowerCase() in possible then args.shift() else args.pop()
            switch options.toLowerCase()
                when "-r" then recursive = true
                when "-f" then force = true
                when "-rf","-fr" then [recursive, force] = [true, true]
            
        path = args[0]
        absPath = @absolutePath path
        @sendCommand "rm", {"force":force, "recursive":recursive, "path":absPath}, (data, textStatus, xhr) =>
            if not data.success
                if not data.target_exists
                    @output "rm: cannot remove `#{path}': No such file or directory"
                else if data.is_dir
                    @output "rm: cannot remove `#{path}': is a directory; use -R to remove."
                else 
                    @output "rm: Unknown error: #{data.error}"
            @newLine()
        return false
    
    do_download:(path) ->
        absPath = @absolutePath path
        @sendCommand "download", path:absPath, (data, textStatus, xhr) =>
            if data.success
                window.open data.url
            else if not data.exists
                @output "download: cannot download #{path}: No such file or directory"
            else
                @output "download: Unknown error: #{data.error}"
            @newLine()
        return false
    
    do_storage:(op, service) ->
        if not op? and not service?
            console.log op
            op = "get"
        else
            if op not in ["enable", "disable"]
                return @do_help "storage"
            if service not in SUPPORTED_SERVICES
                return @output "storage: Service not supported: `#{service}'"
        
        @sendCommand "storage", {"action":op, "service":service}, (data, textStatus, xhr) =>
            if not data.success
                @output "storage: Unknown error: data.error"
            else if data.success and op == "enable"
                @output "Use `login `#{service}' to authorize this app to access your account."
            else if data.services
                @output """
                Enabled services: <span class="command-list">#{data.services.join(" ")}</span>
                Use `storage disable &lt;service>` to disable."""
            @newLine()
        return false
        
$(document).ready () ->
    new Terminal()