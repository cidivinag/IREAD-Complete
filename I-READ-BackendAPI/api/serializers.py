from rest_framework import serializers
from apps.models import Modules, Question, User_Module_Answer, User_Word_Pronunciation_Answer, UserExperience, Users, Choice, Answer, UserCompletedModules, ModuleMaterials
from django.db.models import F, Sum

from apps.utils import are_texts_similar
class AnswerSerializer(serializers.ModelSerializer):
    class Meta:
      model = Answer
      fields = '__all__'
  
class ChoiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Choice
        fields = ['id','text','question']

# Use dynamic fields
class DynamicQuestionSerializer(serializers.ModelSerializer):
    choices = ChoiceSerializer(many=True, read_only=True)
    answer = AnswerSerializer(read_only=True)

    class Meta:
        model = Question
        fields = '__all__'
        
class QuestionSerializer(serializers.ModelSerializer):
  choices = ChoiceSerializer(many=True, read_only=True)
  # answer = AnswerSerializer(read_only=True)

  class Meta:
    model = Question
    fields = '__all__'
    
class ModuleMaterialSerializer(serializers.ModelSerializer):
    
    class Meta:
        model = ModuleMaterials
        fields = '__all__'
        
class ModulesSerializer(serializers.ModelSerializer):
    questions_per_module = QuestionSerializer(many=True, read_only=True)
    isLock = serializers.SerializerMethodField()
    progress = serializers.SerializerMethodField()
    module_materials = ModuleMaterialSerializer(many=True, read_only=True)

    class Meta:
        model = Modules
        fields = '__all__'

    def get_progress(self, obj):
        user = self.context['request'].user
        category = obj.category
        
        completed_count = UserCompletedModules.objects.filter(
            user=user,
            module__category=category
        ).values('module__difficulty').distinct().count()
        
        return completed_count

    def get_isLock(self, obj):
        user = self.context['request'].user
        return not is_module_unlocked(user, obj)
    


class UserModuleAsnwerSerializer(serializers.ModelSerializer):
  class Meta:
    model = User_Module_Answer
    fields = '__all__'

class UserSerializer(serializers.ModelSerializer):
    section = serializers.SerializerMethodField()

    def get_section(self, obj):
        return obj.get_section()
    
    class Meta:
        model = Users
        fields = '__all__'
        

# Define this function if not already present
def is_module_unlocked(user, module):
    if module.difficulty == "Easy":
        return True

    previous_level = get_previous_difficulty(module.difficulty)
    return UserCompletedModules.objects.filter(
        user=user, module__difficulty=previous_level, module__category=module.category
    ).exists()

def get_previous_difficulty(current_difficulty):
    levels = ["Easy", "Medium", "Hard"]
    try:
        index = levels.index(current_difficulty)
        return levels[index - 1] if index > 0 else None
    except ValueError:
        return None
    
class CompletedModulePointsSerializer(serializers.ModelSerializer):
    total_points = serializers.SerializerMethodField()

    class Meta:
        model = Modules
        fields = ['title', 'total_points']

    def get_total_points(self, obj):
        # Calculate total points for the module
        module = obj
        return self.calculate_total_points_for_module(module)

    def calculate_total_points_for_module(self, module):
        # Retrieve the user from UserCompletedModules
        completed_modules = UserCompletedModules.objects.filter(module=module)
        total_module_points = 0

        for completed_module in completed_modules:
            user = completed_module.user
            if module.category == 'Word Pronunciation':
                # Calculate the total points for Word Pronunciation module
                total_module_points += User_Word_Pronunciation_Answer.objects.filter(
                    user=user, question__module=module
                ).aggregate(total_points=Sum('points'))['total_points'] or 0
            elif module.category == 'Sentence Composition':
                # Calculate the total points for Sentence Composition module
                user_answers = User_Module_Answer.objects.filter(user=user, question__module=module)
                for user_answer in user_answers:
                    correct_answers = Answer.objects.filter(question=user_answer.question)
                    for correct_answer in correct_answers:
                        if are_texts_similar(correct_answer.text, user_answer.text):
                            total_module_points += correct_answer.points
            else:
                # Calculate the total points for other modules
                total_module_points += User_Module_Answer.objects.filter(
                    user=user, question__module=module
                ).filter(
                    question__answer__text=F('text')  # Correct answers matching user's answer
                ).aggregate(total_points=Sum('question__answer__points'))['total_points'] or 0

        return total_module_points
    
class UserExperienceSerializer(serializers.ModelSerializer):
    total_points = serializers.SerializerMethodField()

    class Meta:
        model = UserExperience
        fields = '__all__'

    def get_total_points(self, obj):
        user = obj.user
        return self.calculate_total_points(user)

    def calculate_total_points(self, user):
        total_points = 0

        # Get all completed modules for the user
        completed_modules = UserCompletedModules.objects.filter(user=user)

        for completed_module in completed_modules:
            module = completed_module.module
            if module.category == 'Word Pronunciation':
                # Calculate the total points for Word Pronunciation module
                total_points += User_Word_Pronunciation_Answer.objects.filter(
                    user=user, question__module=module
                ).aggregate(total_points=Sum('points'))['total_points'] or 0
            elif module.category == 'Sentence Composition':
                # Calculate the total points for Sentence Composition module
                user_answers = User_Module_Answer.objects.filter(user=user, question__module=module)
                for user_answer in user_answers:
                    correct_answers = Answer.objects.filter(question=user_answer.question)
                    for correct_answer in correct_answers:
                        if are_texts_similar(correct_answer.text, user_answer.text):
                            total_points += correct_answer.points
            else:
                # Calculate the total points for other modules
                total_points += User_Module_Answer.objects.filter(
                    user=user, question__module=module
                ).filter(
                    question__answer__text=F('text')  # Correct answers matching user's answer
                ).aggregate(total_points=Sum('question__answer__points'))['total_points'] or 0

        return total_points