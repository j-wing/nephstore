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
        
        if path == "/":
            
            data = {
                "success":True,
                "contents":self.get_root_contents()
            }
        else:
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
    
    def mv(self, source, target):
        client = self._init_client()
        
        data = {
            "success":True,
            "newPath":"",
            "error":"",
            "over_quota":False,
            "source_exists":True
        }
        
        target = self._target_to_full_name(client, source, target)
                
        try:
            meta = client.file_move(source, target)
        except ErrorResponse as e:
            if e.status == 404:
                data['success'] = False
                data['source_exists'] = False
            elif e.status == 503:
                data['success'] = False
                data['over_quota'] = True
            else:
                data['success'] = False
                data['error'] = e.error_msg
        else:
            data['newPath'] = meta['path']
        return data
    
    def _target_to_full_name(self, client, source, target):
        try:
            meta = client.metadata(target)
        except ErrorResponse:
            pass
        else:
            if meta['is_dir']:
                return os.path.join(target, os.path.basename(source))
        return target
    
    def cp(self, source, target, recursive):
        if recursive == 'false':
            recursive = False
        client = self._init_client()
        
        data = {
            "success":True,
            "newPath":"",
            "error":"",
            "over_quota":False,
            "source_exists":True,
            "source_is_dir":False
        }
        
        try:
            meta = client.metadata(source)
        except ErrorResponse:
            data['success'] = False
            data['source_exists'] = False
        else:
            if meta['is_dir'] and not recursive:
                data['success'] = False
                data['source_is_dir'] = True
        
        
        if data['success']:
            target = self._target_to_full_name(client, source, target)
            try:
                meta = client.file_copy(source, target)
            except ErrorResponse as e:
                data['success'] = False
                if e.status == 404:
                    data['source_exists'] = False
                elif e.status == 503:
                    data['over_quota'] = True
                else:
                    data['error'] = e.error_msg
            else:
                data['newPath'] = meta['path']
        return data
    
    def rm(self, path, recursive, force):
        recursive = False if recursive == "false" else True
        force = False if force == "false" else True
        
        client = self._init_client()
        
        data = {
            "success":True,
            "error":"",
            "target_exists":True,
            "is_dir":False
        }
        
        try:
            meta = client.metadata(path)
        except ErrorResponse:
            data['success'] = False
            data['target_exists'] = False
        else:
            if meta['is_dir'] and not recursive:
                data['success'] = False
                data['is_dir'] = True
        
        if data['success']:
            try:
                meta = client.file_delete(path)
            except ErrorResponse as e:
                if e.status == 404:
                    data['success'] = False
                    data['target_exists'] = False
                else:
                    data['success'] = False
                    data['error'] = e.error_msg
        return data
    
    def download(self, path):
        client = self._init_client()
        
        data = {
            "success":True,
            "url":"",
            "error":"",
            "exists":True
        }
        
        try:
            meta = client.share(path)
        except ErrorResponse as e:
            data['success'] = False
            if e.status == 404:
                data['exists'] = False
            else:
                data['error'] = e.error_msg
        else:
            data['url'] = meta['url']
        
        return data
                
    def exec_command(self, command, *args, **kwargs):
        if self.authorization_required():
            return {
                "success":False,
                "error":"Please authorize this app to use Dropbox by running `login dropbox`",
                "is_dir":True,
                "exists":True
            }
            
        if command == "cd": return self.cd(**kwargs)
        elif command == "mkdir": return self.mkdir(**kwargs)
        elif command == "ls":return self.ls(**kwargs)
        elif command == "mv": return self.mv(**kwargs)
        elif command == "cp": return self.cp(**kwargs)
        elif command == "rm": return self.rm(**kwargs)
        elif command == "download": return self.download(**kwargs)