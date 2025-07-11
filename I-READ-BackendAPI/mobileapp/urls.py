from django.urls import path, include

from mobileapp.views import MobileLandingPageView

from . import services

services_urlpatterns = [
    path("student_signin_service", services.student_signin_service, name="student_signin_service"),
    path("api/", include("mobileapp.api")),
]

urlpatterns = [
    path("login", MobileLandingPageView.as_view(), name="mobile_landing_page"),
] + services_urlpatterns