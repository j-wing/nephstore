from django.http import HttpResponse
from django.utils import simplejson

class JSONResponse(HttpResponse):
    def __init__(self, data, *args, **kwargs):
        kwargs['mimetype'] = kwargs.get("mimetype", "application/x-json")
        super(JSONResponse, self).__init__(*args, **kwargs)
        
        self.write_json(data)
    
    def write_json(self, data):
        self.write(simplejson.dumps(data))