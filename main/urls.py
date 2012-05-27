from django.conf.urls.defaults import patterns, include, url

urlpatterns = patterns('nephstore.main.views',
    url(r'^$', "index", name="index"),
    url(r'^user/get/$', 'user_info', name="user_info"),
    url(r'^dropbox_auth/$', 'dropbox_step1', name="dropbox_auth1"),
    url(r'^dropbox_oauth2_callback/$', 'dropbox_step2', name="dropbox_auth2"),
)
