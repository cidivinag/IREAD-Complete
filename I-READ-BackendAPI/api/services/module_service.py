from apps.models import Question, User_Module_Answer

class ModuleService:
    @staticmethod
    def create_user_module_answer(user, question_id, answer_text):
        try:
            # Fetch the relevant question
            question = Question.objects.get(id=question_id)

            # Create and save the user's answer
            user_answer = User_Module_Answer.objects.create(
                user=user, question=question, text=answer_text
            )
            return user_answer
        except Question.DoesNotExist:
            raise ValueError("Question not found.")
