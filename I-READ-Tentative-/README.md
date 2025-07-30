# I-Read Mobile Application (Flutter + Django)

## 📱 Features
- **Quiz Modules**
  - Vocabulary exercises
  - Reading comprehension
  - Sentence composition
  - Word pronunciation with scoring
- **Gamification**
  - Experience points system
  - Leaderboard
  - Progressive module unlocking
- **Backend Services**
  - RESTful API with Django Ninja
  - JWT Authentication
  - File management with Supabase
  - Speech analysis using Azure Cognitive Services

## 🛠 Tech Stack
- **Frontend**: Flutter
- **Backend**: Django 5.1.2 with Django Ninja
- **Database**: SQLite (Development), PostgreSQL (Production)
- **Authentication**: JWT
- **Cloud Services**:
  - Azure Cognitive Services (Speech-to-Text)
  - Supabase (File Storage)
- **APIs**: RESTful API with OpenAPI documentation

# 🚀 Setup Instructions

## Prerequisites
- Python 3.9+
- Node.js & npm (for frontend)
- Flutter SDK
- Azure Cognitive Services account
- Supabase account

## Backend Setup (Django)

### 1. Clone the repository
```bash
git clone https://github.com/cidivinag/IREAD-Complete.git
cd IREAD-Complete/I-READ-BackendAPI
```

### 2. Create and activate virtual environment
```bash
# Windows
python -m venv venv
.\venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### 3. Install dependencies
```bash
pip install -r requirements.txt
```

### 4. Configure environment variables
Create a `.env` file in the root directory with the following variables:
```env
DEBUG=True
SECRET_KEY=your-secret-key
DATABASE_URL=sqlite:///db.sqlite3
AZURE_SPEECH_KEY=your-azure-speech-key
AZURE_SERVICE_REGION=your-azure-region
SUPABASE_URL=your-supabase-url
SUPABASE_KEY=your-supabase-key
```

### 5. Run migrations
```bash
python manage.py makemigrations
python manage.py migrate
```

### 6. Create superuser (optional)
```bash
python manage.py createsuperuser
```

### 7. Run the development server
```bash
python manage.py runserver
```

### 8. Access API Documentation
Visit `http://127.0.0.1:8000/api/docs` for interactive API documentation.

## Frontend Setup (Flutter)

### 1. Navigate to frontend directory
```bash
cd ../I-READ-Tentative-
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure environment

#### Update API Configuration
Before running the app, make sure to update the API base URL in:
`lib/constant.dart`

```dart
class Constants {
  // ✅ Use your real server IP or domain in production
  // For local development (Android Emulator):
  // static const baseUrl = 'http://10.0.2.2:8000';
  
  // For physical device or production:
  // static const baseUrl = 'https://your-production-domain.com';
  
  static const baseUrl = 'http://10.0.2.2:8000';  // Default for emulator
}
```

#### Environment Variables
Create a `.env` file in the root directory with your backend URL:
```env
API_BASE_URL=http://your-backend-url:8000/api
```

### 4. Run the application
```bash
flutter run
```

## 📚 API Documentation

### Authentication
- **Login**: `POST /api/auth/login/`
- **Register**: `POST /api/auth/register/`
- **Refresh Token**: `POST /api/auth/refresh/`

### Modules
- **List Modules**: `GET /api/modules/`
- **Module Details**: `GET /api/modules/{module_id}/`
- **Module Content**: `GET /api/modules/{module_id}/content/`

### User Progress
- **User Progress**: `GET /api/progress/`
- **Update Progress**: `POST /api/progress/update/`
- **Leaderboard**: `GET /api/leaderboard/`

## 🔒 Security
- JWT-based authentication
- CORS configured for mobile app domains
- Secure file uploads with signed URLs
- Environment-based configuration

## 📦 Dependencies
Key Python packages:
- Django 5.1.2
- Django Ninja 1.3.0
- Django REST Framework 3.15.2
- Azure Cognitive Services Speech SDK
- Supabase Python Client

## 🐍 Python Shell Commands

### List All Modules
```python
from apps.models import Modules

for m in Modules.objects.all():
    print(f"{m.id} - {m.title}")
```

### Check Module Questions
```python
# Replace the module ID with the one you want to check
mod1 = Modules.objects.get(id="6ca9a882-af6b-4b3a-bf71-5cf3338a76e3")
print(mod1.questions_per_module.all())
```

### Reset User Progress
```python
from django.contrib.auth import get_user_model
from apps.models import (
    UserExperience,
    UserCompletedModules,
    User_Module_Answer,
    User_Word_Pronunciation_Answer
)

# Get the user
User = get_user_model()
user = User.objects.get(email='user@example.com')  # Replace with actual email

# 1. Delete all answered module questions
User_Module_Answer.objects.filter(user=user).delete()

# 2. Delete all pronunciation answers
User_Word_Pronunciation_Answer.objects.filter(user=user).delete()

# 3. Delete completed module records
UserCompletedModules.objects.filter(user=user).delete()

# 4. Reset XP to 0
experience = UserExperience.objects.get(user=user)
experience.total_points = 0
experience.save()

print("✅ User progress has been reset.")
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

### Go into the backend directory
- cd i-read-backendapi

### Set up virtual environment
- python -m venv venv
- source venv/bin/activate

### Install dependencies
- pip install -r requirements.txt

### Run migrations and start server
- python manage.py makemigrations
- python manage.py migrate
- python manage.py runserver
