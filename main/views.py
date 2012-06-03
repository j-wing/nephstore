from django.shortcuts import render
from django.http import HttpResponse, HttpResponseForbidden, HttpResponseRedirect
from responses import JSONResponse
from dropbox_integ import DropboxAPI
from django.core.urlresolvers import reverse
from django.core.files.base import ContentFile
from django.views.decorators.csrf import ensure_csrf_cookie
from models import ServicesAPI, SERVICE_APIS


@ensure_csrf_cookie
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

def upload_frame(request):
    return render(request, "upload-frame.html")
    
def handle_upload(request):
    if request.method != "POST":
        return HttpResponse("Invalid request")
        
    path = request.GET.get("target")
    overwrite = request.GET.get("overwrite", False)
    services = request.GET.get("services", "").split(",")
    
    if not path:
        return JSONResponse({
            "success":False,
            "error":"No target path provided"
        })
    elif not len(services):
        return JSONResponse({
            "success":False,
            "error":"No services provided"
        })
    
    user_services = request.user.credentials.enabled_services
    for service in services:
        if service not in user_services:
            return JSONResponse({
                "success":False,
                "error":"Service '%s' is not enabled. \
                        Either remove it from the list of target services, or enable it with 'storage enable %s' before continuing. "
            })
    
    resp = {
        "success":True,
        "results":[]
    }
    for service in services:
        resp['results'].append({
            "service":service,
            "result":SERVICE_APIS[service](request).upload(path=path, overwrite=overwrite, file=ContentFile(request.body))
        })
    return JSONResponse(resp)
    
def command(request):
    if request.user.is_anonymous():
        return HttpResponseForbidden("Please login before attempting a command")
    
    services = request.user.credentials.enabled_services
    api = ServicesAPI(request, services)
    
    data = dict(request.POST.copy())
    for key, value in data.items():
        if len(value) == 1:
            data[key] = value[0]
            
    command = data.pop("command")
    resp = api.exec_command(command, **data)
    return JSONResponse(resp)