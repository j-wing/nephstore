from django.db import models
from oauth2client.django_orm import FlowField, CredentialsField
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
import dropbox
from dropbox_integ import DropboxAPI
import ast

SERVICE_APIS = {
    "dropbox":DropboxAPI
}

class ServicesAPI(object):
    
    def __init__(self, request, services):
        self.request = request
        self.services = [api(request) for name, api in SERVICE_APIS.items() if name in services]
        
    def exec_command(self, command, *args, **kwargs):
        responses = []
        for service in self.services:
            responses.append(service.exec_command(command, *args, **kwargs))
        return responses


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
        if isinstance(value, dropbox.session.OAuthToken):
            return "%s|%s" % (value.key, value.secret)
        elif isinstance(value, list):
            return value
        else:
            return value.split("|")
        return value
    def get_db_prep_value(self, value, connection, prepared=False):
        if isinstance(value, dropbox.session.OAuthToken):
            return "%s|%s" % (value.key, value.secret)
        elif isinstance(value, list):
            return "|".join(list)
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
        
