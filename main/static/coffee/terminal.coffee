COMMANDS = 
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
        "options":
            "recursive":
                "type":"bool"
                "longForm":"recursive"
                "shortForm":"r"
                "default":false
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
            Logs you out NephStore. You will need log back in via OpenID to continue using NephStore. 
            """
    "ls":
        "args":[0,1]
        "help":"""
                Usage: ls [DIRECTORY]
                List information about DIRECTORY (the current directory by default).
                """
    "mkdir":
        "args":[1,2]
        "help":"""
            Usage: mkdir NAME
            Creates a directory 'NAME' in the current working directory.
            """
    "mv":
        "args":[2]
        "help":"""
                Usage: mv [SOURCE] [DEST]
                or:    mv [SOURCE] [DIRECTORY]
                Rename SOURCE to DEST, or move SOURCE(s) to DIRECTORY.
                """
    "rm":
        "args":[1,2,3]
        "help":"""
        Usage: rm [-rf] FILE
        Removes FILE.
        -R, -r: Removes FILE recursively, removing all files within FILE if it is a directory.
        -f: Never prompt for confirmation
        """
        "options":
            "force":
                "type":"bool"
                "longForm":"force"
                "shortForm":"f"
                "default":false
            "recursive":
                "type":"bool"
                "longForm":"recursive"
                "shortForm":"r"
                "default":false
    "storage":
        "args":[0, 2]
        "help":"""
            Usage: storage [enable or disable] [SERVICE]
            View and enable or disable storage methods. SERVICE should be one of: "dropbox", "google"
            """
    "upload":
        "args":[1, 2, 3]
        "help":"""
                Usage: upload TARGET_PATH [--services=dropbox,google] [--overwrite]
                Brings up the upload dialog box to upload a file.
                TARGET_PATH: Path of the resulting file on the target services.
                -s, --services: Comma-separated list of services to upload the file to.
                -o, --overwrite: Overwrite an existing file of the same.
                """
        "options":
            "overwrite":
                "type":"bool"
                "longForm":"overwrite"
                "shortForm":"o"
                "default":false
            "services":
                "type":"list"
                "longForm":"services"
                "shortForm":"s"
                "default":["dropbox", "google"]

SUPPORTED_SERVICES = [
    "dropbox"
    "google"
]

WELCOME_MESSAGE = """
<div class="welcome-message">
Welcome to NephStore.

To begin, login via OpenID to a Google account. Click the link below to do so. 
- Once the terminal is available, use the `storage` command to enable and disable storage services. By default, no service is enabled. 
- Once you've enabled a service(s), use `login &lt;service name&gt;` for each service you enable to authorize Nephstore to access your account.
- Then, you can navigate the filesystem using standard Unix terminal commands, as well as use the `upload` and `download &lt;path&gt;` commands.
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

class Options
    ###
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
        
        Usage:
            Call the constructor with options in the format described above.
            
            `options = new Options COMMANDS['command']['options']`
            
            Then call proccessOptions, which returns any unknown or unidentified arguments.
            `args = options.processOptions args`
    ###
        
    constructor:(@options) ->
    
    stripArgs:(args) ->
        return (arg for arg in args when (arg.startswith "-")) or []
        
    _getSwitchIndex:(long, short, args) ->
        i = args.indexOf "--#{long}"
        
        if i >= 0
            return i
        else
            # Short switches can have multiple combined in one
            i = 0
            matchedIndex = -1
            for arg in args
                i++
                if arg.startswith("-") and arg.toLowerCase().indexOf(short) >= 0
                    matchedIndex = i
                    break
            return matchedIndex
    
    _getAssignedArgIndex:(long, short, args) ->
        for i in [0...args.length]
            return i if (args[i].startswith("--#{long}") or args[i].startswith("-#{short}"))
        return -1
        
    processOptions:(oargs) ->
        args = @stripArgs oargs
        parsedIndices = []
        
        for name, data of @options
            switch data.type
                when "bool"
                    i = @_getSwitchIndex data.longForm, data.shortForm, args
                    if i >= 0
                        parsedIndices.push i
                        @[name] = (not data["default"])
                    else
                        @[name] = data['default']
                when "list"
#                     r = new RegExp "(?:(?:--#{data.longForm}|-#{data.shortForm})=)((\\w+)(?:,*(\\w+)))", "g"
                    i = @_getAssignedArgIndex data.longForm, data.shortForm, args
                    if i >= 0
                        try 
                            list = args[i].split("=")[1].split(",")
                        catch e
                            @[name] = data['default']
                            break
                        @[name] = list
                        parsedIndices.push i
                    else
                        @[name] = data['default']
                when "var"
                    i = @_getAssignedArgIndex data.longForm, data.shortForm, args
                    if i >= 0
                        @[name] = args[i]
                        parsedIndices.push i
                    else
                        @[name] = data['default']
        
        # Eliminate args that were parsed out
        for i in $.unique parsedIndices
            oargs.splice oargs.indexOf(args[i]), 1
        return oargs
        
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
        @cursorMoving = 0
        
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
            # Ctrl+C
            interrupt = (e.which == 67 and e.ctrlKey)
            if @promptHandler and not interrupt
                @promptHandler e
            
            else if interrupt
                @keyboardInterrupt()
                
            # Return key
            else if e.which == 13
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
                @updateCursorPosition()

    absolutePath:(path) ->
        if (not path.startswith "/" or path.startswith "./") and not path.startswith ".."
            path = path.slice 2 if path.startswith "./"
            path = if @path.endswith("/") then "#{@path}#{path}" else "#{@path}/#{path}"
        return normpath path

    blinkCursor:() ->
        if @cursorMoving == 0
            $("#cursor").toggleClass("hidden")
        setTimeout @blinkCursor.bind(@),750
    
    createCursor:() ->
        div = $ document.createElement "div"
        div.attr "id", "cursor-wrapper"
        
        cdiv = $(document.createElement("span")).html("&nbsp;").attr("id","cursor").appendTo(div)
        return div

    createEntryElement:()->
        span = $ document.createElement "span"
        span.attr("id", "active-entry")
    
    forceOpenIDLogin:() ->
        $(".welcome-message").after $ """<span>OpenID Login: <a href="#{@user.loginURL}">#{@user.loginURL}</a></span>"""

    keyboardInterrupt:() ->
        $("#entry").val("")
        @newLine()
        throw new Error "KeyboardInterrupt"
    
    newLine:() ->
        $("#active-entry,#active-line").attr("id", "")
        $("#cursor-wrapper").remove()
        
        entry = @createEntryElement()
        text = "[#{@user.name.toLowerCase()}@nephstore]:#{@path}$ "
        cursor = @createCursor()
        
        div = $ document.createElement "div" 
        div.addClass("line").attr("id", "active-line").append(text).append(entry).append(cursor)
        $("#terminal").append div
        div[0].scrollIntoViewIfNeeded()
        @setEntryEnabled true
        @promptHandler = null
    
    output:(html, append, keepNewLines) ->
        div = $(document.createElement("div")).addClass("output")
        if keepNewLines or typeof html != "string" then div.html html else div.html html.replace /\n/g, "<br />"
        
        if append
            $("#terminal").append html
        else 
            $("#active-line").after div
        $("#cursor-wrapper").insertAfter div
            
    processCurrentLine:()->
        @setEntryEnabled false
        input = $("#entry").val().trim()
        
        if input is ""
            return @newLine()
        
        @stack.push input
        
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
        
    recallCommand:(previous) ->
        command = if previous then @stack.previous() else @stack.next()
        if command != null
            @setCommand command,true
    
    sendCommand:(command, data, callback) ->
        data["command"] = command
        $.post "/command/", data, callback, "json"

    setCommand:(command, copyToInput) ->
        $("#active-entry").html command.replace(/\s/g,"&nbsp;").replace(/</g, "&lt;")
        $("#entry").val command if copyToInput
    
    setEntryEnabled:(enabled) ->
        if enabled then $("#entry").removeAttr("disabled") else $("#entry").attr("disabled", "disabled")    
    
    updateCursorPosition:() ->
        @cursorMoving = 1
        $("#cursor").removeClass("hidden")
        clearTimeout @cursorTimer
        
        elem = $("#entry")[0]
        caretIndex = elem.selectionStart
        cursorIndex = ((caretIndex) - elem.value.length) * 10
        
        $("#cursor-wrapper").css("left", "#{cursorIndex}px")
        @cursorMoving = 2
        @cursorTimer = setTimeout () =>
            @cursorMoving = 0 if @cursorMoving == 2
        , 300

    do_cd:(path) ->
        path = "/" if not path
        absPath = @absolutePath path
        
        if absPath == "/"
            return true
        
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
        
    do_cp:(args...) ->
        options = new Options COMMANDS['cp']['options']
        
        [source, target] = options.processOptions args
        
        if not (source and target)
            return @output "cp:  missing destination file operand after `#{source}'\nTry help cp for more information"
        
        absSource = @absolutePath source
        absTarget = @absolutePath target
        
        @sendCommand "cp", {"source":absSource, "target":absTarget, "recursive":options.recursive}, (data, textStatus, xhr) =>
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

    do_logout:() ->
        window.location.href = "/logout/"

    do_ls:(path) ->
        path = if path? then @absolutePath path else @path
        @sendCommand "ls", {"path":path}, (data, textStatus, xhr) =>
            if data.error
                @output "ls: Unknown error: #{data.error}"
            else
                contents = []
                
                elem = if data.contents.length > 15 then "div" else "span"
                for c in data.contents
                    if c.is_dir
                        s = """<#{elem} class="directory">"""
                    else
                        s = """<#{elem} class="file">"""
                    s += "#{c.path.basename()}</span>"
                    contents.push s
                @output """<div class="command-list">#{contents.join("&nbsp;&nbsp;")}</div>"""
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
    
    
    do_rm:(args...) ->
        options = new Options COMMANDS['rm']['options']
        
        [path] = options.processOptions args
        
        if not path
            return @output "rm: missing operand"
            
        absPath = @absolutePath path
        @sendCommand "rm", {"force":options.force, "recursive":options.recursive, "path":absPath}, (data, textStatus, xhr) =>
            if not data.success
                if not data.target_exists
                    @output "rm: cannot remove `#{path}': No such file or directory"
                else if data.is_dir
                    @output "rm: cannot remove `#{path}': is a directory; use -R to remove."
                else 
                    @output "rm: Unknown error: #{data.error}"
            @newLine()
        return false
    
    
    do_storage:(op, service) ->
        if not op? and not service?
            op = "get"
        else
            if op not in ["enable", "disable"]
                return @do_help "storage"
            if service not in SUPPORTED_SERVICES
                return @output "storage: Service not supported: `#{service}'"
        
        @sendCommand "storage", {"action":op, "service":service}, (data, textStatus, xhr) =>
            if not data.success
                @output "storage: Unknown error: #{data.error}"
            else if data.success and op == "enable"
                @output "Successfully enabled #{service}.\nUse `login `#{service}' to authorize this app to access your account."
            else if data.services
                @output """
                Enabled services: <span class="command-list">#{data.services.join(" ")}</span>
                Available services: <span class="command-list">#{SUPPORTED_SERVICES.join(" ")}</span>
                Use `storage disable &lt;service>` to disable."""
            @newLine()
        return false
        
    _uploadFile:(fileInput, successHandler) ->
        data = fileInput.dataset
        xhr = new XMLHttpRequest()
        terminal = $("#terminal")
        percent = $(document.createElement("span")).addClass("upload-percent").html("0%&nbsp;").appendTo terminal
        hashes = $(document.createElement("span")).addClass("upload-hashes").appendTo terminal
        
        xhr.upload.addEventListener "progress", (e) =>
            if e.lengthComputable
                p = Math.round((e.loaded * 100) / e.total)
                percent.html "#{p}%&nbsp;"
                hashes.text "#".repeat p
                
        xhr.addEventListener "load", (e) =>
            percent.html "100%&nbsp;"
            hashes.text "#".repeat 100
            @output "<br />Complete.<br />", true
            successHandler(e)
        
        xhr.open "POST", "/upload/?overwrite=#{data.overwrite}&services=#{data.services}&target=#{data.target}", true
        xhr.setRequestHeader "X-CSRFToken", $.cookie 'csrftoken'
        xhr.send fileInput.files[0]
        
        
    do_upload:(args...) ->
        options = new Options COMMANDS.upload.options
        
        target = options.processOptions(args)[0]
        if not target
            return @outputError "upload: Invalid target path"
        
        for service in options.services
            if service not in SUPPORTED_SERVICES
                return @outputError "upload: service not supported: `#{service}'"
        @setEntryEnabled true
        
        successHandler = (e) =>
            json = JSON.parse e.target.responseText
            if json.success
                results = []
                for result in json.results
                    s = "#{result.service.capitalize()}: "
                    if result.result.success
                        s += "Successful."
                    else
                        s += "Failed: #{result.result.error}"
                    results.push s
                @output results.join("<br />"), true
            else
                @output "upload: Failed to upload: #{json.error}"
            @newLine()
        
        @promptHandler = (e) =>
            if e.which == 13
                lastUpload = $(".file-upload").slice(-1)[0]
                @_uploadFile lastUpload, successHandler
            
        @output """
        Select the file to upload below, then hit enter:
<input type="file" name="file" class="file-upload" data-overwrite="#{options.overwrite}" data-services="#{options.services.join(",")}" data-target="#{target}" />
        
        """
        
        $(".file-upload").change (e) =>
            $("#entry")[0].focus()
        return false
$(document).ready () ->
    new Terminal()