"""
    Google OpenID auth backend.
    
    Thanks to Hangya: http://djangosnippets.org/snippets/2183/
"""

from django.contrib.auth.models import User
from openid.consumer.consumer import SUCCESS
from django.conf import settings

class GoogleBackend:

  def authenticate(self, openid_response):
    if openid_response is None:
      return None
    if openid_response.status != SUCCESS:
      return None
    
    google_email = openid_response.getSigned('http://openid.net/srv/ax/1.0', 'value.email')
    google_firstname = openid_response.getSigned('http://openid.net/srv/ax/1.0', 'value.firstname')
    google_lastname = openid_response.getSigned('http://openid.net/srv/ax/1.0', 'value.lastname')
    try:
      user = User.objects.get(username=google_email)
    except User.DoesNotExist:
        # Default pass defined in secrets.py
        user = User.objects.create_user(google_email, google_email, settings.DEFAULT_USER_PASSWORD)
        user.first_name = google_firstname
        user.last_name = google_lastname
        user.is_active = True
        user.save()

    return user

  def get_user(self, user_id):

    try:
      return User.objects.get(pk=user_id)
    except User.DoesNotExist:
      return None
