import datetime
import json
import logging
import urllib.parse

import pandas as pd
from typing import Union, Dict

from django.contrib.auth import authenticate, login
from django.contrib.auth.hashers import make_password
from django.core.exceptions import ValidationError, ObjectDoesNotExist
from django.db import transaction, IntegrityError
from django.http import HttpRequest, JsonResponse
from django.shortcuts import render, get_object_or_404
from django.urls import reverse
from django.utils.text import slugify
from django.conf import settings
from django.db.models import Value
from django.db.models.functions import Concat
from fuzzywuzzy import fuzz

from apps.models import (
    Users,
    Teachers,
    Sections,
    Students,
    AccessToken,
    Modules,
    ModuleMaterials,
    Question,
    Answer,
    Choice
)
from apps.forms import ModuleForm
from apps.utils import (
    generate_access_token,
    upload_file_to_storage,
    generate_signed_url,
)

# Set up logging
logger = logging.getLogger(__name__)

def signin_services(request: HttpRequest):
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

        user: Union[Users, None] = authenticate(email=email, password=password)

        if user:
            is_user_teacher: bool = Teachers.objects.filter(user=user).exists()

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

def add_new_section(request: HttpRequest):
    if request.method == "POST":
        user: Users = request.user
        section: str = request.POST.get("section", "")

        teacher: Teachers = get_object_or_404(Teachers, user=user)

        Sections.objects.create(section=section, created_by=teacher)
        response = JsonResponse({"message": "Successfully added new section"})
        response["HX-Redirect"] = "/class/sections"
        return response

def upload_class_list(request: HttpRequest, section: str):
    if request.method == "POST":
        excel_file = request.FILES["excel_file"]
        df = pd.read_excel(excel_file)
        data = []
        sections = get_object_or_404(Sections, slug=section)

        for _, row in df.iterrows():
            try:
                birthday = pd.to_datetime(row.get("Birthday")).strftime("%Y-%m-%d")
            except Exception:
                birthday = None
            
            data.append(
                {
                    "last_name": row.get("Last Name"),
                    "first_name": row.get("First Name"),
                    "middle_name": row.get("Middle Name"),
                    "email": row.get("E-mail"),
                    "section": sections.section,
                    "strand": row.get("Strand"),
                    "birthday": birthday,
                    "address": row.get("Address"),
                }
            )
        
        excel_file_name = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        settings.REDIS_CLIENT.set(excel_file_name, json.dumps(data))

        return render(
            request,
            "components/uploaded_class_lists_table.html",
            {"data": data, "excel_file_name": excel_file_name, "section": section},
        )

def validate_student_data(data: Dict) -> bool:
    required_fields = ["email", "first_name", "last_name", "strand", "section"]
    return all(data.get(field) for field in required_fields)

def save_uploaded_class_lists(request: HttpRequest, filename: str, section: str):
    try:
        user = request.user
        teacher = get_object_or_404(Teachers, user=user)
        file_data = settings.REDIS_CLIENT.get(filename)
        sec_result = get_object_or_404(Sections, slug=section)
        if not file_data:
            raise ValueError("No data found in Redis for the given filename")

        students_data = json.loads(file_data)

        if not isinstance(students_data, list):
            raise ValueError("Invalid data format - expected a list of students")

        invalid_records = []
        valid_students_data = []

        for idx, student in enumerate(students_data):
            if not validate_student_data(student):
                invalid_records.append(idx + 1)
            else:
                valid_students_data.append(student)

        if not valid_students_data:
            raise ValueError("No valid student records found")

        with transaction.atomic():
            access_token = get_object_or_404(AccessToken, created_by=teacher, access_token=sec_result.access_token)

            if not access_token:
                return JsonResponse({"message": "No access token found", "type": "error"}, status=400)

            users = [
                Users(
                    last_name=student["last_name"],
                    first_name=student["first_name"],
                    middle_name=student.get("middle_name", ""),
                    email=student["email"],
                    username=student["email"],
                    password=make_password(access_token.access_token),
                )
                for student in valid_students_data
            ]

            emails = [user.email for user in users]
            existing_emails = Users.objects.filter(email__in=emails).values_list("email", flat=True)

            if existing_emails:
                raise ValidationError(f"Duplicate emails found: {', '.join(existing_emails)}")

            created_users = Users.objects.bulk_create(users)

            students = [
                Students(
                    user=user,
                    strand=student_data["strand"],
                    section=sec_result,
                    birthday=student_data.get("birthday"),
                    address=student_data.get("address", ""),
                )
                for user, student_data in zip(created_users, valid_students_data)
            ]
            Students.objects.bulk_create(students)

        settings.REDIS_CLIENT.delete(filename)

        response = JsonResponse({"message": "Successfully added new section", "type": "success"})
        response["HX-Redirect"] = f"/class/sections/{sec_result.slug}"
        return response

    except ValidationError as e:
        return JsonResponse({"message": str(e), "type": "error"}, status=400)
    except Exception as e:
        return JsonResponse({"message": f"Internal error: {str(e)}", "type": "error"}, status=500)

def generate_new_access_token(request: HttpRequest):
    user = request.user
    new_token = generate_access_token(20)
    teacher = get_object_or_404(Teachers, user=user)
    section = Sections.objects.filter(created_by=teacher, access_token_id__isnull=True).last()
    
    if section is None:
        response = JsonResponse({"message": "All sections have access tokens", "type": "error", "error": True})
        response["HX-Trigger"] = "showMessage"
        return response
    
    token_obj = AccessToken.objects.create(
        created_by=teacher,
        access_token=new_token
    )
    
    section.access_token = token_obj
    section.save()

    response = JsonResponse({"message": "Successfully generated a new token"})
    response["HX-Redirect"] = "/settings"
    return response

def add_new_module_service(request: HttpRequest):
    # Initialize context with defaults
    context = {
        "form": ModuleForm(),
        "module_builder_active": "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white",
        "success_message": "",
        "error_message": ""
    }

    try:
        # Check authentication
        user = request.user
        if not user.is_authenticated:
            logger.error("User is not authenticated")
            context["error_message"] = "You must be logged in to create a module."
            return render(request, "module_builder.html", context, status=403)
        logger.debug(f"User: {user.email}, ID: {user.id}")

        # Check for Teachers record
        try:
            teacher = Teachers.objects.get(user=user)
            logger.debug(f"Teacher found: ID {teacher.id}")
        except ObjectDoesNotExist:
            logger.error(f"No Teachers record found for user {user.email}")
            context["error_message"] = "Teacher profile not found. Please contact support to set up your teacher account."
            return render(request, "module_builder.html", context, status=404)

        # Add modules to context (for initial render and error cases)
        context["modules"] = Modules.objects.filter(created_by=teacher)
        #context["modules"] = Modules.objects.all()

        # Add choices to context
        try:
            context["difficulties"] = Modules.difficulty_choices
            logger.debug(f"Difficulties: {context['difficulties']}")
        except Exception as e:
            logger.error(f"Error fetching difficulties: {str(e)}")
            context["difficulties"] = []

        try:
            context["categories"] = Modules.category_choices
            logger.debug(f"Categories: {context['categories']}")
        except Exception as e:
            logger.error(f"Error fetching categories: {str(e)}")
            context["categories"] = []

        context["statuses"] = [("", "All"), ("Published", "Published"), ("Not Publish", "Not Publish")]
        logger.debug(f"Statuses: {context['statuses']}")

        try:
            creators = Teachers.objects.filter(
                user__first_name__isnull=False,
                user__last_name__isnull=False
            ).annotate(
                full_name=Concat('user__first_name', Value(' '), 'user__last_name')
            ).values_list('full_name', flat=True).distinct()
            context["creators"] = creators
            logger.debug(f"Creators fetched: {list(creators)}")
        except Exception as e:
            logger.error(f"Error fetching creators: {str(e)}")
            context["creators"] = []

        if request.method == "POST":
            logger.debug(f"POST data: {request.POST}")
            form = ModuleForm(request.POST)
            context["form"] = form  # Update form in context for error cases
            
            if form.is_valid():
                title = form.cleaned_data["title"]
                logger.debug(f"Validating title: {title}")
                description = form.cleaned_data["description"]
                difficulty = form.cleaned_data["difficulty"]
                category = form.cleaned_data["category"]
                logger.debug(f"Form data - Title: {title}, Difficulty: {difficulty}, Category: {category}")

                # Check for similar titles
                existing_modules = Modules.objects.filter(created_by=teacher)
                for module in existing_modules:
                    similarity = fuzz.ratio(title.lower(), module.title.lower())
                    if similarity >= 90:
                        logger.warning(f"Similar title found: {module.title} (similarity: {similarity}%)")
                        context["error_message"] = "A module with a similar title already exists. Please choose a different title."
                        return render(request, "module_builder.html", context)

                # Create module
                module = Modules(
                    title=title,
                    description=description,
                    difficulty=difficulty,
                    category=category,
                    created_by=teacher,
                )
                # Generate unique slug
                base_slug = slugify(title)
                slug = base_slug
                counter = 1
                while Modules.objects.filter(slug=slug).exists():
                    slug = f"{base_slug}-{counter}"
                    counter += 1
                module.slug = slug
                logger.debug(f"Generated slug: {module.slug}")

                # Save module
                module.save()
                logger.info(f"Module '{title}' saved with slug: {module.slug}")

                # Update modules in context after saving
                context["modules"] = Modules.objects.filter(created_by=teacher)
                #context["modules"] = Modules.objects.all()
                context["success_message"] = f"Module '{title}' created successfully!"
                logger.debug("Success message set")

                return render(request, "module_builder.html", context, status=200)
            else:
                logger.debug(f"Form invalid: {form.errors}")
                context["error_message"] = "Please correct the errors in the form."
                return render(request, "module_builder.html", context)
        else:
            logger.debug("Rendering initial module builder page")
            return render(request, "module_builder.html", context)

    except IntegrityError as e:
        logger.error(f"Database integrity error: {str(e)}")
        context["error_message"] = "A module with this title or URL already exists. Please try a different title."
        return render(request, "module_builder.html", context, status=400)
    except Exception as e:
        logger.error(f"Unexpected error in add_new_module_service: {str(e)}")
        context["error_message"] = "An unexpected error occurred. Please try again or contact support."
        return render(request, "module_builder.html", context, status=500)

def edit_module_service(request: HttpRequest, slug: str):
    try:
        user = request.user
        teacher = get_object_or_404(Teachers, user=user)
        module = get_object_or_404(Modules, slug=slug, created_by=teacher)
        
        if request.method == "POST":
            title = request.POST.get("title", "").strip()
            description = request.POST.get("description", "").strip()
            
            # Validate inputs
            if not title:
                return render(
                    request,
                    "components/editable_part.html",
                    {"module": module, "error": "Title cannot be empty."},
                    status=400
                )
            
            # Check for similar titles (excluding the current module)
            existing_modules = Modules.objects.filter(created_by=teacher).exclude(slug=slug)
            for existing_module in existing_modules:
                similarity = fuzz.ratio(title.lower(), existing_module.title.lower())
                if similarity >= 90:
                    logger.warning(f"Similar title found: {existing_module.title} (similarity: {similarity}%)")
                    return render(
                        request,
                        "components/editable_part.html",
                        {"module": existing_module, "error": "A module with a similar title already exists."},
                        status=400
                    )
            
            # Update module
            module.title = title
            module.description = description
            module.save()
            logger.info(f"Module '{module.slug}' updated: Title='{title}', Description='{description}'")
            
            # Render the updated HTML for #editable-part in normal mode
            response = render(
                request,
                "components/editable_part.html",
                {"module": module}
            )
            # Trigger an event to refresh the module builder page
            response["HX-Trigger"] = "moduleUpdated"
            return response
        
        # If not POST, return the initial HTML for #editable-part
        return render(
            request,
            "components/editable_part.html",
            {"module": module}
        )
    
    except Exception as e:
        logger.error(f"Error in edit_module_service: {str(e)}")
        return render(
            request,
            "components/editable_part.html",
            {"module": module, "error": f"Error: {str(e)}"},
            status=500
        )

def delete_module_service(request: HttpRequest, slug: str):
    try:
        user = request.user
        teacher = get_object_or_404(Teachers, user=user)
        module = get_object_or_404(Modules, slug=slug, created_by=teacher)
        
        module_title = module.title
        module.delete()
        logger.info(f"Module '{module_title}' with slug '{slug}' deleted by user {user.email}")
        
        # Encode success message for URL
        success_message = urllib.parse.quote(f"Module '{module_title}' deleted successfully!")
        redirect_url = f"{reverse('module_builder')}?success_message={success_message}"
        
        response = JsonResponse({"message": "Module deleted successfully"})
        response["HX-Redirect"] = redirect_url
        return response
        
    except Exception as e:
        logger.error(f"Error in delete_module_service: {str(e)}")
        context = {
            "error_message": f"Error deleting module: {str(e)}",
            "modules": Modules.objects.filter(created_by=teacher),
            "form": ModuleForm(),
            "module_builder_active": "bg-indigo-500 text-white px-2 rounded-lg font-semibold hover:text-indigo-600 hover:bg-white",
            "difficulties": Modules.difficulty_choices,
            "categories": Modules.category_choices,
            "statuses": [("", "All"), ("Published", "Published"), ("Not Publish", "Not Publish")],
            "creators": Teachers.objects.filter(
                user__first_name__isnull=False,
                user__last_name__isnull=False
            ).annotate(
                full_name=Concat('user__first_name', Value(' '), 'user__last_name')
            ).values_list('full_name', flat=True).distinct(),
        }
        return render(request, "module_builder.html", context, status=500)

def upload_module_material_service(request: HttpRequest, slug: str):
    user = request.user
    teacher = get_object_or_404(Teachers, user=user)
    module = get_object_or_404(Modules, slug=slug)
    if request.method == "POST":
        name = request.POST.get("name", "")
        file = request.FILES.get("file", None)

        upload_file = upload_file_to_storage(file=file)

        path = upload_file["path"]
        file_url = upload_file["file_url"]

        ModuleMaterials.objects.create(
            module=module,
            name=name,
            path=path,
            file_url=file_url,
            uploaded_by=teacher,
        )
        response = JsonResponse({"message": "Successfully uploaded a material"})
        response["HX-Redirect"] = f"/module/{slug}"
        return response

def question_and_answer_form_service(request, slug):
    if request.method == "POST":
        module = get_object_or_404(Modules, slug=slug)
        question_count = int(request.POST.get("question_count", 0))

        for idx in range(question_count):
            if idx == 0:
                question_text = request.POST.get("question")
                points = request.POST.get("points")
                question_type = request.POST.get("question_type")
            else:
                question_text = request.POST.get(f"question_{idx}")
                points = request.POST.get(f"points_{idx}")
                question_type = request.POST.get(f"question_type_{idx}")

            question = Question.objects.create(
                module=module, 
                text=question_text, 
                question_type=question_type
            )

            if question_type == "multiple_choice":
                if idx == 0:
                    correct_choice_text = request.POST.get("answer").strip()
                else:
                    correct_choice_text = request.POST.get(f"answer_{idx}_0").strip()

                choice_keys = [key for key in request.POST.keys() if key.startswith(f"choice_{idx}_")]

                for key in choice_keys:
                    choice_text = request.POST.get(key).strip()
                    is_correct = choice_text == correct_choice_text
                    Choice.objects.create(
                        question=question, 
                        text=choice_text, 
                        is_correct=is_correct
                    )
                Answer.objects.create(
                    question=question, 
                    text=correct_choice_text, 
                    points=points
                )
            else:
                if idx == 0:
                    answer_text = request.POST.get("answer")
                else:
                    answer_text = request.POST.get(f"answer_{idx}_0")
                Answer.objects.create(question=question, text=answer_text, points=points)

        response = JsonResponse({"message": "Successfully created quizzes"})
        response["HX-Redirect"] = f"/module/{slug}"
        return response

def publish_module_service(request: HttpRequest, slug: str):
    try:
        user = request.user
        teacher = get_object_or_404(Teachers, user=user)
        module = get_object_or_404(Modules, slug=slug, created_by=teacher)
        
        module.is_published = True
        module.save()
        
        response = JsonResponse({"message": "Successfully published module"})
        response["HX-Redirect"] = f"/module/{slug}"
        return response
        
    except Exception as e:
        response = JsonResponse({"message": f"Error: {e}", "type": "error"})
        response["HX-Trigger"] = "showMessage"
        return response