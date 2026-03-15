from rest_framework import serializers
from django.contrib.auth.models import User
from .models import (
    Complaint, ComplaintMedia, ComplaintResolutionProof, ComplaintReopenProof,
    CitizenProfile, Department, DepartmentUser, ComplaintCategory,
    ComplaintSubcategory, ComplaintCategoryField, ComplaintFieldResponse, OTP
)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        read_only_fields = ['id']


class CitizenProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = CitizenProfile
        fields = ['id', 'user', 'surname', 'state', 'district', 'taluka', 
                  'city', 'address', 'mobile_no', 'aadhaar_number', 
                  'latitude', 'longitude']


class ComplaintMediaSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ComplaintMedia
        fields = ['id', 'file', 'file_url', 'file_type']
    
    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and hasattr(obj.file, 'url'):
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None


class ComplaintResolutionProofSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    uploaded_by_name = serializers.SerializerMethodField()
    
    class Meta:
        model = ComplaintResolutionProof
        fields = ['id', 'file', 'file_url', 'file_type', 'uploaded_by', 
                  'uploaded_by_name', 'uploaded_at']
    
    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and hasattr(obj.file, 'url'):
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
    
    def get_uploaded_by_name(self, obj):
        if obj.uploaded_by:
            return obj.uploaded_by.get_full_name() or obj.uploaded_by.username
        return None


class ComplaintReopenProofSerializer(serializers.ModelSerializer):
    proof_url = serializers.SerializerMethodField()
    requested_by_name = serializers.SerializerMethodField()
    
    class Meta:
        model = ComplaintReopenProof
        fields = ['id', 'reason', 'proof', 'proof_url', 'requested_by', 
                  'requested_by_name', 'created_at']
    
    def get_proof_url(self, obj):
        request = self.context.get('request')
        if obj.proof and hasattr(obj.proof, 'url'):
            if request:
                return request.build_absolute_uri(obj.proof.url)
            return obj.proof.url
        return None
    
    def get_requested_by_name(self, obj):
        if obj.requested_by:
            return obj.requested_by.get_full_name() or obj.requested_by.username
        return None


class DepartmentSerializer(serializers.ModelSerializer):
    department_type_display = serializers.CharField(source='get_department_type_display', read_only=True)
    logo_url = serializers.SerializerMethodField()
    assigned_admin = serializers.SerializerMethodField()
    
    class Meta:
        model = Department
        fields = ['id', 'name', 'department_type', 'department_type_display',
                  'state', 'city', 'location_name', 'latitude', 'longitude',
                  'email', 'phone', 'address', 'formatted_address', 'sla_hours',
                  'department_logo', 'logo_url', 'is_active', 'assigned_admin']
    
    def get_logo_url(self, obj):
        request = self.context.get('request')
        if obj.department_logo and hasattr(obj.department_logo, 'url'):
            if request:
                return request.build_absolute_uri(obj.department_logo.url)
            return obj.department_logo.url
        return None

    def get_assigned_admin(self, obj):
        dept_user = obj.departmentuser_set.select_related('user').first()
        if dept_user and dept_user.user:
            return dept_user.user.get_full_name() or dept_user.user.username
        return None


class ComplaintFieldResponseSerializer(serializers.ModelSerializer):
    field_label = serializers.CharField(source='field.label', read_only=True)
    field_type = serializers.CharField(source='field.field_type', read_only=True)
    
    class Meta:
        model = ComplaintFieldResponse
        fields = ['id', 'field', 'field_label', 'field_type', 'value']


class ComplaintListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for complaint lists"""
    complaint_type_display = serializers.CharField(source='get_complaint_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    work_status_display = serializers.CharField(source='get_work_status_display', read_only=True)
    priority_display = serializers.CharField(source='get_priority_display', read_only=True)
    user_name = serializers.SerializerMethodField()
    media_count = serializers.SerializerMethodField()
    thumbnail = serializers.SerializerMethodField()
    
    class Meta:
        model = Complaint
        fields = ['id', 'complaint_number', 'title', 'complaint_type', 
                  'complaint_type_display', 'subcategory', 'status', 'status_display',
                  'work_status', 'work_status_display', 'priority', 'priority_display',
                  'city', 'state', 'created_at', 'updated_at', 'user_name',
                  'media_count', 'thumbnail', 'citizen_rating']
    
    def get_user_name(self, obj):
        if obj.user:
            return obj.user.get_full_name() or obj.user.username
        return obj.guest_name or 'Anonymous'
    
    def get_media_count(self, obj):
        return obj.media.count()
    
    def get_thumbnail(self, obj):
        request = self.context.get('request')
        first_media = obj.media.filter(file_type='image').first()
        if first_media and first_media.file and hasattr(first_media.file, 'url'):
            if request:
                return request.build_absolute_uri(first_media.file.url)
            return first_media.file.url
        return None


class ComplaintDetailSerializer(serializers.ModelSerializer):
    """Detailed serializer for single complaint view"""
    complaint_type_display = serializers.CharField(source='get_complaint_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    work_status_display = serializers.CharField(source='get_work_status_display', read_only=True)
    priority_display = serializers.CharField(source='get_priority_display', read_only=True)
    user_name = serializers.SerializerMethodField()
    media = ComplaintMediaSerializer(many=True, read_only=True)
    resolution_proofs = ComplaintResolutionProofSerializer(many=True, read_only=True)
    reopen_proofs = ComplaintReopenProofSerializer(many=True, read_only=True)
    assigned_department = DepartmentSerializer(read_only=True)
    field_responses = ComplaintFieldResponseSerializer(many=True, read_only=True)
    can_reopen = serializers.BooleanField(read_only=True)
    reopen_deadline = serializers.DateTimeField(read_only=True)
    estimated_completion_time = serializers.DateTimeField(read_only=True)
    time_remaining = serializers.CharField(read_only=True)
    is_overdue = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Complaint
        fields = '__all__'
    
    def get_user_name(self, obj):
        if obj.user:
            return obj.user.get_full_name() or obj.user.username
        return obj.guest_name or 'Anonymous'


class ComplaintCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating complaints"""
    media_files = serializers.ListField(
        child=serializers.FileField(),
        write_only=True,
        required=False
    )
    
    class Meta:
        model = Complaint
        fields = ['complaint_type', 'subcategory', 'priority', 'title', 'description',
                  'latitude', 'longitude', 'city', 'state', 'pincode', 'address',
                  'preferred_contact_phone', 'preferred_contact_email', 
                  'preferred_contact_sms', 'media_files']
    
    def create(self, validated_data):
        media_files = validated_data.pop('media_files', [])
        request = self.context.get('request')
        user = request.user if request and request.user.is_authenticated else None
        
        complaint = Complaint.objects.create(user=user, **validated_data)
        
        # Handle media files
        for file in media_files:
            file_type = 'image' if file.content_type.startswith('image') else 'video'
            ComplaintMedia.objects.create(
                complaint=complaint,
                file=file,
                file_type=file_type
            )
        
        # Handle dynamic fields from request.data
        if request:
            for key, value in request.data.items():
                if key.startswith('field_'):
                    try:
                        field_id = int(key.replace('field_', ''))
                        field_obj = ComplaintCategoryField.objects.filter(id=field_id, is_active=True).first()
                        if field_obj:
                            ComplaintFieldResponse.objects.update_or_create(
                                complaint=complaint,
                                field=field_obj,
                                defaults={'value': str(value).strip()},
                            )
                    except (ValueError, TypeError):
                        continue
        
        return complaint


class ComplaintCategoryFieldSerializer(serializers.ModelSerializer):
    options = serializers.SerializerMethodField()
    options_list = serializers.SerializerMethodField()
    
    class Meta:
        model = ComplaintCategoryField
        fields = ['id', 'label', 'field_type', 'options', 'options_list', 
                  'is_required', 'display_order']
    
    def get_options(self, obj):
        if obj.options:
            return [opt.strip() for opt in obj.options.split(',')]
        return []

    def get_options_list(self, obj):
        return self.get_options(obj)


class ComplaintSubcategorySerializer(serializers.ModelSerializer):
    dynamic_fields = ComplaintCategoryFieldSerializer(many=True, read_only=True)
    
    class Meta:
        model = ComplaintSubcategory
        fields = ['id', 'name', 'is_active', 'display_order', 'dynamic_fields']


class ComplaintCategorySerializer(serializers.ModelSerializer):
    subcategories = ComplaintSubcategorySerializer(many=True, read_only=True)
    logo_url = serializers.SerializerMethodField()
    
    class Meta:
        model = ComplaintCategory
        fields = ['id', 'key', 'name', 'emoji', 'logo', 'logo_url', 
                  'is_active', 'display_order', 'subcategories']
    
    def get_logo_url(self, obj):
        request = self.context.get('request')
        if obj.logo and hasattr(obj.logo, 'url'):
            if request:
                return request.build_absolute_uri(obj.logo.url)
            return obj.logo.url
        return None


class OTPSerializer(serializers.ModelSerializer):
    class Meta:
        model = OTP
        fields = ['email', 'otp', 'created_at', 'is_verified']
        read_only_fields = ['created_at', 'is_verified']


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    password2 = serializers.CharField(write_only=True, required=True)
    mobile_no = serializers.CharField(write_only=True, required=False)
    
    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password2', 'first_name', 
                  'last_name', 'mobile_no']
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password2']:
            raise serializers.ValidationError({"password": "Passwords don't match"})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password2')
        mobile_no = validated_data.pop('mobile_no', '')
        
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', '')
        )
        
        # Create citizen profile
        CitizenProfile.objects.create(
            user=user,
            mobile_no=mobile_no,
            surname=validated_data.get('last_name', ''),
            city='',
            address=''
        )
        
        return user


class DashboardStatsSerializer(serializers.Serializer):
    total_complaints = serializers.IntegerField()
    pending_complaints = serializers.IntegerField()
    resolved_complaints = serializers.IntegerField()
    reopened_complaints = serializers.IntegerField()
    in_progress_complaints = serializers.IntegerField()
