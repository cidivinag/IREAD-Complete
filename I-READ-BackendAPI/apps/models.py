import uuid

from autoslug import AutoSlugField
from django.contrib.auth.models import (
    AbstractBaseUser,
    PermissionsMixin,
    BaseUserManager,
)
from django.db import models
from django.db.models import UniqueConstraint, Sum
from apps.utils import generate_access_token
from django.core.validators import MaxValueValidator
from django.core.exceptions import ValidationError

from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver
from rest_framework.authtoken.models import Token


# Question Types
QUESTION_TYPE_CHOICES = [
    ('multiple_choice', 'Multiple Choice'),
    ('fill_in_the_blank', 'Fill in the Blank'),
    ('auditory', 'Auditory'),
]

@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_auth_token(sender, instance=None, created=False, **kwargs):
    if created:
        Token.objects.create(user=instance)

# Create your models here.
class CustomUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError("The email field must be set")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_teacher_account(self, user):
        if not user:
            raise ValueError(
                "A user instance must be provided to create a teacher account"
            )
        teacher = Teachers.objects.create(user=user)
        return teacher

    def generate_default_access_token(self, teacher):
        new_token = generate_access_token(20)
        AccessToken.objects.create(created_by=teacher, access_token=new_token)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        # Create the superuser
        user = self.create_user(email, password, **extra_fields)

        # Create a teacher account associated with this superuser
        teacher = self.create_teacher_account(user=user)
        self.generate_default_access_token(teacher=teacher)
        return user


class BaseModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now_add=False, blank=True, null=True)

    class Meta:
        abstract = True


class Users(AbstractBaseUser, PermissionsMixin, BaseModel):
    username = models.CharField(max_length=30, blank=True, null=True, default=None)

    email = models.CharField(max_length=255, unique=True, blank=True, null=True)
    first_name = models.CharField(max_length=255)
    last_name = models.CharField(max_length=255)
    middle_name = models.CharField(max_length=255, blank=True, null=True)
    is_staff = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    USERNAME_FIELD = "email"

    REQUIRED_FIELDS = ["first_name", "last_name"]

    objects = CustomUserManager()

    class Meta:
        db_table = "users"
        verbose_name = "User"
        verbose_name_plural = "Users"

    def full_name(self):
        return f"{self.last_name}, {self.first_name} "
    
    def get_section(self):
        try:
            return self.user_student.section.section
        except Students.DoesNotExist:
            return None



class Teachers(BaseModel):
    user = models.OneToOneField(
        Users, on_delete=models.CASCADE, related_name="user_teacher"
    )

    class Meta:
        db_table = "teachers"

    def __str__(self):
        return self.user.full_name()


class Students(BaseModel):
    user = models.OneToOneField(
        Users, on_delete=models.CASCADE, related_name="user_student"
    )

    strand = models.CharField(max_length=255)
    section = models.ForeignKey(
        "Sections", on_delete=models.CASCADE, related_name="section_class_list"
    )
    birthday = models.DateField(auto_now_add=False, blank=True, null=True)
    address = models.CharField(max_length=255)

    class Meta:
        db_table = "students"
        verbose_name = "Student"
        verbose_name_plural = "Students"

    def __str__(self):
        return self.user.full_name()


class Sections(BaseModel):
    created_by = models.ForeignKey(
        "Teachers", on_delete=models.CASCADE, related_name="section_created_by"
    )
    section = models.CharField(max_length=255, unique=True)
    slug = AutoSlugField(populate_from="section")
    access_token = models.OneToOneField(
        "AccessToken", on_delete=models.CASCADE, related_name="section_access_token",
        null=True
    )

    class Meta:
        db_table = "sections"
        verbose_name = "Section"
        verbose_name_plural = "Sections"

    def __str__(self):
        return self.section


class AccessToken(BaseModel):
    created_by = models.ForeignKey(
        "Teachers", on_delete=models.CASCADE, related_name="access_token_created_by"
    )
    access_token = models.CharField(max_length=1000)

    class Meta:
        db_table = "access_token"
        verbose_name = "Access Token"
        verbose_name_plural = "Access Tokens"

    def __str__(self):
        return self.access_token


class Modules(BaseModel):

    difficulty_choices = (
        ("Easy", "Easy"),
        ("Medium", "Medium"),
        ("Hard", "Hard"),
    )
    category_choices = (
        ("Vocabulary Skills", "Vocabulary Skills"),
        ("Word Pronunciation", "Word Pronunciation"),
        ("Reading Comprehension", "Reading Comprehension"),
        ("Sentence Composition", "Sentence Composition"),
    )
    created_by = models.ForeignKey(
        "Teachers", on_delete=models.CASCADE, related_name="module_created_by"
    )

    title = models.CharField(max_length=255)
    description = models.TextField()
    difficulty = models.CharField(max_length=255, choices=difficulty_choices)
    category = models.CharField(max_length=255, choices=category_choices)
    is_published = models.BooleanField(default=False)
    slug = AutoSlugField(populate_from="title")

    class Meta:
        db_table = "modules"
        verbose_name = "Module"
        verbose_name_plural = "Modules"

    def __str__(self):
        return self.title


class ModuleMaterials(BaseModel):
    module = models.ForeignKey(
        Modules, on_delete=models.CASCADE, related_name="module_materials"
    )
    name = models.CharField(max_length=255)
    path = models.CharField(max_length=255)
    file_url = models.CharField(max_length=255)
    slug = AutoSlugField(populate_from="name")

    uploaded_by = models.ForeignKey(
        "Teachers", on_delete=models.CASCADE, related_name="materials_uploaded_by"
    )

    class Meta:
        db_table = "module_materials"
        verbose_name = "Module Material"
        verbose_name_plural = "Module Materials"

    def __str__(self):
        return self.name


class Question(BaseModel):
    text = models.CharField(max_length=1000)
    module = models.ForeignKey(
        Modules, on_delete=models.CASCADE, related_name="questions_per_module"
    )
    question_type = models.CharField(
        max_length=20, 
        choices=QUESTION_TYPE_CHOICES, 
        default='multiple_choice'
    )

    class Meta:
        db_table = "questions"
        verbose_name = "Question"
        verbose_name_plural = "Questions"

    def __str__(self):
        return self.text
    
class Choice(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question = models.ForeignKey(Question, related_name='choices', on_delete=models.CASCADE)
    text = models.CharField(max_length=255)
    is_correct = models.BooleanField(default=False)

    def save(self, *args, **kwargs):
        if self._state.adding and self.question.choices.count() >= 4:
            raise ValidationError("A question can only have 4 choices.")
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.text} (Correct: {self.is_correct})"
    
class Answer(BaseModel):
    question = models.OneToOneField(
        Question, related_name="answer", on_delete=models.CASCADE
    )
    text = models.CharField(max_length=255)
    points = models.IntegerField(default=0)

    class Meta:
        db_table = "answers"
        verbose_name = "Answer"
        verbose_name_plural = "Answers"

    def __str__(self):
        return self.text
    
class User_Word_Pronunciation_Answer(BaseModel):
    question = models.ForeignKey(
        Question, related_name="user_word_pronunciation_answers", on_delete=models.CASCADE
    )
    text = models.CharField(max_length=255)
    user = models.ForeignKey(
        Users, related_name="users_user_word_pronunciation_answers", on_delete=models.CASCADE
    )
    points = models.IntegerField(default=0)

    class Meta:
        db_table = "user_word_pronunciation_answers"
        verbose_name = "User Word Pronunciation Answer"
        verbose_name_plural = "User Word Pronunciation Answers"
        constraints = [
            UniqueConstraint(fields=['question'], name='unique_question')
        ]

    def __str__(self):
        return self.text
    
class User_Module_Answer(BaseModel):
    question = models.ForeignKey(
        Question, related_name="user_question_answers", on_delete=models.CASCADE
    )
    text = models.CharField(max_length=255)
    user = models.ForeignKey(
        Users, related_name="users_user_question_answers", on_delete=models.CASCADE
    )

    class Meta:
        db_table = "user_module_answers"
        verbose_name = "User Module Answer"
        verbose_name_plural = "User Module Answers"

    def __str__(self):
        return self.text

class UserExperience(models.Model):
    user = models.OneToOneField(Users, on_delete=models.CASCADE, related_name="experience")
    total_points = models.PositiveIntegerField(default=0, validators=[MaxValueValidator(100)])

    def __str__(self):
        return f"{self.user.full_name()} - {self.total_points} points"

 
class UserCompletedModules(BaseModel):
    user = models.ForeignKey(
        Users, related_name="completed_modules", on_delete=models.CASCADE
    )
    module = models.ForeignKey(
        Modules, related_name="completed_by_users", on_delete=models.CASCADE
    )
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_completed_modules"
        verbose_name = "User Completed Module"
        verbose_name_plural = "User Completed Modules"

    def __str__(self):
        return f"{self.user.full_name()} completed {self.module.title} on {self.completed_at}"
