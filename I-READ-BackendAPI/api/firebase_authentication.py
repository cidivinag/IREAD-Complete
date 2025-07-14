from rest_framework import authentication, exceptions
from firebase_admin import auth as firebase_auth
from django.contrib.auth import get_user_model

import logging

class FirebaseAuthentication(authentication.BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            logging.error('Missing Authorization header')
            raise exceptions.AuthenticationFailed('Missing Authorization header')
        if not auth_header.startswith('Bearer '):
            logging.error(f'Malformed Authorization header: {auth_header}')
            raise exceptions.AuthenticationFailed('Malformed Authorization header: must start with "Bearer "')
        id_token = auth_header.split('Bearer ')[1]
        try:
            decoded = firebase_auth.verify_id_token(id_token)
        except Exception as e:
            logging.error(f'Firebase ID token verification failed: {e}')
            raise exceptions.AuthenticationFailed(f'Invalid Firebase ID token: {e}')
        try:
            uid = decoded['uid']
            email = decoded.get('email', f'{uid}@firebase.local')
            User = get_user_model()
            user, created = User.objects.get_or_create(username=uid, defaults={'email': email})
            return (user, None)
        except Exception as e:
            logging.error(f'User fetch/create failed: {e}')
            raise exceptions.AuthenticationFailed(f'User fetch/create failed: {e}')
