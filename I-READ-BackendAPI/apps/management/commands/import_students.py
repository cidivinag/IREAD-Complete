import pandas as pd
from django.core.management.base import BaseCommand
from django.db import transaction
from apps.models import Students, Users, Sections
from django.utils.dateparse import parse_date

class Command(BaseCommand):
    help = 'Import users and students from Excel.'

    def add_arguments(self, parser):
        parser.add_argument('excel_file', type=str, help='Path to the Excel file.')

    def handle(self, *args, **options):
        excel_file = options['excel_file']

        # Header row is Excel row 11 → 0-indexed = 10
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
                        'Birthday (YYYY-MM-DD)': birthday,
                        'Address': address,
                    }
                    for field, value in required_fields.items():
                        if pd.isna(value) or str(value).strip() == '':
                            raise ValueError(f"Missing required field: {field}")

                    # Section lookup
                    section = Sections.objects.filter(section=section_name).first()
                    if not section:
                        raise ValueError(f"Section not found: {section_name}")

                    # Parse birthday
                    birthday_parsed = None
                    if birthday:
                        if isinstance(birthday, pd.Timestamp):
                            birthday_parsed = birthday.date()
                        else:
                            birthday_parsed = parse_date(str(birthday))

                    # Create or update user
                    user = Users.objects.filter(email=email).first()

                    if user:
                        self.stdout.write(self.style.WARNING(f"User already exists: {email}. Skipping import for this user."))
                        continue  # Skip to next row without creating/updating anything
                    else:
                        user = Users(
                            username=username,
                            email=email,
                            first_name=first_name,
                            last_name=last_name,
                        )
                        user.set_password(password)
                        user.save()


                    # Create or update student
                    student, created = Students.objects.get_or_create(
                        user=user,
                        defaults={
                            'strand': strand,
                            'section': section,
                            'birthday': birthday_parsed,
                            'address': address
                        }
                    )
                    if not created:
                        student.strand = strand
                        student.section = section
                        student.birthday = birthday_parsed
                        student.address = address
                        student.save()

                    success_count += 1

            except Exception as e:
                error_rows.append((idx + 2, str(e)))  # +2 = header offset

        self.stdout.write(self.style.SUCCESS(f"Imported {success_count} users and students."))
        if error_rows:
            self.stdout.write(self.style.ERROR("Errors encountered:"))
            for row_num, error in error_rows:
                self.stdout.write(f"Row {row_num}: {error}")
