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
            View and enable or disable storage methods.
            Usage: storage [enable or disable] [SERVICE]
            Where SERVICE is either "dropbox" or "drive".
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
            Usage: logout [SERVICE]
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

class Events
    # Mixin to be used by other classes
    # Implements event hooking/firing
    
    hook:(name, handler)->
        @_events = {} unless @_events?
        @_events[name] = [] unless @_events[name]?
        
        @_events[name].push handler
    
    fire:(name, args...) ->
        handler(args...) for handler in @_events[name] if (@_events? and @_events[name]?)


class CommandStack
    constructor:() ->
        @stack = []
        @index = -1
    
    reset:() ->
        @index = -1
    
    empty:(reset) ->
        @stack = []
        @reset() if reset or not reset?
    
    push:(command) ->
        @stack.splice 0, 0, command
    
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
        input = $("#entry").val().trim()
        
        if input is ""
            return @newLine()
        
        @stack.push input
        
        #TODO Do not match escaped spaces!
        [command,args...] = input.split " "
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
    do_cd:(path) ->
        path = "/" if not path
        @path = path
    
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
        @output "..."
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
$(document).ready () ->
    new Terminal()