from api_keys import DROPBOX_INFO
import dropbox
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