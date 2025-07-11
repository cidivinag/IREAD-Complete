from django.urls import path
from . import views
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
  path("token", TokenObtainPairView.as_view(), name="token_obtain_pair"), #LOGIN
  path("token/refresh", TokenRefreshView.as_view(), name="token_refresh"), #REFRESH LOGIN
  path('profile', views.get_profile), #GET LOGGED IN USER PROFILE
  path('leaderboard', views.get_leaderboard), #GET LOGGED IN USER PROFILE
  path('modules/', views.get_modules), #GET ALL MODULES
  path('modules/<str:module_id>', views.get_module), #GET SPECIFIC MODULE
  path('modules/<str:module_id>/questions', views.get_module_questions), #GET MODULE QUESTIONS
  path('questions/<str:question_id>', views.get_question), #GET SPECIFIC MODULE QUESTION
  path('modules/<str:module_id>/answer', views.post_module_answers), #SUBMIT USER ANSWER FOR SPECIFIC MODULE
  path('assess/pronounciation', views.assess_pronunciation), #SUBMIT USER ANSWER FOR SPECIFIC MODULE
]