String.prototype.startswith = (string) ->
    return (@.slice(0, string.length) is string)
String.prototype.endswith = (string) ->
    return (@.slice(-(string.length)) is string)
String.prototype.basename = () ->
    return @.split("/").splice(-1)