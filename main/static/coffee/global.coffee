String.prototype.startswith = (string) ->
    return (@slice(0, string.length) is string)
String.prototype.endswith = (string) ->
    return (@slice(-(string.length)) is string)
String.prototype.basename = () ->
    return @split("/").splice(-1)
String.prototype.capitalize = () ->
    split = @split(" ")
    for i in [0...split.length]
        split[i] = split[i][0].toUpperCase() + split[i][1...]
    return split.join(" ")
String.prototype.splitUnescapedSpaces = () ->
    spaces = @split " "
    resp = []
    for i in [0...spaces.length]
        if spaces.slice(i-1)[0] && spaces.slice(i-1)[0].endswith "\\"
            prev = resp.pop()
            resp.push "#{prev.slice(0,-1)} #{spaces[i]}"
        else
            resp.push spaces[i]
    return resp
String.prototype.repeat = (num) ->
    return new Array(num + 1).join @

window.normpath = (path) ->
    # Normalize path, eliminating double slashes, etc.
    # Adapted from the Python stdlib
    
    [slash, dot] = ['/', '.']
    if path == ''
        return path
        
    initial_slashes = path.startswith('/')
    # POSIX allows one or two initial slashes, but treats three or more
    # as single slash.
    if (initial_slashes and path.startswith('//') and not path.startswith('///'))
        initial_slashes = 2
    comps = path.split('/')
    new_comps = []
    for comp in comps
        if comp in ['', '.']
            continue
        if (comp != '..' or (not initial_slashes and not new_comps) or (new_comps and new_comps.slice(-1) == '..'))
            new_comps.push(comp)
        else if new_comps
            new_comps.pop()
    comps = new_comps
    path = comps.join(slash)
    if initial_slashes
        path = slash.repeat(initial_slashes) + path
    return path or dot
