from django.shortcuts import render
from django.http import HttpResponse
from responses import JSONResponse
from dropbox_integ import DropboxAPI
from django.core.urlresolvers import reverse
from django.views.decorators.csrf import ensure_csrf_cookie

@ensure_csrf_cookie()
def index(request):
    return render(request, "terminal.html")

def user_info(request):
    authenticated = request.user.is_authenticated()
    data = {
        "success":True,
        "authenticated":authenticated
    }
    if authenticated:
        data['userInformation'] = {
            "uid":request.user.pk,
            "first_name":request.user.first_name,
            "email":request.user.username
        }
    else:
        data['loginURL'] = request.build_absolute_uri(reverse("openid-login"))
    return JSONResponse(data)

def dropbox_step1(request):
    if request.user.is_anonymous():
        return JSONResponse({"success":False, "error":"no_user"})
    
    api = DropboxAPI(request)
    required = api.authorization_required()
    
    if request.session.get('dropbox_token_key'):
        data = {
            "success":True,
            "authorized":False
        }
        
    elif required:
        url = api.get_auth_url()
        data = {
                "success":True,
                "auth_url":url
        }
    else:
        data = {
            "success":True,
            "authorized":True,
        }
    return JSONResponse(data)
        
    
def dropbox_step2(request):
    api = DropboxAPI(request)
    ret = api.second_step_auth()
    if not ret:
        return HttpResponseRedirect(reverse("main:dropbox_auth1"))
    return HttpResponse("You may now close this window.")