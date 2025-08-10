import pandas as pd
from django.core.management.base import BaseCommand
from django.db import transaction
from apps.models import Students, Users, Sections, Teachers, AccessToken, UserExperience
from django.utils.dateparse import parse_date
from datetime import datetime
from django.contrib.auth import get_user_model
from django.utils import timezone

class Command(BaseCommand):
    help = 'Import users and students from Excel.'

    def add_arguments(self, parser):
        parser.add_argument('excel_file', type=str, help='Path to the Excel file.')

    def handle(self, *args, **options):
        excel_file = options['excel_file']

        # Header row is Excel row 11 (0-indexed as 10)
        df = pd.read_excel(excel_file, header=10)
        df.columns = [col.strip() for col in df.columns]

        success_count = 0
        error_rows = []

        for idx, row in df.iterrows():
            row = row.fillna('').apply(lambda x: str(x).strip())

            try:
                with transaction.atomic():
                    username     = row.get('Username', '')
                    email        = row.get('Email', '')
                    password     = row.get('Password', '')
                    first_name   = row.get('First name', '')
                    middle_name  = row.get('Middle name', '')   # optional
                    last_name    = row.get('Last name', '')
                    strand       = row.get('Strand', '')
                    section_name = row.get('Section (section name)', '')
                    birthday     = row.get('Birthday (YYYY-MM-DD)', '')
                    address      = row.get('Address', '')        # optional

                    # 1) Skip rows with blank Email (no error)
                    if not email:
                        continue

                    # 2) Enforce required fields (email already ensured above)
                    required_fields = {
                        'Username': username,
                        'Password': password,
                        'First name': first_name,
                        'Last name': last_name,
                        'Strand': strand,
                        'Section (section name)': section_name,
                        'Birthday (YYYY-MM-DD)': birthday,
                    }
                    missing = [k for k, v in required_fields.items() if not v]
                    if missing:
                        raise ValueError(f"Missing required field(s): {', '.join(missing)}")

                    # 3) Section (case-insensitive; auto-create if not exists)
                    section_name = section_name.strip()
                    section = Sections.objects.filter(section__iexact=section_name).first()
                    if not section:
                        self.stdout.write(self.style.WARNING(f"Section '{section_name}' not found. Creating..."))
                        User = get_user_model()
                        admin_teacher = Teachers.objects.filter(user__is_superuser=True).first()
                        if not admin_teacher:
                            admin_user = User.objects.filter(is_superuser=True).first()
                            if not admin_user:
                                admin_user = User.objects.create_superuser(
                                    email='admin@example.com', password='admin123',
                                    first_name='Admin', last_name='User'
                                )
                            admin_teacher = Teachers.objects.create(user=admin_user)

                        section = Sections.objects.create(section=section_name, created_by=admin_teacher)

                        from apps.utils import generate_access_token
                        access_token = AccessToken.objects.create(
                            created_by=admin_teacher,
                            access_token=generate_access_token(20)
                        )
                        section.access_token = access_token
                        section.save()
                        self.stdout.write(self.style.SUCCESS(f"Created section: {section_name}"))

                    # 4) Parse birthday (required)
                    birthday_parsed = None
                    if birthday:
                        try:
                            if isinstance(birthday, str):
                                date_part = birthday.split()[0]
                                birthday_parsed = parse_date(date_part) or pd.to_datetime(date_part).date()
                            elif isinstance(birthday, pd.Timestamp):
                                birthday_parsed = birthday.date()
                            elif isinstance(birthday, (int, float)):
                                birthday_parsed = (datetime(1899, 12, 30) + pd.Timedelta(days=float(birthday))).date()
                            elif hasattr(birthday, 'date'):
                                birthday_parsed = birthday.date()
                        except Exception:
                            birthday_parsed = None
                    if not birthday_parsed:
                        raise ValueError("Invalid 'Birthday (YYYY-MM-DD)' format")

                    # 5) Create or update user (email is the identity)
                    user = Users.objects.filter(email=email).first()
                    user_changed = False
                    user_changes = {}

                    if user:
                        # username
                        if user.username != username:
                            user_changes["username"] = {"from": user.username or "", "to": username}
                            user.username = username
                            user_changed = True

                        # first_name
                        if user.first_name != first_name:
                            user_changes["first_name"] = {"from": user.first_name or "", "to": first_name}
                            user.first_name = first_name
                            user_changed = True

                        # last_name
                        if user.last_name != last_name:
                            user_changes["last_name"] = {"from": user.last_name or "", "to": last_name}
                            user.last_name = last_name
                            user_changed = True

                        # middle_name (optional: only update if provided)
                        if middle_name and user.middle_name != middle_name:
                            user_changes["middle_name"] = {"from": user.middle_name or "", "to": middle_name}
                            user.middle_name = middle_name
                            user_changed = True

                        # password: only update if provided AND different from existing
                        if password:
                            try:
                                already_same = user.check_password(password)
                            except Exception:
                                already_same = False

                            if not already_same:
                                user.set_password(password)
                                user_changes["password"] = "(changed)"
                                user_changed = True

                        if user_changed:
                            user.save()
                            self.stdout.write(self.style.WARNING(f"Updated user: {email}"))
                            self.stdout.write(f"  Changes: {user_changes}")
                        else:
                            self.stdout.write(self.style.SUCCESS(f"No user changes: {email}"))
                    else:
                        user = Users(
                            username=username,
                            email=email,
                            first_name=first_name,
                            last_name=last_name,
                            date_joined=timezone.now(),  # ensure NOT NULL
                        )
                        if middle_name:
                            user.middle_name = middle_name
                        user.set_password(password)
                        user.save()
                        
                        # Create UserExperience record for the new user
                        UserExperience.objects.create(user=user, total_points=0)
                        
                        user_changed = True
                        self.stdout.write(self.style.SUCCESS(f"Created user: {email}"))

                    # 6) Create or update student
                    student, created = Students.objects.get_or_create(
                        user=user,
                        defaults={
                            'strand': strand,
                            'section': section,
                            'birthday': birthday_parsed,
                            'address': address if address else '',
                        }
                    )

                    student_changed = False
                    student_changes = {}

                    if not created:
                        # Required syncs
                        if student.strand != strand:
                            student_changes["strand"] = {"from": student.strand or "", "to": strand}
                            student.strand = strand
                            student_changed = True

                        if student.section_id != section.id:
                            student_changes["section"] = {
                                "from": getattr(student.section, "section", "") or "",
                                "to": section.section
                            }
                            student.section = section
                            student_changed = True

                        if student.birthday != birthday_parsed:
                            student_changes["birthday"] = {
                                "from": student.birthday.isoformat() if student.birthday else "",
                                "to": birthday_parsed.isoformat() if birthday_parsed else ""
                            }
                            student.birthday = birthday_parsed
                            student_changed = True

                        # Optional address: update only if provided and different
                        if address and student.address != address:
                            student_changes["address"] = {"from": student.address or "", "to": address}
                            student.address = address
                            student_changed = True

                        if student_changed:
                            student.save()
                            self.stdout.write(self.style.WARNING(f"Updated student: {email}"))
                            self.stdout.write(f"  Changes: {student_changes}")
                        else:
                            self.stdout.write(self.style.SUCCESS(f"No student changes: {email}"))

                    if user_changed or created or student_changed:
                        success_count += 1

            except Exception as e:
                excel_row = idx + 12  # header row (11) + 1-based index
                error_rows.append((excel_row, str(e)))

        self.stdout.write(self.style.SUCCESS(f"Imported {success_count} users/students."))
        if error_rows:
            self.stdout.write(self.style.ERROR("Errors encountered:"))
            for excel_row, error in error_rows:
                self.stdout.write(f"Excel Row {excel_row}: {error}")
