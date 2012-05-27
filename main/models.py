from django.db import models
from oauth2client.django_orm import FlowField, CredentialsField
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver
import dropbox

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
class GoogFlow(models.Model):
    id = models.ForeignKey(User, primary_key=True)
    flow = FlowField()

class UserAccessCredentials(models.Model):
    user = models.OneToOneField(User, related_name="credentials")
    dropbox_enabled = models.BooleanField(default=False)
    dropbox_authorized = models.BooleanField(default=False)
    dropbox_access = DropboxTokenField(null=True, blank=True)
    
    google_enabled = models.BooleanField(default=False)
    google_authorized = models.BooleanField(default=False)
    google_access = CredentialsField(null=True, blank=True)
    
    class Meta:
        verbose_name_plural = "user access credentials"
    
    def __unicode__(self):
        return "Credentials for %s" % self.user.username
        
