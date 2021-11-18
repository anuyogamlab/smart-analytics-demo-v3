# Copyright 2018 Google, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This application demonstrates how to construct a Signed URL for objects in
   Google Cloud Storage.

For more information, see the README.md under /storage and the documentation
at https://cloud.google.com/storage/docs/access-control/signing-urls-manually.
"""

import argparse
# [START storage_signed_url_all]
import binascii
import collections
import datetime
import hashlib
import sys

# pip install google-auth
from google.oauth2 import service_account
# pip install six
import six
from six.moves.urllib.parse import quote


def generate_signed_url(service_account_file, bucket_name, object_name,
                        subresource=None, expiration=604800, http_method='GET',
                        query_parameters=None, headers=None):

    if expiration > 604800:
        print('Expiration Time can\'t be longer than 604800 seconds (7 days).')
        sys.exit(1)

    escaped_object_name = quote(six.ensure_binary(object_name), safe=b'/~')
    canonical_uri = '/{}'.format(escaped_object_name)

    datetime_now = datetime.datetime.utcnow()
    request_timestamp = datetime_now.strftime('%Y%m%dT%H%M%SZ')
    datestamp = datetime_now.strftime('%Y%m%d')

    google_credentials = service_account.Credentials.from_service_account_file(
        service_account_file)
    client_email = google_credentials.service_account_email
    credential_scope = '{}/auto/storage/goog4_request'.format(datestamp)
    credential = '{}/{}'.format(client_email, credential_scope)

    if headers is None:
        headers = dict()
    host = '{}.storage.googleapis.com'.format(bucket_name)
    headers['host'] = host

    canonical_headers = ''
    ordered_headers = collections.OrderedDict(sorted(headers.items()))
    for k, v in ordered_headers.items():
        lower_k = str(k).lower()
        strip_v = str(v).lower()
        canonical_headers += '{}:{}\n'.format(lower_k, strip_v)

    signed_headers = ''
    for k, _ in ordered_headers.items():
        lower_k = str(k).lower()
        signed_headers += '{};'.format(lower_k)
    signed_headers = signed_headers[:-1]  # remove trailing ';'

    if query_parameters is None:
        query_parameters = dict()
    query_parameters['X-Goog-Algorithm'] = 'GOOG4-RSA-SHA256'
    query_parameters['X-Goog-Credential'] = credential
    query_parameters['X-Goog-Date'] = request_timestamp
    query_parameters['X-Goog-Expires'] = expiration
    query_parameters['X-Goog-SignedHeaders'] = signed_headers
    query_parameters['Content-Type']="text/plain"
    if subresource:
        query_parameters[subresource] = ''

    canonical_query_string = ''
    ordered_query_parameters = collections.OrderedDict(
        sorted(query_parameters.items()))
    for k, v in ordered_query_parameters.items():
        encoded_k = quote(str(k), safe='')
        encoded_v = quote(str(v), safe='')
        canonical_query_string += '{}={}&'.format(encoded_k, encoded_v)
    canonical_query_string = canonical_query_string[:-1]  # remove trailing '&'

    canonical_request = '\n'.join([http_method,
                                   canonical_uri,
                                   canonical_query_string,
                                   canonical_headers,
                                   signed_headers,
                                   'UNSIGNED-PAYLOAD'])

    canonical_request_hash = hashlib.sha256(
        canonical_request.encode()).hexdigest()

    string_to_sign = '\n'.join(['GOOG4-RSA-SHA256',
                                request_timestamp,
                                credential_scope,
                                canonical_request_hash])

    # signer.sign() signs using RSA-SHA256 with PKCS1v15 padding
    signature = binascii.hexlify(
        google_credentials.signer.sign(string_to_sign)
    ).decode()

    scheme_and_host = '{}://{}'.format('https', host)
    signed_url = '{}{}?{}&x-goog-signature={}'.format(
        scheme_and_host, canonical_uri, canonical_query_string, signature)

    return signed_url
# [END storage_signed_url_all]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        'service_account_file',
        help='Path to your Google service account keyfile.')
    parser.add_argument(
        'request_method',
        help='A request method, e.g GET, POST.')
    parser.add_argument('bucket_name', help='Your Cloud Storage bucket name.')
    parser.add_argument('object_name', help='Your Cloud Storage object name.')
    parser.add_argument('expiration', type=int, help='Expiration time.')
    parser.add_argument(
        '--subresource',
        default=None,
        help='Subresource of the specified resource, e.g. "acl".')

    args = parser.parse_args()

    signed_url = generate_signed_url(
        service_account_file=args.service_account_file,
        http_method=args.request_method, bucket_name=args.bucket_name,
        object_name=args.object_name, subresource=args.subresource, 
        expiration=int(args.expiration))

    print(signed_url)


# https://github.com/GoogleCloudPlatform/python-docs-samples/tree/master/storage/signed_urls
# https://cloud.google.com/blog/products/storage-data-transfer/uploading-images-directly-to-cloud-storage-by-using-signed-url?utm_source=twitter&utm_medium=unpaidsocial&utm_campaign=emea-de-gcp&utm_content=tipsandeducation-staticimage

# python generate_signed_urls.py "/Users/paternostro/smart-analytics-demo-01.json" "GET" "sa-ingestion-myid-dev" "sigtest/testpic.png" 120
# python generate_signed_urls.py "/Users/paternostro/smart-analytics-demo-01.json" "POST" "sa-ingestion-myid-dev" "sigtest/" 3600
# uri="https://sa-ingestion-myid-dev.storage.googleapis.com/sigtest/?Content-Type=text%2Fplain&X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=smart-analytics-dev-ops%40smart-analytics-demo-01.iam.gserviceaccount.com%2F20210113%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20210113T144158Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&x-goog-signature=488bb20ea2cc687c344e135efa973dc7a6123927f00af0226627dbf8a6b3092e1694ed3871af5b4826b0d3de7b173871f11a8be0009c72ec6f569710cc97347f8efaa9a77f02bd44f7cea6c7f66eea942cea72ef77f9ea397d8c7e111918cf0b7b0e150f82edbd2dc49fb011c66355f883c4c825b70fd0cbb78dd86d96429c4cddde09c378608ba6c2a759abfda3f559544804b13ed60d0bb04c10f804ac065eacacc5cd3e1d651792ac8c2afc6b16b6e07fe268ddb6a2559853ad1b4af6a07c1186c6b85f56cf5d1aa0baa9e37818d5db7c3c6a879ecb9f936435462b639a32aacdaa554f14de1efe4bf8be1941216faf9277dcd3a283ac655782cf20a7ab61"
# headers="content-type:text/plain"
# curl $uri -H $headers --upload-file temp.json