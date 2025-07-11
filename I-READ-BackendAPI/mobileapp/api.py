from django.urls import path, include

from . import services

urlpatterns = [
    path("login", services.student_signin_service, name="api.login"),
]