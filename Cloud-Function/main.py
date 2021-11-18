# Copyright 2021 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys
from google.auth.transport.requests import Request
from google.oauth2 import id_token
import requests
import os

IAM_SCOPE = 'https://www.googleapis.com/auth/iam'
OAUTH_TOKEN_URI = 'https://www.googleapis.com/oauth2/v4/token'
env_project_id=os.environ["env_project_id"] 
env_location=os.environ["env_location"] 
env_composer_environment=os.environ["env_composer_environment"] 
env_composer_url=os.environ["env_composer_url"] 
env_dag_name=os.environ["env_dag_name"] 

# Monitors storage for uploaded files named "end_file.txt"
# This is a marker file that will trigger a Cloud Composer to process the file
def customerUploadTrigger(event, context):
    print('BEGIN: Cloud Function Executing for File: {}'.format(event['name']))
    fileName = event['name']

    if fileName.endswith('end_file.txt'):
        print('Event ID: {}'.format(context.event_id))
        print('Event type: {}'.format(context.event_type))
        print('Bucket: {}'.format(event['bucket']))
        print('File: {}'.format(event['name']))
        print('Metageneration: {}'.format(event['metageneration']))
        print('Created: {}'.format(event['timeCreated']))
        print('Updated: {}'.format(event['updated']))
        print('Calling Cloud Composer')
        print('env_project_id: {}'.format(env_project_id))
        print('env_location: {}'.format(env_location))
        print('env_composer_environment: {}'.format(env_composer_environment))
        print('env_composer_url: {}'.format(env_composer_url))
        print('env_dag_name: {}'.format(env_dag_name))
        data = { "filename" : fileName } 
        trigger_dag(data=data)

    print('END: Cloud Function Executing for File: {}'.format(event['name']))



# https://cloud.google.com/composer/docs/how-to/using/triggering-with-gcf
def trigger_dag(data, context=None):
    """Makes a POST request to the Composer DAG Trigger API

    When called via Google Cloud Functions (GCF),
    data and context are Background function parameters.

    For more info, refer to
    https://cloud.google.com/functions/docs/writing/background#functions_background_parameters-python

    To call this function from a Python script, omit the ``context`` argument
    and pass in a non-null value for the ``data`` argument.
    """

    # Fill in with your Composer info here
    # Navigate to your webserver's login page and get this from the URL
    # Or use the script found at
    # https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/composer/rest/get_client_id.py
    client_id = get_client_id(env_project_id, env_location, env_composer_environment)
    # This should be part of your webserver's URL:
    # {tenant-project-id}.appspot.com
    webserver_id = env_composer_url
    # The name of the DAG you wish to trigger
    dag_name = env_dag_name
    webserver_url = (
        'https://'
        + webserver_id
        + '.appspot.com/api/experimental/dags/'
        + dag_name
        + '/dag_runs'
    )
    # Make a POST request to IAP which then Triggers the DAG
    make_iap_request(
        webserver_url, client_id, method='POST', json={"conf": data})


# This code is copied from
# https://github.com/GoogleCloudPlatform/python-docs-samples/blob/master/iap/make_iap_request.py
# START COPIED IAP CODE
def make_iap_request(url, client_id, method='GET', **kwargs):
    """Makes a request to an application protected by Identity-Aware Proxy.
    Args:
      url: The Identity-Aware Proxy-protected URL to fetch.
      client_id: The client ID used by Identity-Aware Proxy.
      method: The request method to use
              ('GET', 'OPTIONS', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE')
      **kwargs: Any of the parameters defined for the request function:
                https://github.com/requests/requests/blob/master/requests/api.py
                If no timeout is provided, it is set to 90 by default.
    Returns:
      The page body, or raises an exception if the page couldn't be retrieved.
    """
    # Set the default timeout, if missing
    if 'timeout' not in kwargs:
        kwargs['timeout'] = 90

    # Obtain an OpenID Connect (OIDC) token from metadata server or using service
    # account.
    google_open_id_connect_token = id_token.fetch_id_token(Request(), client_id)

    # Fetch the Identity-Aware Proxy-protected URL, including an
    # Authorization header containing "Bearer " followed by a
    # Google-issued OpenID Connect token for the service account.
    resp = requests.request(
        method, url,
        headers={'Authorization': 'Bearer {}'.format(
            google_open_id_connect_token)}, **kwargs)
    if resp.status_code == 403:
        raise Exception('Service account does not have permission to '
                        'access the IAP-protected application.')
    elif resp.status_code != 200:
        raise Exception(
            'Bad response from application: {!r} / {!r} / {!r}'.format(
                resp.status_code, resp.headers, resp.text))
    else:
        return resp.text
# END COPIED IAP CODE



def get_client_id(project_id, location, composer_environment):
    # [START composer_get_environment_client_id]
    import google.auth
    import google.auth.transport.requests
    import requests
    import six.moves.urllib.parse

    # Authenticate with Google Cloud.
    # See: https://cloud.google.com/docs/authentication/getting-started
    credentials, _ = google.auth.default(
        scopes=['https://www.googleapis.com/auth/cloud-platform'])
    authed_session = google.auth.transport.requests.AuthorizedSession(
        credentials)

    # project_id = 'YOUR_PROJECT_ID'
    # location = 'us-central1'
    # composer_environment = 'YOUR_COMPOSER_ENVIRONMENT_NAME'

    environment_url = (
        'https://composer.googleapis.com/v1beta1/projects/{}/locations/{}'
        '/environments/{}').format(project_id, location, composer_environment)
    composer_response = authed_session.request('GET', environment_url)
    environment_data = composer_response.json()
    airflow_uri = environment_data['config']['airflowUri']

    # The Composer environment response does not include the IAP client ID.
    # Make a second, unauthenticated HTTP request to the web server to get the
    # redirect URI.
    redirect_response = requests.get(airflow_uri, allow_redirects=False)
    redirect_location = redirect_response.headers['location']

    # Extract the client_id query parameter from the redirect.
    parsed = six.moves.urllib.parse.urlparse(redirect_location)
    query_string = six.moves.urllib.parse.parse_qs(parsed.query)
    print("Client Id:" + query_string['client_id'][0])
    return query_string['client_id'][0]
    # [END composer_get_environment_client_id]
