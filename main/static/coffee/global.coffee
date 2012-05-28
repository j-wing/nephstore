String.prototype.startswith = (string) ->
    return (@slice(0, string.length) is string)
String.prototype.endswith = (string) ->
    return (@slice(-(string.length)) is string)
String.prototype.basename = () ->
    return @split("/").splice(-1)
String.prototype.splitUnescapedSpaces = () ->
    spaces = @split " "
    resp = []
    for i in [0...spaces.length]
        if spaces.slice(i-1)[0] && spaces.slice(i-1)[0].endswith "\\"
            prev = resp.pop -1
            resp.push "#{prev.slice(0,-1)} #{spaces[i]}"
        else
            resp.push spaces[i]
    return resp
