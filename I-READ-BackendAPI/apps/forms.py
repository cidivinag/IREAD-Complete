from django import forms
from django.forms import modelformset_factory, inlineformset_factory

from apps.models import Modules, Question, Answer


class ModuleForm(forms.ModelForm):
    class Meta:
        model = Modules
        fields = ["title", "description", "difficulty", "category"]
        widgets = {
            "description": forms.Textarea(attrs={"rows": 5}),
        }
        labels = {
            "difficulty": "Level of difficulty",
        }


class QuestionForm(forms.Form):
    question = forms.CharField(widget=forms.TextInput(attrs={"name": "question"}))


class AnswerForm(forms.Form):
    answer = forms.CharField(widget=forms.TextInput(attrs={"name": "answer"}))
