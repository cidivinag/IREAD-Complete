from django.urls import path

from apps.views.views import (
    SignInView,
    HomepageView,
    UsersManagementView,
    ClassSectionsView,
    ClassSectionsDetailView,
    SettingsView,
    ModuleBuilderView,
    ModuleDetailView,
    QuestionAnswerCreateView,
    UserProfileView
)
from apps.views.services import (
    signin_services,
    add_new_section,
    upload_class_list,
    save_uploaded_class_lists,
    generate_new_access_token,
    add_new_module_service,
    upload_module_material_service,
    question_and_answer_form_service,
    delete_module_service,
    edit_module_service,
    publish_module_service
)

services_urlpatterns = [
    path("signin-service", signin_services, name="signin_services"),
    path("section/add/", add_new_section, name="add_new_section"),
    path(
        "section/class/upload/<str:section>/",
        upload_class_list,
        name="upload_class_list",
    ),
    path(
        "section/class/upload/save/<str:filename>/<str:section>/",
        save_uploaded_class_lists,
        name="save_uploaded_class_lists",
    ),
    path(
        "settings/access-token/generate/",
        generate_new_access_token,
        name="generate_new_access_token",
    ),
    path(
        "module/add/",
        add_new_module_service,
        name="add_new_module_service",
    ),
    path(
        "module/material/upload?module=<str:slug>/",
        upload_module_material_service,
        name="upload_module_material_service",
    ),
    path(
        "module/material/question-and-answer?module=<str:slug>/",
        question_and_answer_form_service,
        name="question_and_answer_form_service",
    ),
    path(
        "module/delete/<str:slug>/",
        delete_module_service,
        name="delete_module_service",
    ),
    path(
        "module/edit/<str:slug>/",
        edit_module_service,
        name="edit_module_service",
    ),
    path(
        "module/publish/<str:slug>/",
        publish_module_service,
        name="publish_module_service",
    ),
]
urlpatterns = [
    path("", HomepageView.as_view(), name="homepage"),
    path("signin/", SignInView.as_view(), name="signin"),
    path("users-management", UsersManagementView.as_view(), name="users_management"),
    path("class/sections/", ClassSectionsView.as_view(), name="class_sections"),
    path(
        "class/sections/<str:slug>",
        ClassSectionsDetailView.as_view(),
        name="class_section_detail",
    ),
    path(
        "settings",
        SettingsView.as_view(),
        name="settings",
    ),
    path(
        "module/builder/",
        ModuleBuilderView.as_view(),
        name="module_builder",
    ),
    path(
        "module/<str:slug>",
        ModuleDetailView.as_view(),
        name="module_detail",
    ),
    path(
        "module/questions-and-answers/<str:slug>/",
        QuestionAnswerCreateView.as_view(),
        name="question_and_answer_form",
    ),
    path("profile/<str:student_id>/", UserProfileView.as_view(), name="user_profile"),
] + services_urlpatterns
