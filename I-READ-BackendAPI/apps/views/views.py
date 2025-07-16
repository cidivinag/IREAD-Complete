import os
from django.conf import settings
from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import render, get_object_or_404, redirect
from django.urls import reverse_lazy
from django.views.generic import TemplateView, DetailView, CreateView, View
from django.contrib import messages
from django.utils.text import slugify
from apps.models import Modules, Question, User_Word_Pronunciation_Answer, UserExperience
from api.serializers import CompletedModulePointsSerializer, ModulesSerializer, QuestionSerializer, UserExperienceSerializer, UserSerializer
from django.db.models import Sum, F
from fuzzywuzzy import fuzz
from apps.forms import ModuleForm, QuestionForm, AnswerForm
from apps.models import (
    Students,
    Sections,
    AccessToken,
    Teachers,
    Modules,
    ModuleMaterials,
    Question,
    Answer,
    UserCompletedModules,
    User_Module_Answer,
    QUESTION_TYPE_CHOICES
)
from apps.utils import are_texts_similar
from django.db.models import Value
from django.db.models.functions import Concat

# Create your views here.
class SignInView(TemplateView):
    template_name = "auth/signin.html"

class HomepageView(LoginRequiredMixin, TemplateView):
    template_name = "homepage.html"
    login_url = "/signin"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        leaderboard = UserExperience.objects.filter(
            user__user_student__isnull=False
        ).select_related(
            'user',
            'user__user_student'
        ).annotate(
            annotated_total_points=F('total_points')
        ).order_by('-annotated_total_points')[:10]
        leaderboard_data = []
        for user_experience in leaderboard:
            user = user_experience.user
            user_data = UserSerializer(user).data
            user_data["experience"] = UserExperienceSerializer(user_experience).data.get("total_points")
            leaderboard_data.append(user_data)

        context["analytics_active"] = "nav-active"
        context["leaderboard"] = leaderboard_data

        module_points = Modules.objects.all()
        module_points_data = []
        for module in module_points:
            serializer = CompletedModulePointsSerializer(module)
            module_points_data.append(serializer.data)

        context["module_points"] = module_points_data
        return context

class UsersManagementView(LoginRequiredMixin, TemplateView):
    template_name = "users_management.html"
    login_url = "/signin"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        students = Students.objects.select_related('user', 'section').all()

        # Apply filters
        strand = self.request.GET.get('strand')
        section = self.request.GET.get('section')

        if strand:
            students = students.filter(strand=strand)
        if section:
            students = students.filter(section__section=section)

        strands = Students.objects.values_list('strand', flat=True).distinct()
        sections = Sections.objects.values_list('section', flat=True).distinct()
        context["users_management_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        context["students"] = students
        context["strands"] = strands
        context["sections"] = sections
        return context

class UserProfileView(LoginRequiredMixin, TemplateView):
    template_name = "user_profile_template.html"
    login_url = "/signin"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        student_id = self.kwargs.get("student_id")
        student = get_object_or_404(Students, user_id=student_id)
        user_experience = UserExperience.objects.get_or_create(user=student.user)[0]
        completed_modules = UserCompletedModules.objects.filter(user=student.user)
        completed_modules_data = []

        for completed in completed_modules:
            module = completed.module
            total_module_points = User_Module_Answer.objects.filter(
                user=student.user, question__module=module
            ).filter(
                question__answer__text=F('text')
            ).aggregate(total_points=Sum('question__answer__points'))['total_points'] or 0

            completed_modules_data.append({
                'module_title': module.title,
                'points_earned': total_module_points
            })
        
        student_data = {
            'first_name': student.user.first_name,
            'last_name': student.user.last_name,
            'section': student.section,
            'experience': user_experience.total_points,
            'completed_modules': completed_modules_data,
            'is_authenticated': True,
        }
        context['user'] = student_data
        return context

class ClassSectionsView(LoginRequiredMixin, TemplateView):
    template_name = "class_sections.html"
    login_url = "/signin"

    def post(self, request, *args, **kwargs):
        section_name = request.POST.get('section')
        if section_name:
            teacher = get_object_or_404(Teachers, user=request.user)
            section = Sections.objects.create(
                section=section_name,
                created_by=teacher,
                slug=slugify(section_name)
            )
            messages.success(request, "Section created successfully!")
        else:
            messages.error(request, "Error creating section. Section name is required.")

        # For HTMX, re-render the table with updated data
        context = self.get_context_data()
        return render(request, "class_sections.html#pagination-table", context)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        sections = Sections.objects.all()

        # Custom handling for 'creator' filter
        creator = self.request.GET.get('creator')
        if creator:
            sections = sections.filter(
                created_by__user__first_name__icontains=creator.split()[0],
                created_by__user__last_name__icontains=creator.split()[-1] if len(creator.split()) > 1 else ''
            )

        creators = Teachers.objects.annotate(
            full_name=Concat('user__first_name', Value(' '), 'user__last_name')
        ).values_list('full_name', flat=True).distinct()

        context["class_lists_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        context["sections"] = sections
        context["creators"] = creators
        return context

class ClassSectionsDetailView(LoginRequiredMixin, DetailView):
    template_name = "class_lists_per_section.html"
    login_url = "/signin"
    context_object_name = "section"
    model = Sections

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        section = self.get_object()
        students = Students.objects.filter(section=section)
        teacher = get_object_or_404(Teachers, user=self.request.user)
        
        is_creator = section.created_by == teacher

        context["class_lists_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        context["students"] = students
        context["section_slug"] = section.slug
        context["is_creator"] = is_creator
        return context

class SettingsView(LoginRequiredMixin, TemplateView):
    template_name = "settings.html"
    login_url = "/signin"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        teacher = get_object_or_404(Teachers, user=self.request.user)
        sections = Sections.objects.filter(created_by=teacher)
        access_token = AccessToken.objects.filter(created_by=teacher).first()

        context["settings_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        context["sections"] = sections
        context["access_token"] = access_token if access_token else ""
        return context

class ModuleBuilderView(LoginRequiredMixin, TemplateView):
    template_name = "module_builder.html"
    login_url = "/signin"

    def post(self, request, *args, **kwargs):
        form = ModuleForm(request.POST)
        if form.is_valid():
            module = form.save(commit=False)
            teacher = get_object_or_404(Teachers, user=request.user)
            module.created_by = teacher
            module.slug = slugify(module.title)
            module.save()
            messages.success(request, "Module created successfully!")
        else:
            messages.error(request, "Error creating module. Please check the form.")
            # Re-render the form with errors
            context = self.get_context_data(form=form)
            return self.render_to_response(context)

        # For HTMX, re-render the table with updated data
        context = self.get_context_data()
        return render(request, "module_builder.html#pagination-table", context)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        user = self.request.user
        teacher = get_object_or_404(Teachers, user=user)
        modules = Modules.objects.all()

        # Apply filters
        difficulty = self.request.GET.get('difficulty')
        category = self.request.GET.get('category')
        status = self.request.GET.get('status')
        creator = self.request.GET.get('creator')

        if difficulty:
            modules = modules.filter(difficulty=difficulty)
        if category:
            modules = modules.filter(category=category)
        if status:
            modules = modules.filter(is_published=(status == "Published"))
        if creator:
            try:
                name_parts = creator.split()
                first_name = name_parts[0]
                last_name = name_parts[-1] if len(name_parts) > 1 else ''
                if last_name:
                    modules = modules.filter(
                        created_by__user__first_name__icontains=first_name,
                        created_by__user__last_name__icontains=last_name
                    )
                else:
                    modules = modules.filter(
                        created_by__user__first_name__icontains=first_name
                    )
            except (ValueError, IndexError):
                pass

        form = ModuleForm(self.request.POST or None)
        difficulties = Modules.difficulty_choices
        categories = Modules.category_choices
        statuses = [("", "All"), ("Published", "Published"), ("Not Publish", "Not Publish")]
        creators = Teachers.objects.annotate(
            full_name=Concat('user__first_name', Value(' '), 'user__last_name')
        ).values_list('full_name', flat=True).distinct()

        context["module_builder_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        context["form"] = form
        context["modules"] = modules
        context["difficulties"] = difficulties
        context["categories"] = categories
        context["statuses"] = statuses
        context["creators"] = creators
        return context

class ModuleDetailView(LoginRequiredMixin, DetailView):
    template_name = "module_detail.html"
    login_url = "/signin"
    context_object_name = "module"
    model = Modules

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        module_slug = self.kwargs.get("slug")
        module = get_object_or_404(Modules, slug=module_slug)
        teacher = get_object_or_404(Teachers, user=self.request.user)
        module_materials = ModuleMaterials.objects.filter(
            module=module, uploaded_by=teacher
        )
        questions = Question.objects.filter(module=module).prefetch_related(
            "answer"
        )
        context["module_builder_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        context["module_slug"] = module_slug
        context["module_materials"] = module_materials
        context["questions"] = questions
        return context

class QuestionAnswerCreateView(LoginRequiredMixin, TemplateView):
    login_url = "/signin"
    template_name = "question_and_answer_form.html"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        slug = self.kwargs.get("slug")
        module = get_object_or_404(Modules, slug=slug)
        if module.category == "Vocabulary Skills":
            category_choice = QUESTION_TYPE_CHOICES[0][0]
        elif module.category == "Word Pronunciation":
            category_choice = QUESTION_TYPE_CHOICES[2][0]
        elif module.category == "Sentence Composition":
            category_choice = QUESTION_TYPE_CHOICES[0][0]
        elif module.category == "Reading Comprehension":
            category_choice = QUESTION_TYPE_CHOICES[0][0]
        context["slug"] = slug
        context["question_form"] = QuestionForm(self.request.POST or None)
        context["answer_form"] = AnswerForm(self.request.POST or None)
        context["category_choice"] = [category_choice]
        context["module_builder_active"] = "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white"
        return context