from api_keys import DROPBOX_INFO
#from dropbox import client, session, rest
import dropbox
import time, os, pprint

class DropboxTest(object):
    _storage_path = os.path.join(os.path.dirname(__file__), "access.txt")
    def __init__(self):        
        # Create a Dropbox session with the api info from api_keys
        print "Creating session..."
        sess = dropbox.session.DropboxSession(*DROPBOX_INFO)
        if not self.stored_access_token():
            # Obtain a unique request token
            print "Obtaining request token"
            request_token = sess.obtain_request_token()
            print "Obtained:", request_token
            
            # Build the url at which users can authorize the app
            url = sess.build_authorize_url(request_token)
            print "URL:", url
            print "Please visit the URL above to authorize this app, then hit enter."
            time.sleep(1)
            print "If the above link expires, enter 'cake' below."
            resp = raw_input()
            if resp == "cake":
                print "SUCKS TO BE YOU! LOLOLOLOLOLOLOLOLOL"
            
            # The following will fail if the user did not authorize the app. Unsure what exactly it will do though.
            print "Obtaining new access token..."
            access_token = sess.obtain_access_token(request_token)
            print "Done"
            self.store_access_token(access_token)
        else:
            print "Using stored access token..."
            access_token = self.get_stored_access_token()
            sess.set_token(*access_token)
        
        print "Creating client..."
        self.client = dropbox.client.DropboxClient(sess)
        print "Linked account:"
        pprint.pprint(self.client.account_info())
        
        print "Metadata of Dropbox /:"
        pprint.pprint(self.client.metadata("/"))
        
        self.upload_test_file()
        self.download_test_file()
    
    def upload_test_file(self):
        path = raw_input("Enter path to file to upload: ")
        if os.path.isfile(path):
            with open(path) as f:
                response = self.client.put_file("/%s" % os.path.basename(path), f)
                pprint.pprint(response)
        else:
            print "Failed to upload..."
    
    def download_test_file(self):
        path = raw_input("Enter Dropbox path of file to download: ")
        response = self.client.get_file(path)
        if response.status == 200:
            new_path = os.path.join(os.path.dirname(__file__), "files", os.path.basename(path))
            with open(new_path, "w") as f:
                f.write(response.read())
                print "Wrote file contents to: ", os.path.abspath(new_path)

    def stored_access_token(self):
        return os.path.exists(self._storage_path)
    
    def store_access_token(self, token):
        with open(self._storage_path, "w") as f:
            f.write("%s|%s" % (token.key, token.secret))
    
    def get_stored_access_token(self):
        return ["xxxxx", "xxxxx"]
        with open(self._storage_path, "r") as f:
            return f.read().split("|")

if __name__ == "__main__":
    DropboxTest()