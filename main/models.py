from django.db import models
from oauth2client.django_orm import FlowField, CredentialsField
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
import dropbox
from dropbox_integ import DropboxAPI
import ast
import oauth.oauth as oauth

SERVICE_APIS = {
    "dropbox":DropboxAPI,
    "google":""
}

class ServicesAPI(object):
    
    def __init__(self, request, services):
        self.request = request
        self.services = services
    
    def get_api_from_path(self, path):
        for name, api in SERVICE_APIS.items():
            if path.startswith("/%s" % name):
                return (name, api)
        return (None, None)
    
    def modify_services(self, action, service=None):
        if action == "get":
            return {
                "success":True,
                "services":self.request.user.credentials.enabled_services
            }
        elif service in SERVICE_APIS and action in ['enable', 'disable']:
            creds = self.request.user.credentials
            s = creds.enabled_services
            if action == "enable":
                if service not in creds.enabled_services:
                    s.append(service)
                    creds.enabled_services = s
                    creds.save()
            else:
                try:
                    s.remove(service)
                except ValueError:
                    pass
                else:
                    creds.enabled_services = s
                    creds.save()
            return {
                "success":True
            }
        else:
            return {
                "success":False,
                "error":"Invalid parameters."
            }
    def exec_command(self, command, *args, **kwargs):
        if command == "storage":
            return self.modify_services(*args, **kwargs)
        path = kwargs.get("path")
        source = kwargs.get("source")
        target = kwargs.get("target")
        
        api = None
        
        if path:
            if path == "/":
                if command == "ls":
                    return {
                        "success":True,
                        "contents":self.get_root_contents()
                    }
                elif command == "cd":
                    return {
                        "success":True,
                        "exists":True,
                        "is_dir":True
                    }
                
            else:
                name,api = self.get_api_from_path(path)
                if name:
                    kwargs['path'] = kwargs['path'][len(name)+1:]
        elif source and target:
            if source.count("/") == 1 or target.count("/") == 1:
                return {
                    "success":False,
                    "error":"Cannot perform modification operations to service directories"
                }
                
            (src_name, api) = self.get_api_from_path(source)
            (target_name, target_api) = self.get_api_from_path(target)
            
            if api is not target_api:
                return {
                    "success":False,
                    "error":"Performing operations between services is not yet supported."
                }
            elif src_name and target_name:
                kwargs['source'] = kwargs['source'][len(src_name)+1:]
                kwargs['target'] = kwargs['target'][len(target_name)+1:]
                
        if api:
            return api(self.request).exec_command(command, *args, **kwargs)
        else:
            return {
                "success":False,
                "error":"Unrecognized service."
            }

    def get_root_contents(self):
        l = [{"path":"/%s" % name} for name in self.services]
        l.append({"path":"/home"})
        l.sort()
        return l


@receiver(post_save, sender=User)
def create_credentials(sender, **kwargs):
    if kwargs.get("created", True):
        creds = UserAccessCredentials(user=kwargs.get("instance"))
        creds.save()
class DropboxTokenField(models.Field):
    __metaclass__ = models.SubfieldBase
    
    def get_internal_type(self):
        return "TextField"
    
    def to_python(self, value=None):
        if not value:
            return None
        if isinstance(value, oauth.OAuthToken):
            return "%s|%s" % (value.key, value.secret)
        elif isinstance(value, list):
            return value
        else:
            return value.split("|")
        return value
    def get_db_prep_value(self, value, connection, prepared=False):
        if isinstance(value, oauth.OAuthToken):
            return "%s|%s" % (value.key, value.secret)
        elif isinstance(value, list):
            return "|".join(value)
        return value

class ListField(models.TextField):
    __metaclass__ = models.SubfieldBase
    description = "Stores a python list"

    def __init__(self, *args, **kwargs):
        super(ListField, self).__init__(*args, **kwargs)

    def to_python(self, value):
        if not value:
            value = []

        if isinstance(value, list):
            return value

        return ast.literal_eval(value)

    def get_prep_value(self, value):
        if value is None:
            return value

        return unicode(value)

    def value_to_string(self, obj):
        value = self._get_val_from_obj(obj)
        return self.get_db_prep_value(value)

class GoogFlow(models.Model):
    id = models.ForeignKey(User, primary_key=True)
    flow = FlowField()

class UserAccessCredentials(models.Model):
    user = models.OneToOneField(User, related_name="credentials")
    dropbox_authorized = models.BooleanField(default=False)
    dropbox_access = DropboxTokenField(null=True, blank=True)
    
    google_authorized = models.BooleanField(default=False)
    google_access = CredentialsField(null=True, blank=True)
    
    # See services.py for the codes for each services
    enabled_services = ListField()
    
    class Meta:
        verbose_name_plural = "user access credentials"
    
    def __unicode__(self):
        return "Credentials for %s" % self.user.username
        
