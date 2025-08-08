import pandas as pd
from django.core.management.base import BaseCommand
from django.db import transaction
from apps.models import Students, Users, Sections, Teachers, AccessToken
from django.utils.dateparse import parse_date
from datetime import datetime
from django.contrib.auth import get_user_model

class Command(BaseCommand):
    help = 'Import users and students from Excel.'

    def add_arguments(self, parser):
        parser.add_argument('excel_file', type=str, help='Path to the Excel file.')

    def handle(self, *args, **options):
        excel_file = options['excel_file']

        # Header row is Excel row 11 (0-indexed as 10)
        df = pd.read_excel(excel_file, header=10)
        df.columns = [col.strip() for col in df.columns]  # Clean column headers

        success_count = 0
        error_rows = []

        for idx, row in df.iterrows():
            row = row.fillna('').apply(lambda x: str(x).strip())  # Clean row values
            try:
                with transaction.atomic():
                    username = row.get('Username')
                    email = row.get('Email')
                    password = row.get('Password')
                    first_name = row.get('First name')
                    last_name = row.get('Last name')
                    strand = row.get('Strand', '')
                    section_name = row.get('Section (section name)')
                    birthday = row.get('Birthday (YYYY-MM-DD)')
                    address = row.get('Address', '')

                    # Validate required fields
                    required_fields = {
                        'Username': username,
                        'Email': email,
                        'Password': password,
                        'First name': first_name,
                        'Last name': last_name,
                        'Strand': strand,
                        'Section (section name)': section_name,
                        'Birthday (YYYY-MM-DD)': birthday
                    }
                    missing_fields = [
                        field for field, value in required_fields.items()
                        if pd.isna(value) or str(value).strip() == ''
                    ]
                    if missing_fields:
                        if len(missing_fields) == 1:
                            raise ValueError(f"Missing required field: {missing_fields[0]}")
                        else:
                            raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

                    # Section lookup - case insensitive and auto-create if not exists
                    section_name = str(section_name).strip()
                    if not section_name:
                        raise ValueError("Section name cannot be empty")
                        
                    # Try to find existing section (case insensitive)
                    section = Sections.objects.filter(section__iexact=section_name).first()
                    
                    # If section doesn't exist, create it with a default teacher
                    if not section:
                        self.stdout.write(self.style.WARNING(f"Section '{section_name}' not found. Creating new section..."))
                        
                        # Get or create a default teacher
                        from django.contrib.auth import get_user_model
                        User = get_user_model()
                        
                        # Try to find an admin user who is also a teacher
                        admin_teacher = Teachers.objects.filter(
                            user__is_superuser=True
                        ).first()
                        
                        if not admin_teacher:
                            # If no admin teacher exists, create one
                            admin_user = User.objects.filter(is_superuser=True).first()
                            if not admin_user:
                                # Create a superuser if none exists
                                admin_user = User.objects.create_superuser(
                                    email='admin@example.com',
                                    password='admin123',
                                    first_name='Admin',
                                    last_name='User'
                                )
                            admin_teacher = Teachers.objects.create(user=admin_user)
                        
                        # Create the section with the admin teacher
                        section = Sections(
                            section=section_name,
                            created_by=admin_teacher
                        )
                        section.save()
                        
                        # Create an access token for the section
                        from apps.utils import generate_access_token
                        from apps.models import AccessToken
                        
                        access_token = AccessToken.objects.create(
                            created_by=admin_teacher,
                            access_token=generate_access_token(20)
                        )
                        section.access_token = access_token
                        section.save()
                        
                        self.stdout.write(self.style.SUCCESS(f"Created new section: {section_name} with admin teacher"))

                    # Parse birthday
                    birthday_parsed = None
                    if pd.notna(birthday) and str(birthday).strip():
                        try:
                            # Handle string input (e.g., '2004-11-01 00:00:00')
                            if isinstance(birthday, str):
                                # Extract just the date part before space
                                date_part = birthday.split()[0]
                                birthday_parsed = parse_date(date_part)
                            # Handle pandas Timestamp
                            elif isinstance(birthday, pd.Timestamp):
                                birthday_parsed = birthday.date()
                            # Handle Excel numeric dates
                            elif isinstance(birthday, (int, float)):
                                birthday_parsed = (datetime(1899, 12, 30) + pd.Timedelta(days=float(birthday))).date()
                            # Handle datetime objects
                            elif hasattr(birthday, 'date'):
                                birthday_parsed = birthday.date()
                            
                            # If still not parsed, try pandas to_datetime as last resort
                            if not birthday_parsed:
                                birthday_parsed = pd.to_datetime(birthday).date()
                                
                        except Exception:
                            # If parsing fails, the required field validation will catch it
                            pass

                    # Create or update user
                    user = Users.objects.filter(email=email).first()
                    user_updated = False

                    if user:
                        # Check if any user data has changed
                        if (user.username != username or 
                            user.first_name != first_name or 
                            user.last_name != last_name or 
                            (password and not user.check_password(password))):
                            
                            # Update existing user data
                            user.username = username
                            user.first_name = first_name
                            user.last_name = last_name
                            if password:  # Only update password if provided
                                user.set_password(password)
                            user.save()
                            user_updated = True
                            self.stdout.write(self.style.WARNING(f"Updated existing user: {email}"))
                        else:
                            self.stdout.write(self.style.SUCCESS(f"No changes detected for user: {email}"))
                            user_updated = False  # No need to update student if user wasn't updated
                    else:
                        # Create new user
                        user = Users(
                            username=username,
                            email=email,
                            first_name=first_name,
                            last_name=last_name,
                        )
                        user.set_password(password)
                        user.save()
                        user_updated = True
                        self.stdout.write(self.style.SUCCESS(f"Created new user: {email}"))


                    # Only proceed with student update if user was created or updated
                    if not user or user_updated:
                        student, created = Students.objects.get_or_create(
                            user=user,
                            defaults={
                                'strand': strand,
                                'section': section,
                                'birthday': birthday_parsed,
                                'address': address
                            }
                        )
                        student_updated = False
                        if not created:
                            # Check if any student data has changed
                            if (student.strand != strand or 
                                student.section != section or 
                                student.birthday != birthday_parsed or 
                                student.address != address):
                                
                                student.strand = strand
                                student.section = section
                                student.birthday = birthday_parsed
                                student.address = address
                                student.save()
                                student_updated = True
                                self.stdout.write(self.style.WARNING(f"Updated student record for: {email}"))
                            else:
                                self.stdout.write(self.style.SUCCESS(f"No changes detected in student record for: {email}"))
                        
                        # Only count as success if either user or student was created/updated
                        if user_updated or created or student_updated:
                            success_count += 1
                    else:
                        # Skip student update if user wasn't updated and no changes were made
                        self.stdout.write(self.style.SUCCESS(f"Skipped - no changes needed for: {email}"))
                        continue

            except Exception as e:
                # Add 12 to get the actual Excel row number (11 for header + 1 for 1-based index + idx)
                excel_row = idx + 12
                error_rows.append((excel_row, str(e)))

        self.stdout.write(self.style.SUCCESS(f"Imported {success_count} users and students."))
        if error_rows:
            self.stdout.write(self.style.ERROR("Errors encountered:"))
            for excel_row, error in error_rows:
                self.stdout.write(f"Excel Row {excel_row}: {error}")
