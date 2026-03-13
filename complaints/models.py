from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
import math

class OTP(models.Model):
    email = models.EmailField()
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)

class Complaint(models.Model):
    COMPLAINT_TYPES = [
        ('police', 'Police Complaint'),
        ('traffic', 'Traffic Complaint'),
        ('construction', 'Construction Complaint'),
        ('water', 'Water Supply'),
        ('electricity', 'Electricity'),
        ('garbage', 'Garbage/Sanitation'),
        ('road', 'Road/Pothole'),
        ('drainage', 'Drainage/Sewage'),
        ('illegal', 'Illegal Activities'),
        ('transportation', 'Transportation'),
        ('cyber', 'Cyber Crime'),
        ('other', 'Other Complaint'),
    ]
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    PRIORITY_CHOICES = [
        ('high', 'High'),
        ('medium', 'Medium'),
        ('normal', 'Normal'),
    ]
    REOPEN_WINDOW_DAYS = 7
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    complaint_type = models.CharField(max_length=20, choices=COMPLAINT_TYPES)
    subcategory = models.CharField(max_length=200, blank=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='normal')
    preferred_contact_phone = models.BooleanField(default=False)
    preferred_contact_email = models.BooleanField(default=False)
    preferred_contact_sms = models.BooleanField(default=False)
    title = models.CharField(max_length=200)
    description = models.TextField()
    latitude = models.FloatField()
    longitude = models.FloatField()
    city = models.CharField(max_length=100, blank=True)
    state = models.CharField(max_length=100, blank=True)
    pincode = models.CharField(max_length=10, blank=True)
    address = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Guest complaint fields
    guest_name = models.CharField(max_length=200, blank=True)
    guest_email = models.EmailField(blank=True)
    guest_phone = models.CharField(max_length=15, blank=True)
    complaint_number = models.CharField(max_length=20, unique=True, blank=True)
    
    # Department assignment fields
    assigned_department = models.ForeignKey('Department', on_delete=models.SET_NULL, null=True, blank=True)
    assigned_at = models.DateTimeField(null=True, blank=True)
    work_status = models.CharField(max_length=20, choices=[
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('process', 'Process'),
        ('reopened', 'Reopened'),
        ('solved', 'Solved'),
        ('rejected', 'Rejected')
    ], default='pending')
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolution_notes = models.TextField(blank=True)
    citizen_rating = models.PositiveSmallIntegerField(null=True, blank=True)
    citizen_feedback = models.TextField(blank=True)
    citizen_rated_at = models.DateTimeField(null=True, blank=True)
    reopen_count = models.PositiveIntegerField(default=0)
    reopened_at = models.DateTimeField(null=True, blank=True)
    reopen_reason = models.TextField(blank=True)
    reopen_requested_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reopened_requests'
    )
    
    def save(self, *args, **kwargs):
        if not self.complaint_number:
            import random
            self.complaint_number = f"SC{random.randint(100000, 999999)}"
        
        # Auto-assign to nearest department on creation
        if not self.assigned_department and self.latitude and self.longitude:
            from django.utils import timezone
            nearest_dept = self.get_nearest_department()
            if nearest_dept:
                self.assigned_department = nearest_dept
                self.assigned_at = timezone.now()
        
        super().save(*args, **kwargs)
    
    def get_assigned_department(self):
        """Get the department this complaint should be assigned to"""
        supported_types = {value for value, _label in Department.DEPARTMENT_TYPES}
        if self.complaint_type in supported_types:
            return self.complaint_type
        return 'other'

    @staticmethod
    def _distance_km(lat1, lon1, lat2, lon2):
        """Great-circle distance between two points in kilometers."""
        r = 6371.0
        phi1 = math.radians(float(lat1))
        phi2 = math.radians(float(lat2))
        d_phi = math.radians(float(lat2) - float(lat1))
        d_lambda = math.radians(float(lon2) - float(lon1))
        a = (
            math.sin(d_phi / 2) ** 2
            + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
        )
        return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    def _pick_nearest_department(self, departments):
        """
        Pick nearest department by coordinates.
        Falls back to first department when complaint coordinates are not usable.
        """
        department_list = list(departments)
        if not department_list:
            return None

        try:
            complaint_lat = float(self.latitude)
            complaint_lon = float(self.longitude)
        except (TypeError, ValueError):
            return department_list[0]

        nearest = None
        nearest_distance = None
        for dept in department_list:
            if dept.latitude is None or dept.longitude is None:
                continue
            distance = self._distance_km(complaint_lat, complaint_lon, dept.latitude, dept.longitude)
            if nearest_distance is None or distance < nearest_distance:
                nearest = dept
                nearest_distance = distance

        return nearest or department_list[0]
    
    def get_nearest_department(self):
        """
        Assign to nearest matching department by geo-distance.
        Priority:
        1) same city + state
        2) same state
        3) any city/state
        """
        dept_type = self.get_assigned_department()
        department_types = [dept_type]

        legacy_mapping = {
            'illegal': 'police',
            'transportation': 'traffic',
        }
        legacy_type = legacy_mapping.get(dept_type)
        if legacy_type and legacy_type not in department_types:
            department_types.append(legacy_type)

        base_departments = Department.objects.filter(
            is_active=True,
            department_type__in=department_types
        ).select_related('city_admin')

        if not base_departments.exists():
            return None

        city_name = (self.city or '').strip()
        state_name = (self.state or '').strip()

        # 1) City + State exact scope
        city_state_scope = base_departments
        if city_name:
            city_state_scope = city_state_scope.filter(
                models.Q(city__iexact=city_name) | models.Q(city_admin__city_name__iexact=city_name)
            )
        if state_name:
            city_state_scope = city_state_scope.filter(
                models.Q(state__iexact=state_name) | models.Q(city_admin__state__iexact=state_name)
            )
        nearest = self._pick_nearest_department(city_state_scope)
        if nearest:
            return nearest

        # 2) State scope
        if state_name:
            state_scope = base_departments.filter(
                models.Q(state__iexact=state_name) | models.Q(city_admin__state__iexact=state_name)
            )
            nearest = self._pick_nearest_department(state_scope)
            if nearest:
                return nearest

        # 3) Global nearest fallback
        return self._pick_nearest_department(base_departments)

    @property
    def reopen_deadline(self):
        if not self.resolved_at:
            return None
        return self.resolved_at + timedelta(days=self.REOPEN_WINDOW_DAYS)

    @property
    def can_reopen(self):
        if self.work_status != 'solved' or not self.resolved_at:
            return False
        return timezone.now() <= self.reopen_deadline
    
    @property
    def estimated_completion_time(self):
        """Calculate estimated completion time based on department SLA"""
        if not self.assigned_department or not self.assigned_department.sla_hours:
            return None
        if self.work_status == 'solved':
            return None
        
        sla_hours = self.assigned_department.sla_hours
        estimated_completion = self.created_at + timedelta(hours=sla_hours)
        return estimated_completion
    
    @property
    def time_remaining(self):
        """Calculate time remaining until SLA deadline"""
        if not self.estimated_completion_time or self.work_status == 'solved':
            return None
        
        now = timezone.now()
        if now >= self.estimated_completion_time:
            return "Overdue"
        
        time_diff = self.estimated_completion_time - now
        days = time_diff.days
        hours = time_diff.seconds // 3600
        
        if days > 0:
            return f"{days} day{'s' if days != 1 else ''}, {hours} hour{'s' if hours != 1 else ''}"
        elif hours > 0:
            return f"{hours} hour{'s' if hours != 1 else ''}"
        else:
            minutes = (time_diff.seconds % 3600) // 60
            return f"{minutes} minute{'s' if minutes != 1 else ''}"
    
    @property
    def is_overdue(self):
        """Check if complaint is overdue based on SLA"""
        if not self.estimated_completion_time or self.work_status == 'solved':
            return False
        return timezone.now() > self.estimated_completion_time
    
    class Meta:
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['work_status']),
            models.Index(fields=['complaint_type']),
            models.Index(fields=['assigned_department', '-created_at']),
            models.Index(fields=['city', 'state']),
            models.Index(fields=['complaint_number']),
        ]

class ComplaintMedia(models.Model):
    complaint = models.ForeignKey(Complaint, related_name='media', on_delete=models.CASCADE)
    file = models.FileField(upload_to='complaint_media/')
    file_type = models.CharField(max_length=10) # 'image' or 'video'

    def __str__(self):
        return f"Media for {self.complaint.id}"


class ComplaintResolutionProof(models.Model):
    complaint = models.ForeignKey(Complaint, related_name='resolution_proofs', on_delete=models.CASCADE)
    file = models.FileField(upload_to='resolution_proofs/')
    file_type = models.CharField(max_length=10)  # 'image' or 'video'
    uploaded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-uploaded_at']

    def __str__(self):
        return f"Resolution proof for {self.complaint.complaint_number}"


class ComplaintReopenProof(models.Model):
    complaint = models.ForeignKey(Complaint, related_name='reopen_proofs', on_delete=models.CASCADE)
    reason = models.TextField()
    proof = models.ImageField(upload_to='reopen_proofs/')
    requested_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Reopen proof for {self.complaint.complaint_number}"

class CitizenProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    surname = models.CharField(max_length=100)
    state = models.CharField(max_length=100, default='Not Specified')
    district = models.CharField(max_length=100, default='Not Specified')
    taluka = models.CharField(max_length=100, default='Not Specified')
    city = models.CharField(max_length=100)
    address = models.TextField()
    mobile_no = models.CharField(max_length=15)
    aadhaar_number = models.CharField(max_length=12, blank=True, null=True)
    latitude = models.FloatField(default=0)
    longitude = models.FloatField(default=0)

    def __str__(self):
        return f"{self.user.first_name} {self.surname}"

class CityAdmin(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    city_name = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10, blank=True, default='')
    contact_address = models.TextField(blank=True, default='')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.user.get_full_name()} - {self.city_name}"


class ManagedState(models.Model):
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.code})"


class ManagedCity(models.Model):
    state = models.ForeignKey(ManagedState, on_delete=models.CASCADE, related_name='cities')
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [('state', 'name')]
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.state.name} ({self.code})"


class ComplaintCategory(models.Model):
    key = models.SlugField(max_length=20, unique=True)
    name = models.CharField(max_length=120)
    emoji = models.CharField(max_length=16, blank=True, help_text='Optional emoji shown on citizen cards')
    logo = models.FileField(upload_to='category_logos/', null=True, blank=True)
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'name']

    def __str__(self):
        return self.name


class ComplaintSubcategory(models.Model):
    category = models.ForeignKey(ComplaintCategory, on_delete=models.CASCADE, related_name='subcategories')
    name = models.CharField(max_length=150)
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'name']
        unique_together = [('category', 'name')]

    def __str__(self):
        return f"{self.category.name} - {self.name}"


class ComplaintCategoryField(models.Model):
    FIELD_TYPES = [
        ('text', 'Text'),
        ('number', 'Number'),
        ('textarea', 'Long Text'),
        ('date', 'Date'),
        ('datetime-local', 'Date & Time'),
        ('select', 'Dropdown'),
        ('email', 'Email'),
        ('tel', 'Phone Number'),
    ]

    category = models.ForeignKey(ComplaintCategory, on_delete=models.CASCADE, related_name='dynamic_fields')
    subcategory = models.ForeignKey(
        ComplaintSubcategory,
        on_delete=models.CASCADE,
        related_name='dynamic_fields',
        null=True,
        blank=True,
    )
    label = models.CharField(max_length=150)
    field_type = models.CharField(max_length=20, choices=FIELD_TYPES, default='text')
    options = models.TextField(blank=True, help_text='Comma separated options for dropdown fields')
    is_required = models.BooleanField(default=False)
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['display_order', 'id']

    def __str__(self):
        if self.subcategory:
            return f"{self.category.name} / {self.subcategory.name} - {self.label}"
        return f"{self.category.name} - {self.label}"


class Department(models.Model):
    DEPARTMENT_TYPES = [
        ('police', '🚔 Police Department'),
        ('traffic', '🚦 Traffic Department'),
        ('construction', '🏗️ Construction Department'),
        ('water', '🚰 Water Supply Department'),
        ('electricity', '💡 Electricity Department'),
        ('garbage', '🗑️ Garbage Department'),
        ('road', '🚧 Road/Pothole Department'),
        ('drainage', '💧 Drainage Department'),
        ('illegal', '🏪 Illegal Activity Department'),
        ('transportation', '🚌 Transportation Department'),
        ('cyber', '🛡️ Cyber Fraud Department'),
        ('other', '📋 Other Department'),
    ]
    
    name = models.CharField(max_length=200, default='Default Department')
    department_type = models.CharField(max_length=20, choices=DEPARTMENT_TYPES)
    unique_id = models.CharField(max_length=50, unique=True, null=True, blank=True)
    state = models.CharField(max_length=100, blank=True)
    city = models.CharField(max_length=100, blank=True)
    location_name = models.CharField(max_length=200, default='City Center')
    latitude = models.FloatField(default=20.5937)
    longitude = models.FloatField(default=78.9629)
    email = models.EmailField(default='dept@smartcity.com')
    phone = models.CharField(max_length=15, default='1234567890')
    address = models.TextField(default='Smart City Office, India')
    sla_hours = models.PositiveIntegerField(default=72)
    department_logo = models.FileField(upload_to='department_logos/', null=True, blank=True)
    city_admin = models.ForeignKey(CityAdmin, on_delete=models.CASCADE, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True, null=True)
    
    def __str__(self):
        return f"{self.name} - {self.get_department_type_display()}"
    
    @property
    def formatted_address(self):
        """Return formatted address for display"""
        parts = []
        if self.location_name and self.location_name != 'City Center':
            parts.append(self.location_name)
        if self.city:
            parts.append(self.city)
        if self.state:
            parts.append(self.state)
        return ', '.join(parts) if parts else self.address

class DepartmentUser(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    department = models.ForeignKey(Department, on_delete=models.CASCADE)
    role = models.CharField(max_length=50, default='Officer')
    
    def __str__(self):
        return f"{self.user.username} - {self.department.name}"


class ComplaintFieldResponse(models.Model):
    complaint = models.ForeignKey(Complaint, on_delete=models.CASCADE, related_name='field_responses')
    field = models.ForeignKey(ComplaintCategoryField, on_delete=models.CASCADE)
    value = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [('complaint', 'field')]

    def __str__(self):
        return f"{self.complaint.complaint_number} - {self.field.label}"
