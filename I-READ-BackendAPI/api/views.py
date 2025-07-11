from rest_framework.response import Response
from rest_framework.decorators import api_view
from apps.models import Modules, Question, User_Module_Answer, Answer, User_Word_Pronunciation_Answer, UserCompletedModules, Users, ModuleMaterials
from apps.utils import are_texts_similar
from .serializers import ModulesSerializer, QuestionSerializer, UserSerializer, DynamicQuestionSerializer
import json
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from django.shortcuts import get_object_or_404
from apps.models import Modules, Question, UserExperience
from api.services.module_service import ModuleService
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum, F  # Add this import
from django.conf import settings
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
import azure.cognitiveservices.speech as speechsdk
import os
import tempfile
from pydub import AudioSegment
from fuzzywuzzy import fuzz


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_profile(request):
  user = request.user
  user_experience = UserExperience.objects.get_or_create(user=user)[0]

  # Rank users based on total points
  leaderboard = UserExperience.objects.annotate(
      annotated_total_points=F('total_points')
  ).order_by('-annotated_total_points')

  # Get the rank by finding the position of the current user's total points
  rank = next((index + 1 for index, exp in enumerate(leaderboard) if exp.user == user), None)
  
  user_serializer = UserSerializer(user, many = False)
  user_profile_data = user_serializer.data
  user_profile_data['rank'] = rank if rank else "Unranked"
  total_experience = 0
  # Get the list of completed modules and points earned in each
  completed_modules = UserCompletedModules.objects.filter(user=user)
  completed_modules_data = []
  
  for completed in completed_modules:
      module = completed.module
      if module.category == 'Word Pronunciation':
          # Calculate the total points for Word Pronunciation module
          total_module_points = User_Word_Pronunciation_Answer.objects.filter(
              user=user, question__module=module
          ).aggregate(total_points=Sum('points'))['total_points'] or 0
          total_experience += total_module_points
      elif module.category == 'Sentence Composition':
          # Calculate the total points for Sentence Composition module
          total_module_points = 0
          user_answers = User_Module_Answer.objects.filter(user=user, question__module=module)
          for user_answer in user_answers:
              correct_answers = Answer.objects.filter(question=user_answer.question)
              for correct_answer in correct_answers:
                  if are_texts_similar(correct_answer.text, user_answer.text):
                      total_module_points += correct_answer.points
                      total_experience += correct_answer.points
      else:
          # Calculate the total points for other modules
          total_module_points = User_Module_Answer.objects.filter(
              user=user, question__module=module
          ).filter(
              question__answer__text=F('text')  # Correct answers matching user's answer
          ).aggregate(total_points=Sum('question__answer__points'))['total_points'] or 0
          total_experience += total_module_points
      completed_modules_data.append({
          'module_title': module.title,
          'points_earned': total_module_points
      })


  user_profile_data['completed_modules'] = completed_modules_data
  user_profile_data['experience'] = total_experience
  return Response(user_profile_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_leaderboard(request):
  # Get the top 10 users sorted by total experience points
  leaderboard = UserExperience.objects.annotate(
      annotated_total_points=F('total_points')  # Rename annotation
  ).order_by('-annotated_total_points')[:10]  # Use the new annotated field name

  leaderboard_data = []
  
  for user_experience in leaderboard:
    user = user_experience.user
    user_data = UserSerializer(user).data
    user_data['experience'] = user_experience.total_points
    leaderboard_data.append(user_data)

  return Response({'leaderboard': leaderboard_data})

@api_view(['GET'])
def get_modules(request):
  modules = Modules.objects.prefetch_related('module_materials').all()
  serializer = ModulesSerializer(modules, many = True, context={'request': request})
  return Response(serializer.data)

@api_view(['GET'])
def get_module(request, module_id: str):
  module = get_object_or_404(Modules, id=module_id)
  serializer = ModulesSerializer(module, many = False, context={'request': request})
  return Response(serializer.data)

@api_view(['GET'])
def get_module_questions(request, module_id: str):
  questions = Question.objects.filter(module_id=module_id)
  serializer = QuestionSerializer(questions, many = True)
  return Response(serializer.data)

@api_view(['GET'])
def get_question(request, question_id: str ):
  question = get_object_or_404(Question, id=question_id)
  serializer = DynamicQuestionSerializer(question, many = False)
  return Response(serializer.data)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def post_module_answers(request, module_id: str):
  user = request.user
  module = get_object_or_404(Modules, id=module_id)

  # Check if the module is locked
  if not is_module_unlocked(user, module):
      return Response({"error": "This module is locked"}, status=status.HTTP_403_FORBIDDEN)

  data = request.data.get("answers", [])
  total_points = 0
  score = 0
  questions_answered = 0

  for answer in data:
    question_id = answer.get("question_id")
    user_answer = answer.get("answer")
    correct = answer.get("correct", False)

    question = module.questions_per_module.filter(id=question_id).first()
    
    # Check module difficulty
    category = module.category
    
    if category == 'Sentence Composition':
        correct_answer = question.answer.text.lower().strip().replace(" ", "")
        user_answer = user_answer.lower().strip().replace(" ", "")
    elif category == 'Reading Comprehension' or category == 'Vocabulary Skills':
        correct_answer = question.answer.text
    else:
        correct_answer = question.answer

    if question:
      if not has_answered_question(user, question):
        save_user_answer(user, question, user_answer)
        if correct or user_answer == correct_answer:
          total_points += question.answer.points
          score += 1
      questions_answered += 1
  update_user_experience(user, total_points)

  if questions_answered == module.questions_per_module.count():
    UserCompletedModules.objects.get_or_create(user=user, module=module)
    unlock_next_module(user, module)

  return Response(
      {"message": "Answers submitted successfully", "points_gained": total_points, "score": score, } ,
      status=status.HTTP_200_OK,
  )

def get_speech_config():
  speech_key = settings.AZURE['SPEECH_KEY']
  service_region = settings.AZURE['SERVICE_REGION']
  return speechsdk.SpeechConfig(subscription=speech_key, region=service_region)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def assess_pronunciation(request):
  reference_text = request.data.get('reference_text')
  question_id = request.data.get('question_id')
  audio_file = request.FILES.get('audio_file')
  user = request.user

  if not reference_text or not audio_file:
    return Response({"error": "Reference text and audio file are required"}, status=status.HTTP_400_BAD_REQUEST)

  temp_dir = tempfile.gettempdir()
  audio_path = os.path.join(temp_dir, audio_file.name)
  print(audio_path)
  with open(audio_path, "wb") as f:
    for chunk in audio_file.chunks():
        f.write(chunk)
  try:
      # Convert M4A to WAV using pydub
    if audio_path.endswith('.m4a'):
        wav_path = audio_path.replace('.m4a', '.wav')
        audio = AudioSegment.from_file(audio_path, format="m4a")
        audio.export(wav_path, format="wav")
        os.remove(audio_path)  # Remove original M4A file

        # Set the converted WAV file path for Azure processing
        audio_path = wav_path

    speech_config = get_speech_config()
    pronunciation_config = speechsdk.PronunciationAssessmentConfig(
        reference_text=reference_text,
        grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
        granularity=speechsdk.PronunciationAssessmentGranularity.Phoneme,
        enable_miscue=True
    )

    audio_config = speechsdk.audio.AudioConfig(filename=audio_path)
    speech_recognizer = speechsdk.SpeechRecognizer(
        speech_config=speech_config, audio_config=audio_config
    )
    
    pronunciation_config.apply_to(speech_recognizer)

    result = speech_recognizer.recognize_once()

    if result.reason == speechsdk.ResultReason.RecognizedSpeech:
        pronunciation_result = speechsdk.PronunciationAssessmentResult(result)
        
        total_points = 0

        question = get_object_or_404(Question, id=question_id)
        
        if question:
          if question.module.category == 'Word Pronunciation':
            # if not has_answered_question(user, question):
            if has_answered_question(user, question) == False:
              save_user_answer(user, question, result.text)
              total_points += (pronunciation_result.pronunciation_score/10)
              # insert in to User_Word_Pronunciation_Answer for special case
              insert_word_pronunciation(user, question, (pronunciation_result.pronunciation_score/10), result.text)
          update_user_experience(user, total_points)
          if User_Module_Answer.objects.filter(user=user, question__module=question.module).count() == question.module.questions_per_module.count():
            UserCompletedModules.objects.get_or_create(user=user, module=question.module)
            unlock_next_module(user, question.module)

            
        return Response({
            "recognized_text": result.text,
            "accuracy_score": pronunciation_result.accuracy_score,
            "fluency_score": pronunciation_result.fluency_score,
            "prosody_score": pronunciation_result.prosody_score,
            "pronunciation_score": pronunciation_result.pronunciation_score,
            "completeness_score": pronunciation_result.completeness_score
        }, status=status.HTTP_200_OK)
    else:
        error_msg = "Speech recognition failed. Reason: {}".format(result.reason)
        if result.reason == speechsdk.ResultReason.Canceled:
            cancellation_details = result.cancellation_details
            error_msg += " Cancellation details: {}".format(cancellation_details.reason)
            if cancellation_details.reason == speechsdk.CancellationReason.Error:
                error_msg += " Error details: {}".format(cancellation_details.error_details)
        return Response({"error": error_msg}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

  except Exception as e:
    return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

## current has error when removing temp files
  # finally:
  #   if os.path.exists(audio_path):
  #     os.remove(audio_path)  # Clean up the temporary file


def is_module_unlocked(user: Users, module: Modules):
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

# Check if the user has answered the question already
def has_answered_question(user, question):
  return question.user_question_answers.filter(user=user).exists()


def save_user_answer(user, question, answer_text):
  question.user_question_answers.create(user=user, text=answer_text)


def update_user_experience(user, points):
  user_experience = UserExperience.objects.get_or_create(user=user)[0]
  user_experience.total_points += points
  user_experience.save()
  
def insert_word_pronunciation(user, question, result, text):
  # Insert User_Word_Pronunciation_Answer record
  User_Word_Pronunciation_Answer.objects.create(
      question=question,
      text=text,
      user=user,
      points=int(result)
  )


def unlock_next_module(user, current_module):
  next_level = get_next_difficulty(current_module.difficulty)

  if not next_level:
      return

  next_module = Modules.objects.filter(
      difficulty=next_level, category=current_module.category
  ).first()

  if current_module and not UserCompletedModules.objects.filter(
      user=user, module=current_module
  ).exists():
    UserCompletedModules.objects.create(user=user, module=current_module)
    


def get_next_difficulty(current_difficulty):
  levels = ["Easy", "Medium", "Hard"]
  try:
      index = levels.index(current_difficulty)
      return levels[index + 1] if index < len(levels) - 1 else None
  except ValueError:
      return None


def get_modules_with_lock_status(user):
  modules = Modules.objects.all()
  module_data = []
  for module in modules:
      module_data.append({
          "id": module.id,
          "title": module.title,
          "difficulty": module.difficulty,
          "category": module.category,
          "isLock": not is_module_unlocked(user, module),
      })
  return Response(module_data, status=status.HTTP_200_OK)
