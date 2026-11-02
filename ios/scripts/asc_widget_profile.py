"""Идентификатор и профиль подписи расширения виджетов через App Store Connect API.

Создаёт bundle id ru.smit34.smitBilling.SmitWidgets (если нет) и профиль App Store
с действующими сертификатами распространения, кладёт его в ~/Library/MobileDevice
и пишет имя профиля в $GITHUB_ENV (WIDGET_PP_NAME). Запуск — ios-release.yml.
"""
import base64
import os
import pathlib
import plistlib
import subprocess
import sys
import time

import jwt
import requests

BUNDLE = 'ru.smit34.smitBilling.SmitWidgets'
NAME = 'SmIT Billing Widgets AppStore'
API = 'https://api.appstoreconnect.apple.com/v1'

token = jwt.encode({'iss': os.environ['APP_STORE_API_ISSUER_ID'], 'exp': int(time.time()) + 1200,
                    'aud': 'appstoreconnect-v1'},
                   os.environ['APP_STORE_API_KEY_P8'], algorithm='ES256',
                   headers={'kid': os.environ['APP_STORE_API_KEY_ID']})
H = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}


def call(method, path, **kw):
    r = requests.request(method, API + path, headers=H, **kw)
    if r.status_code >= 400:
        sys.exit(f'{method} {path}: {r.status_code} {r.text[:500]}')
    return r.json() if r.text else {}


ids = [b for b in call('GET', '/bundleIds', params={'filter[identifier]': BUNDLE, 'limit': 50})['data']
       if b['attributes']['identifier'] == BUNDLE]
if ids:
    bid = ids[0]['id']
else:
    bid = call('POST', '/bundleIds', json={'data': {'type': 'bundleIds', 'attributes': {
        'identifier': BUNDLE, 'name': 'SmIT Billing Widgets', 'platform': 'IOS'}}})['data']['id']
    print('создан bundle id', BUNDLE)

profile = None
for p in call('GET', f'/bundleIds/{bid}/profiles', params={'limit': 50})['data']:
    a = p['attributes']
    if a['name'] == NAME and a['profileState'] == 'ACTIVE':
        profile = p
    elif a['name'] == NAME:
        call('DELETE', f"/profiles/{p['id']}")   # просроченный — имя должно освободиться

if profile is None:
    certs = [c for c in call('GET', '/certificates', params={'limit': 200})['data']
             if c['attributes']['certificateType'] in ('DISTRIBUTION', 'IOS_DISTRIBUTION')]
    if not certs:
        sys.exit('нет сертификатов распространения')
    profile = call('POST', '/profiles', json={'data': {
        'type': 'profiles', 'attributes': {'name': NAME, 'profileType': 'IOS_APP_STORE'},
        'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bid}},
                          'certificates': {'data': [{'type': 'certificates', 'id': c['id']} for c in certs]}}}})['data']
    print('создан профиль', NAME, 'сертификатов:', len(certs))

raw = base64.b64decode(profile['attributes']['profileContent'])
info = plistlib.loads(subprocess.run(['security', 'cms', '-D'], input=raw, capture_output=True, check=True).stdout)
dst = pathlib.Path.home() / 'Library/MobileDevice/Provisioning Profiles' / f"{info['UUID']}.mobileprovision"
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_bytes(raw)
print('профиль виджетов:', info['Name'], info['UUID'], 'до', info['ExpirationDate'],
      'keychain:', info['Entitlements'].get('keychain-access-groups'))
with open(os.environ['GITHUB_ENV'], 'a') as f:
    f.write(f"WIDGET_PP_NAME={info['Name']}\n")
