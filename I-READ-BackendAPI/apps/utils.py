import datetime
import mimetypes
import os
import secrets
import string
import tempfile
from django.conf import settings
from apps.supabase import create_supabase_client
from fuzzywuzzy import fuzz
supabase = create_supabase_client()


def generate_access_token(length=16):
    """Generates a secure random access token with the specified length.

    Args:
        length (int): The length of the access token. Default is 16.

    Returns:
        str: The generated access token.
    """
    characters = string.ascii_letters + string.digits
    token = "".join(secrets.choice(characters) for _ in range(length))
    return token


def upload_file_to_storage(file):
    now = datetime.datetime.now()
    current_datetime = now.strftime("%Y_%m_%d_%H_%M_%S")

    # Get file extension from the file name
    file_extension = os.path.splitext(file.name)[1]

    # Detect the content type based on the file extension
    content_type, _ = mimetypes.guess_type(file.name)
    if content_type is None:
        content_type = "application/octet-stream"  # Fallback to a generic binary type

    # Define the storage path with timestamp and extension
    storage_path = f"materials/{current_datetime}{file_extension}"

    # Ensure the directory exists
    local_storage_dir = os.path.join(settings.MEDIA_ROOT, "materials")
    os.makedirs(local_storage_dir, exist_ok=True)

    # Save the file to the local storage path
    full_path = os.path.join(local_storage_dir, f"{current_datetime}{file_extension}")
    with open(full_path, "wb") as destination:
        for chunk in file.chunks():
            destination.write(chunk)

    # Return the file path and URL
    return {
        "path": storage_path,
        "file_url": os.path.join(settings.MEDIA_URL, storage_path),
        "content_type": content_type,
    }


def generate_signed_url(file_path):
    response = supabase.storage.from_("modules").get_public_url(file_path)
    return response

def are_texts_similar(text1, text2, threshold=99):
    # Preprocess texts: remove spaces and convert to lowercase
    text1_processed = text1.replace(" ", "").lower()
    text2_processed = text2.replace(" ", "").lower()
    ratio = fuzz.ratio(text1_processed, text2_processed)
    print(f"Similarity ratio between '{text1}' and '{text2}': {ratio}")
    return ratio >= threshold