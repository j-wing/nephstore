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
