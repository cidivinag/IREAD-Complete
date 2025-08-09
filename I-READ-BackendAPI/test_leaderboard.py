import os
import sys
import django

# Set up Django environment
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)

# Set the correct Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'I_READ.settings')

# Add the parent directory to Python path
sys.path.append(os.path.dirname(BASE_DIR))

try:
    django.setup()
except Exception as e:
    print(f"Error setting up Django: {e}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"Python path: {sys.path}")
    raise

from apps.models import Users, UserExperience, Modules, Question, Answer, User_Module_Answer
from django.db.models import Sum, F

def test_leaderboard():
    # Get all users with their experience points
    leaderboard = UserExperience.objects.annotate(
        annotated_total_points=F('total_points')
    ).order_by('-annotated_total_points').select_related('user')
    
    print("\n=== Current Leaderboard ===")
    print(f"{'Rank':<5} | {'User':<20} | {'Points':<10}")
    print("-" * 40)
    
    prev_points = None
    rank = 0
    for i, user_exp in enumerate(leaderboard, 1):
        if prev_points is not None and user_exp.total_points < prev_points:
            rank = i
        elif prev_points is None:
            rank = 1
            
        print(f"{rank:<5} | {user_exp.user.username:<20} | {user_exp.total_points:<10}")
        prev_points = user_exp.total_points

def test_user_points(user_id):
    user = Users.objects.get(id=user_id)
    user_exp = UserExperience.objects.get_or_create(user=user)[0]
    
    print(f"\n=== User Points Details ===")
    print(f"User: {user.username}")
    print(f"Total Points: {user_exp.total_points}")
    
    # Get points from module answers
    module_points = User_Module_Answer.objects.filter(
        user=user,
        question__answer__text=F('text')
    ).aggregate(total=Sum('question__answer__points'))['total'] or 0
    
    print(f"Points from module answers: {module_points}")

if __name__ == "__main__":
    test_leaderboard()
    
    # Test with a specific user ID (change this to an existing user ID)
    try:
        test_user_points(1)  # Change 1 to an actual user ID
    except Users.DoesNotExist:
        print("\nUser not found. Please provide a valid user ID.")
