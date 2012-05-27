from api_keys import DROPBOX_INFO
import dropbox
from dropbox.rest import ErrorResponse
import time, os, pprint, logging
from django.core.urlresolvers import reverse

class DropboxAPI(object):
    def __init__(self, request):
        self.request = request
    
    def authorization_required(self):
        if self.request.user.is_anonymous(): return True
        
        return not (self.request.user.credentials.dropbox_authorized)
        
    def get_auth_url(self):
        sess = dropbox.session.DropboxSession(*DROPBOX_INFO)
        request_token = sess.obtain_request_token()
        
        self.request.session['dropbox_token_secret'] = request_token.secret
        self.request.session['dropbox_token_key'] = request_token.key
        url = sess.build_authorize_url(request_token, self.request.build_absolute_uri(reverse("main:dropbox_auth2")))
        return url
    
    def second_step_auth(self):
        request_token = self.request.GET.get("oauth_token", None)
        
        if not request_token:
            return False
            
        session_key = self.request.session['dropbox_token_key']
        session_secret = self.request.session['dropbox_token_secret']
        
        if session_key != request_token:
            return False
            
        sess = dropbox.session.DropboxSession(*DROPBOX_INFO)

        sess.set_request_token(session_key, session_secret)
        access_token = sess.obtain_access_token()
        if not access_token:
            return False
        
        creds = self.request.user.credentials
        creds.dropbox_authorized = True
        creds.dropbox_access = access_token
        creds.save()
        
        del self.request.session['dropbox_token_key']
        del self.request.session['dropbox_token_secret']
        
        return True
    
    def _init_client(self):
        access_token = self.request.user.credentials.dropbox_access
        
        sess = dropbox.session.DropboxSession(*DROPBOX_INFO)
        sess.set_token(*access_token)
        client = dropbox.client.DropboxClient(sess)
        return client
        
    def cd(self, path):
        path = path
        client = self._init_client()
        
        success,exists,is_dir, data = True, True,True,[]
        try:
            meta = client.metadata(path)
        except ErrorResponse as e:
            exists = False
            success = False
        else:
            if not meta['is_dir']:
                is_dir = False
                success = False
            else:
                data = meta['contents']
        return {
            "success":success,
            "exists":exists,
            "is_dir":is_dir,
            "data":data
        }
    
    def mkdir(self, path, name):
        full_path = os.path.join(path, name)
        client = self._init_client()
        
        data = {
            "success":True,
            "exists_already":False,
            "error":"",
            "full_path":""
        }
        
        try:
            meta = client.file_create_folder(full_path)
        except ErrorResponse as e:
            if e.status == 403:
                data['success'] = False
                data['exists_already'] = True
            else:
                data['success'] = False
                data['error'] = e.error_msg
        else:
            data['full_path'] = meta['path']
        return data
    
    def ls(self, path):
        client = self._init_client()
        
        data = {
            "success":True,
            "error":"",
            "contents":[]
        }
        
        try:
            meta = client.metadata(path)
        except ErrorResponse as e:
            data['success'] = False
            data['error'] = e.error_msg
        else:
            print meta
            if meta['is_dir']:
                data['contents'] = meta['contents']
            else:
                data['contents'] = [{"path":os.path.basename(path)}]
        return data
    def exec_command(self, command, *args, **kwargs):
        if command == "cd": return self.cd(**kwargs)
        elif command == "mkdir": return self.mkdir(**kwargs)
        elif command == "ls":return self.ls(**kwargs)