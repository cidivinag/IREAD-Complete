from django.conf import settings
from supabase import Client, create_client


def create_supabase_client() -> Client:
    url: str = settings.SUPABASE_PROJECT_URL
    key: str = settings.SUPABASE_API_KEY
    supabase: Client = create_client(url, key)
    return supabase
