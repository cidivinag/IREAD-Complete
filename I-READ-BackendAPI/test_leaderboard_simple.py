def test_leaderboard():
    """
    Simple test function to check leaderboard and user points.
    Run this from Django shell with: exec(open('test_leaderboard_simple.py').read())
    """
    from apps.models import Users, UserExperience
    from django.db.models import F
    
    print("\n=== Current Leaderboard ===")
    print(f"{'Rank':<5} | {'User':<20} | {'Points':<10}")
    print("-" * 40)
    
    # Get leaderboard data
    leaderboard = UserExperience.objects.annotate(
        annotated_total_points=F('total_points')
    ).order_by('-annotated_total_points').select_related('user')
    
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
    """Test points for a specific user"""
    from apps.models import Users, UserExperience, User_Module_Answer
    from django.db.models import Sum, F
    
    try:
        user = Users.objects.get(id=user_id)
        user_exp = UserExperience.objects.get_or_create(user=user)[0]
        
        print(f"\n=== User Points Details ===")
        print(f"User: {user.username} (ID: {user.id})")
        print(f"Total Points: {user_exp.total_points}")
        
        # Get points from module answers
        module_points = User_Module_Answer.objects.filter(
            user=user,
            question__answer__text=F('text')
        ).aggregate(total=Sum('question__answer__points'))['total'] or 0
        
        print(f"Points from module answers: {module_points}")
        
    except Users.DoesNotExist:
        print(f"\nUser with ID {user_id} not found.")

# Uncomment one of these lines to run a test
# test_leaderboard()
# test_user_points(1)  # Replace 1 with an actual user ID
