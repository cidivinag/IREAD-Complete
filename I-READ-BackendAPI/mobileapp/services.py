from typing import Union

from django.contrib.auth import authenticate, login
from django.http import HttpRequest, JsonResponse
from django.shortcuts import render
from apps.models import (
    Users,
    Students,
)
from django.conf import settings

def student_signin_service(request: HttpRequest):
    if request.method == "POST":
        email: str = request.POST.get("email", "")
        password: str = request.POST.get("password", "")

        is_email_exists: bool = Users.objects.filter(email=email).exists()

        if not is_email_exists:
            return render(
                request,
                "components/error_message_alerts.html",
                {"message": "Email address does not exist or invalid."},
            )

        # Authenticate the user with the provided email and password
        user: Union[Users, None] = authenticate(email=email, password=password)

        if user:

            is_user_teacher: bool = Students.objects.filter(user=user).exists()

            if not is_user_teacher:
                return render(
                    request,
                    "components/error_message_alerts.html",
                    {"message": "You do not have permission to access this system"},
                )
            login(request, user)
            response = JsonResponse({"message": "Successfully signed in"})
            response["HX-Redirect"] = "/"
            return response

        return render(
            request,
            "components/error_message_alerts.html",
            {"message": "Invalid email address or password"},
        )
