import logging
from rest_framework.response import Response

# Set up logging
logger = logging.getLogger(__name__)
from rest_framework.decorators import api_view, permission_classes
from apps.models import Modules, Question, User_Module_Answer, Answer, User_Word_Pronunciation_Answer, UserCompletedModules, Users, ModuleMaterials, UserExperience
from apps.utils import are_texts_similar
from .serializers import ModulesSerializer, QuestionSerializer, UserSerializer, DynamicQuestionSerializer
from django.shortcuts import get_object_or_404
from rest_framework import status
from django.db.models import Sum, F
from django.conf import settings
import azure.cognitiveservices.speech as speechsdk
import os
import stat
import tempfile
from pydub import AudioSegment
from fuzzywuzzy import fuzz
from django.contrib.auth import authenticate, get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.permissions import IsAuthenticated

# Firebase Admin SDK imports
# import firebase_admin
# from firebase_admin import auth as firebase_auth

# Ensure Firebase app is initialized
# if not firebase_admin._apps:
#     firebase_admin.initialize_app()

# @api_view(['POST'])
# def firebase_token_exchange(request):
#     data = request.data
#     firebase_token = data.get('firebase_token')
#     if not firebase_token:
#         return Response({'error': 'firebase_token is required'}, status=status.HTTP_400_BAD_REQUEST)
#     try:
#         decoded = firebase_auth.verify_id_token(firebase_token)
#         uid = decoded['uid']
#         email = decoded.get('email', f'{uid}@firebase.local')
#         User = get_user_model()
#         user, created = User.objects.get_or_create(username=uid, defaults={'email': email})
#         refresh = RefreshToken.for_user(user)
#         return Response({
#             'access': str(refresh.access_token),
#             'refresh': str(refresh)
#         })
#     except Exception as e:
#         return Response({'error': 'Invalid Firebase token', 'details': str(e)}, status=status.HTTP_400_BAD_REQUEST)

# JWT login endpoint for non-Firebase users
@api_view(['POST'])
def jwt_login(request):
    email = request.data.get('email')
    password = request.data.get('password')
    if not email or not password:
        return Response({'error': 'Email and password required'}, status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(username=email, password=password)
    if user is None:
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

    refresh = RefreshToken.for_user(user)
    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh)
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_profile(request):
    user = request.user
    user_experience = UserExperience.objects.get_or_create(user=user)[0]
    leaderboard = UserExperience.objects.annotate(annotated_total_points=F('total_points')).order_by('-annotated_total_points')
    rank = next((index + 1 for index, exp in enumerate(leaderboard) if exp.user == user), None)
    user_serializer = UserSerializer(user, many=False)
    user_profile_data = user_serializer.data
    user_profile_data['rank'] = rank if rank else "Unranked"
    total_experience = 0
    completed_modules = UserCompletedModules.objects.filter(user=user)
    completed_modules_data = []

    # Get total number of published modules
    total_modules = Modules.objects.filter(is_published=True).count()
    for completed in completed_modules:
        module = completed.module
        if module.category == 'Word Pronunciation':
            total_module_points = User_Word_Pronunciation_Answer.objects.filter(user=user, question__module=module).aggregate(total_points=Sum('points'))['total_points'] or 0
            total_experience += total_module_points
        elif module.category == 'Sentence Composition':
            total_module_points = 0
            user_answers = User_Module_Answer.objects.filter(user=user, question__module=module)
            for user_answer in user_answers:
                correct_answers = Answer.objects.filter(question=user_answer.question)
                for correct_answer in correct_answers:
                    if are_texts_similar(correct_answer.text, user_answer.text):
                        total_module_points += correct_answer.points
                        total_experience += correct_answer.points
        else:
            total_module_points = User_Module_Answer.objects.filter(user=user, question__module=module).filter(question__answer__text=F('text')).aggregate(total_points=Sum('question__answer__points'))['total_points'] or 0
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
    leaderboard = UserExperience.objects.annotate(annotated_total_points=F('total_points')).order_by('-annotated_total_points')[:10]
    leaderboard_data = []
    for user_experience in leaderboard:
        user = user_experience.user
        user_data = UserSerializer(user).data
        user_data['experience'] = user_experience.total_points
        leaderboard_data.append(user_data)
    return Response({'leaderboard': leaderboard_data})

@api_view(['GET'])
@permission_classes([IsAuthenticated]) 
def get_modules(request):
    modules = Modules.objects.prefetch_related('module_materials').all()
    serializer = ModulesSerializer(modules, many=True, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
def get_module(request, module_id: str):
    module = get_object_or_404(Modules, id=module_id)
    serializer = ModulesSerializer(module, many=False, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
def get_module_questions(request, module_id: str):
    questions = Question.objects.filter(module_id=module_id)
    serializer = QuestionSerializer(questions, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def get_question(request, question_id: str):
    question = get_object_or_404(Question, id=question_id)
    serializer = DynamicQuestionSerializer(question, many=False)
    return Response(serializer.data)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def post_module_answers(request, module_id: str):
    user = request.user
    module = get_object_or_404(Modules, id=module_id)

    if not is_module_unlocked(user, module):
        return Response({"error": "This module is locked"}, status=status.HTTP_403_FORBIDDEN)

    # Delete old answers
    if module.category == 'Word Pronunciation':
        User_Word_Pronunciation_Answer.objects.filter(user=user, question__module=module).delete()
    else:
        User_Module_Answer.objects.filter(user=user, question__module=module).delete()

    data = request.data.get("answers", [])
    total_points = 0
    score = 0
    questions_answered = 0

    # ✅ Use actual question count for accurate denominator
    total_questions = Question.objects.filter(module=module).count()

    if module.category == 'Word Pronunciation':
        # Deduplicate answers by question_id (keep last answer for each question)
        deduped = {}
        for answer in data:
            qid = answer.get("question_id")
            if qid:
                deduped[qid] = answer  # last occurrence wins
        for answer in deduped.values():
            question_id = answer.get("question_id")
            user_answer = answer.get("answer", "")

            question = Question.objects.filter(id=question_id, module=module).first()
            if not question or not hasattr(question, 'answer') or not question.answer:
                continue

            # Use same text similarity logic as other categories
            expected_answer = question.answer.text.strip().lower().replace(" ", "")
            user_text = user_answer.strip().lower().replace(" ", "")
            is_correct = expected_answer == user_text or are_texts_similar(expected_answer, user_text)

            insert_word_pronunciation(user, question, question.answer.points if is_correct else 0, user_answer)

            if is_correct:
                total_points += question.answer.points
                score += 1
            questions_answered += 1

        update_user_experience(user, total_points, module=module)

        if questions_answered == total_questions:
            UserCompletedModules.objects.get_or_create(user=user, module=module)
            unlock_next_module(user, module)

        return Response({
            "message": "Word Pro answers submitted successfully",
            "points_gained": total_points,
            "score": score,
            "total_questions": total_questions
        }, status=status.HTTP_200_OK)

    # 🔁 Handle other module categories as before
    for answer in data:
        question_id = answer.get("question_id")
        user_answer = answer.get("answer")
        correct = answer.get("correct", False)

        question = Question.objects.filter(id=question_id, module=module).first()
        if not question or not hasattr(question, 'answer') or not question.answer:
            continue

        category = module.category
        if category == 'Sentence Composition':
            correct_answer = question.answer.text.lower().strip().replace(" ", "")
            user_answer = user_answer.lower().strip().replace(" ", "") if user_answer else ""
            is_correct = correct or user_answer == correct_answer or are_texts_similar(correct_answer, user_answer)
        elif category in ['Reading Comprehension', 'Vocabulary Skills']:
            correct_answer = question.answer.text
            is_correct = correct or str(user_answer).strip() == str(correct_answer).strip()
        else:
            correct_answer = question.answer.text if hasattr(question.answer, 'text') else str(question.answer)
            is_correct = correct or str(user_answer).strip() == str(correct_answer).strip()

        save_user_answer(user, question, user_answer)

        if is_correct:
            total_points += question.answer.points
            score += 1

        questions_answered += 1

    # Only update experience if we have points to add
    if total_points > 0 or questions_answered > 0:
        update_user_experience(user, total_points, module=module)
    if questions_answered == total_questions:
        UserCompletedModules.objects.get_or_create(user=user, module=module)
        unlock_next_module(user, module)

    return Response({
        "message": "Answers submitted successfully",
        "points_gained": total_points,
        "score": score,
        "total_questions": total_questions  # ✅ added for consistency
    }, status=status.HTTP_200_OK)

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

  print(f"[PERMISSION CHECK] File path: {audio_path}")
  print(f"[PERMISSION CHECK] Exists: {os.path.exists(audio_path)}")
  print(f"[PERMISSION CHECK] Readable: {os.access(audio_path, os.R_OK)}")
  print(f"[PERMISSION CHECK] File mode: {oct(os.stat(audio_path).st_mode)}")

  try:
      # Convert M4A to WAV using pydub
    if audio_path.endswith('.m4a'):
        wav_path = audio_path.replace('.m4a', '.wav')
        audio = AudioSegment.from_file(audio_path, format="m4a")
        audio = audio.set_channels(1).set_frame_rate(16000)
        audio.export(wav_path, format="wav")
        os.remove(audio_path)  # Remove original M4A file

        # Set the converted WAV file path for Azure processing
        audio_path = wav_path

    print(f"[DEBUG] Submitting to Azure with audio path: {audio_path}")
    print(f"[DEBUG] File exists: {os.path.exists(audio_path)}")
    print(f"[DEBUG] File size: {os.path.getsize(audio_path)} bytes")

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
        
        if question and question.module.category == 'Word Pronunciation':
            # Only process if the question hasn't been answered yet
            if not has_answered_question(user, question):
                save_user_answer(user, question, result.text)
                # Calculate points based on pronunciation score (0-100 scale)
                points_earned = int(pronunciation_result.pronunciation_score)  # Convert to integer points
                
                # Save to User_Word_Pronunciation_Answer
                insert_word_pronunciation(user, question, points_earned, result.text)
                
                # Update user experience with the points
                update_user_experience(user, points_earned, module=question.module)
                
                # Check if all questions in the module are answered
                total_questions = question.module.questions_per_module.count()
                answered_questions = User_Word_Pronunciation_Answer.objects.filter(
                    user=user, 
                    question__module=question.module
                ).values('question').distinct().count()
                
                if answered_questions >= total_questions:
                    UserCompletedModules.objects.get_or_create(user=user, module=question.module)
                    unlock_next_module(user, question.module)

        score_point = int(pronunciation_result.pronunciation_score / 10)

        return Response({
            "recognized_text": result.text,
            "accuracy_score": pronunciation_result.accuracy_score,
            "fluency_score": pronunciation_result.fluency_score,
            "prosody_score": pronunciation_result.prosody_score,
            "pronunciation_score": pronunciation_result.pronunciation_score,
            "completeness_score": pronunciation_result.completeness_score,
            "score": 1 if score_point > 0 else 0,  # count as correct if got some points
            "points_earned": score_point,
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
    import traceback
    print(traceback.format_exc())
    return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

## current has error when removing temp files
  # finally:
  #   if os.path.exists(audio_path):
  #     os.remove(audio_path)  # Clean up the temporary file


def is_module_unlocked(user: Users, module: Modules):
    # Easy modules are always unlocked
    if module.difficulty == "Easy":
        return True

    # Get the previous difficulty level
    previous_level = get_previous_difficulty(module.difficulty)
    if not previous_level:
        return False

    # Get all published modules in the same category and previous difficulty level
    previous_modules = list(Modules.objects.filter(
        difficulty=previous_level,
        category=module.category,
        is_published=True
    ).values_list('id', flat=True))

    # If there are no previous modules, unlock by default
    if not previous_modules:
        return True

    # Get all completed modules by the user in the previous level
    completed_modules = set(UserCompletedModules.objects.filter(
        user=user,
        module_id__in=previous_modules
    ).values_list('module_id', flat=True))

    # Debug logging
    print(f"\n🔒 Module Lock Check:")
    print(f"- Module: {module.title} ({module.difficulty}, {module.category})")
    print(f"- Previous level: {previous_level}")
    print(f"- Total modules in previous level: {len(previous_modules)}")
    print(f"- Completed modules: {len(completed_modules)}")
    print(f"- Unlocked: {len(completed_modules) == len(previous_modules) and len(previous_modules) > 0}")

    # Only unlock if ALL previous-level modules in this category are completed
    # and there is at least one module in the previous level
    return len(completed_modules) == len(previous_modules) and len(previous_modules) > 0


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


def update_user_experience(user, points, module=None):
    logger.info(f"Updating experience for user {user.id} - Adding {points} points for module: {module.id if module else 'None'}")
    
    user_experience, created = UserExperience.objects.get_or_create(user=user)
    logger.info(f"UserExperience {'created' if created else 'retrieved'} for user {user.id}")

    points_before = user_experience.total_points
    
    if module:
        logger.info(f"Processing module {module.id} ({module.title}) of type {module.category}")
        # Remove old XP earned from this same module
        if module.category == 'Word Pronunciation':
            old_points = User_Word_Pronunciation_Answer.objects.filter(
                user=user, question__module=module
            ).aggregate(total=Sum('points'))['total'] or 0
            logger.info(f"Word Pronunciation module - Old points to remove: {old_points}")
            
        elif module.category == 'Sentence Composition':
            old_points = 0
            user_answers = User_Module_Answer.objects.filter(user=user, question__module=module)
            logger.info(f"Found {user_answers.count()} user answers for Sentence Composition")
            
            for user_answer in user_answers:
                correct_answers = Answer.objects.filter(question=user_answer.question)
                logger.info(f"Checking answer for question {user_answer.question.id} - User answer: {user_answer.text}")
                
                for correct_answer in correct_answers:
                    logger.info(f"  Comparing with correct answer: {correct_answer.text}")
                    if are_texts_similar(correct_answer.text, user_answer.text):
                        old_points += correct_answer.points
                        logger.info(f"  Match found! Adding {correct_answer.points} points (total: {old_points})")
        else:
            old_points = User_Module_Answer.objects.filter(
                user=user, 
                question__module=module,
                question__answer__text=F('text')
            ).aggregate(total=Sum('question__answer__points'))['total'] or 0
            logger.info(f"Standard module - Old points to remove: {old_points}")

        logger.info(f"Removing {old_points} old points")
        user_experience.total_points -= old_points
        logger.info(f"Points after removing old points: {user_experience.total_points}")

    logger.info(f"Adding {points} new points")
    user_experience.total_points += points
    user_experience.total_points = max(user_experience.total_points, 0)  # prevent negative XP
    
    logger.info(f"Saving user experience - Before: {points_before}, After: {user_experience.total_points}")
    user_experience.save()
    
    # Verify the save
    updated_exp = UserExperience.objects.get(user=user)
    if updated_exp.total_points != user_experience.total_points:
        logger.error(f"POINTS NOT SAVED CORRECTLY! Expected: {user_experience.total_points}, Got: {updated_exp.total_points}")
    else:
        logger.info("Points updated successfully")

  
def insert_word_pronunciation(user, question, result, text):
    # Replace .create() with update_or_create()
    User_Word_Pronunciation_Answer.objects.update_or_create(
        user=user,
        question=question,
        defaults={
            'text': text,
            'points': int(result),
        }
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

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_category_progress(request):
    user = request.user
    categories = Modules.objects.values_list('category', flat=True).distinct()
    response_data = {}

    for category in categories:
        modules = Modules.objects.filter(category=category)
        total = modules.count()
        completed = UserCompletedModules.objects.filter(user=user, module__in=modules).count()

        response_data[category] = {
            "total": total,
            "completed": completed
        }

    return Response(response_data, status=status.HTTP_200_OK)
