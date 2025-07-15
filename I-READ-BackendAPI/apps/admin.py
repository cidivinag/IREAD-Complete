from django.contrib import admin
from django.contrib.admin import ModelAdmin
from django.contrib.auth.forms import UserCreationForm
from django.urls import reverse
from django.http import HttpResponseRedirect

from apps.models import Students, Users, Teachers, Modules, Question, User_Module_Answer, Sections


admin.site.register(Students)


@admin.register(Users)
class UserAdmin(ModelAdmin):
    list_display = (
        "email",
        "first_name",
        "last_name",
        "is_active",
    )
    add_form = UserCreationForm

    # Ensure that when creating or updating users, passwords are hashed
    def save_model(self, request, obj, form, change):
        if form.cleaned_data["password"]:
            obj.set_password(form.cleaned_data["password"])
        super().save_model(request, obj, form, change)

@admin.register(Teachers)
class TeachersAdmin(admin.ModelAdmin):
    list_display = ('user',)
    search_fields = ('user__first_name', 'user__last_name')
    
    
@admin.register(Modules)
class ModulesAdmin(admin.ModelAdmin):
    list_display = ('title', 'description')
    search_fields = ('title',)
    
@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    # Changed 'question' to 'text' to match model field name
    list_display = ('text', 'module', 'question_type')
    list_filter = ('module', 'question_type')
    search_fields = ('text', 'module__title')  # Search by question text and module title
    
    # Optional: Add fieldsets for better organization
    fieldsets = (
        (None, {
            'fields': ('text', 'module')
        }),
        ('Options', {
            'fields': ('question_type',)
        })
    )
    
@admin.register(User_Module_Answer)
class UserModuleAnswerAdmin(admin.ModelAdmin):
    list_display = ('text', 'user', 'question')
    list_filter = ('user', 'question')
    search_fields = ('text', 'user__email', 'question__text')
    
    fieldsets = (
        (None, {
            'fields': ('user', 'question', 'text')
        }),
    )
    
    def get_readonly_fields(self, request, obj=None):
        if obj: # editing an existing object
            return ('user', 'question')
        return ()
    
@admin.register(Sections)
class SectionsAdmin(admin.ModelAdmin):
    list_display = ('section', 'created_by', 'created_at')  # Adjust as needed
    search_fields = ('section',)
    list_filter = ('created_by',)
