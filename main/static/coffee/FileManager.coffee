class EntryList
    # Data format:
#     {
#         "name":"/",
#         "is_file":false,
#         "entries":[
#             {
#                 "name":"File1.py",
#                 "is_file":true,
#             },
#             {
#                 "name":"Dir1",
#                 "is_file":false,
#                 "entries":[]
#             }
#         ]
#     }
    constructor:(@files) ->
        
        @entries = []
        @element = @createElement()
        for file in @files
            entry = new Entry file
            @entries.push entry
            @element.append entry.element
    
    createElement:() ->
        return $(document.createElement("ul")).addClass("file-entry-sub")
class Entry
    constructor:(@fileInfo) ->
        @name = @fileInfo.name
        @is_file = @fileInfo.is_file
        @ext = @name.split(".")[-1] if @is_file
        @entries = new EntryList @fileInfo.entries if not @is_file
        
        @element = @createElement()
        @element.text @name
        @element.append @entries.element if not @is_file
        
        _this = @
        @element.click (e) ->
            _this.element.toggleClass "expanded" if not _this.is_file and e.target == @
    createElement:() ->
        elem = $(document.createElement("li")).addClass("file-tree-entry")
        if @is_file then elem.addClass("file-entry") else elem.addClass("directory")
        

class window.FileManager
    constructor:(@files, @element) ->
        @element = $(document.createElement("div")).addClass("file-tree") if not @element
        
        if @files.toString() is not "[object Object]"
            # JSON data
            @files = JSON.parse(files)
        
        rootEntry = new Entry(
            "name":"/",
            "is_file":false,
            "entries":@files
        )
        @element.append rootEntry.element

    
        