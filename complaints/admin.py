from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.models import User
from .models import (
    OTP, Complaint, Department, DepartmentUser, CityAdmin, CitizenProfile,
    ComplaintMedia, ComplaintResolutionProof, ManagedState, ManagedCity,
    ComplaintCategory, ComplaintSubcategory, ComplaintCategoryField, ComplaintFieldResponse,
    ComplaintReopenProof
)
from .forms import CustomUserCreationForm, CustomUserChangeForm

# Unregister the default User admin
admin.site.unregister(User)

# Register custom User admin with email field
@admin.register(User)
class CustomUserAdmin(UserAdmin):
    # Use custom forms
    add_form = CustomUserCreationForm
    form = CustomUserChangeForm
    
    # Add email to the add form
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'password1', 'password2'),
        }),
    )
    
    # Show email in the list view
    list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'is_active', 'date_joined')
    
    # Make email searchable
    search_fields = ('username', 'email', 'first_name', 'last_name')
    
    # Add email to the change form
    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('Personal info', {'fields': ('first_name', 'last_name', 'email')}),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
        }),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    
    # Make email required in admin
    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        if 'email' in form.base_fields:
            form.base_fields['email'].required = True
        return form

@admin.register(CityAdmin)
class CityAdminAdmin(admin.ModelAdmin):
    list_display = ['user', 'city_name', 'state', 'pincode', 'is_active']
    list_filter = ['state', 'is_active']
    search_fields = ['city_name', 'state', 'pincode', 'user__username', 'user__email']

@admin.register(ManagedState)
class ManagedStateAdmin(admin.ModelAdmin):
    list_display = ['name', 'code', 'created_at']
    search_fields = ['name', 'code']

@admin.register(ManagedCity)
class ManagedCityAdmin(admin.ModelAdmin):
    list_display = ['name', 'code', 'state', 'created_at']
    list_filter = ['state']
    search_fields = ['name', 'code', 'state__name']

@admin.register(OTP)
class OTPAdmin(admin.ModelAdmin):
    list_display = ['email', 'otp', 'created_at', 'is_verified']
    list_filter = ['is_verified', 'created_at']

class ComplaintMediaAdmin(admin.StackedInline):
    model = ComplaintMedia
    extra = 0

class ComplaintResolutionProofAdmin(admin.StackedInline):
    model = ComplaintResolutionProof
    extra = 0

class ComplaintFieldResponseAdmin(admin.StackedInline):
    model = ComplaintFieldResponse
    extra = 0

@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = ['complaint_number', 'complaint_type', 'title', 'user', 'work_status', 'assigned_department', 'reopen_count', 'created_at']
    list_filter = ['complaint_type', 'work_status', 'assigned_department', 'created_at']
    search_fields = ['complaint_number', 'title', 'description', 'user__email', 'guest_email']
    inlines = [ComplaintMediaAdmin, ComplaintResolutionProofAdmin, ComplaintFieldResponseAdmin]

@admin.register(Department)
class DepartmentAdmin(admin.ModelAdmin):
    list_display = ['name', 'department_type', 'unique_id', 'state', 'city', 'city_admin', 'sla_hours', 'location_name', 'email', 'is_active']
    list_filter = ['department_type', 'state', 'city_admin', 'is_active']
    search_fields = ['name', 'unique_id', 'email', 'state', 'city']
    
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "city_admin":
            if not request.user.is_superuser:
                try:
                    city_admin = CityAdmin.objects.get(user=request.user)
                    kwargs["queryset"] = CityAdmin.objects.filter(id=city_admin.id)
                except CityAdmin.DoesNotExist:
                    kwargs["queryset"] = CityAdmin.objects.none()
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

@admin.register(DepartmentUser)
class DepartmentUserAdmin(admin.ModelAdmin):
    list_display = ['user', 'department', 'role']
    list_filter = ['department__department_type', 'role']
    search_fields = ['user__username', 'user__email', 'department__name']

@admin.register(CitizenProfile)
class CitizenProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'surname', 'city', 'mobile_no']
    search_fields = ['user__email', 'surname', 'mobile_no']

class ComplaintSubcategoryInline(admin.TabularInline):
    model = ComplaintSubcategory
    extra = 0

class ComplaintCategoryFieldInline(admin.TabularInline):
    model = ComplaintCategoryField
    extra = 0

@admin.register(ComplaintCategory)
class ComplaintCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'key', 'emoji', 'is_active', 'display_order', 'created_at']
    list_filter = ['is_active']
    search_fields = ['name', 'key']
    inlines = [ComplaintSubcategoryInline, ComplaintCategoryFieldInline]

@admin.register(ComplaintSubcategory)
class ComplaintSubcategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'category', 'is_active', 'display_order']
    list_filter = ['category', 'is_active']
    search_fields = ['name', 'category__name']

@admin.register(ComplaintCategoryField)
class ComplaintCategoryFieldAdmin(admin.ModelAdmin):
    list_display = ['label', 'category', 'subcategory', 'field_type', 'is_required', 'is_active', 'display_order']
    list_filter = ['category', 'subcategory', 'field_type', 'is_required', 'is_active']
    search_fields = ['label', 'category__name', 'subcategory__name']


@admin.register(ComplaintReopenProof)
class ComplaintReopenProofAdmin(admin.ModelAdmin):
    list_display = ['complaint', 'requested_by', 'created_at']
    search_fields = ['complaint__complaint_number', 'requested_by__username', 'requested_by__email']
