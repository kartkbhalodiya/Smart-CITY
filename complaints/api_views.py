from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.models import User
from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import IntegrityError, transaction
from django.db.models import Q, Count
from django.utils import timezone
from datetime import timedelta
import os
import random
import string
import secrets
import requests

from .models import (
    Complaint, ComplaintMedia, ComplaintResolutionProof, ComplaintReopenProof,
    CitizenProfile, Department, DepartmentUser, ComplaintCategory, ComplaintSubcategory,
    ComplaintCategoryField, ComplaintFieldResponse, OTP, CityAdmin, ManagedState,
    ManagedCity
)
from .serializers import (
    ComplaintListSerializer, ComplaintDetailSerializer, ComplaintCreateSerializer,
    CitizenProfileSerializer, DepartmentSerializer, ComplaintCategorySerializer,
    ComplaintSubcategorySerializer, ComplaintCategoryFieldSerializer, UserSerializer, RegisterSerializer,
    OTPSerializer, DashboardStatsSerializer, ComplaintResolutionProofSerializer,
    ComplaintReopenProofSerializer
)
from .email_utils import (
    send_welcome_email, send_otp_email, send_password_reset_credentials_email
)
from .conversational_ai import SmartCityAI
from .cityfix_client import cityfix_llm


@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """Database-free deployment probe for Vercel and uptime checks."""
    return Response({
        'success': True,
        'status': 'ok',
        'service': 'smartcity',
        'runtime': 'vercel' if os.getenv('VERCEL') else 'local',
    })


ACTIVE_WORK_STATUSES = ['pending', 'confirmed', 'process', 'reopened']

DEPARTMENT_TYPE_LABELS = {
    'police': 'Police Department',
    'traffic': 'Traffic Department',
    'construction': 'Construction Department',
    'water': 'Water Supply Department',
    'electricity': 'Electricity Department',
    'garbage': 'Garbage Department',
    'road': 'Road/Pothole Department',
    'drainage': 'Drainage Department',
    'illegal': 'Illegal Activity Department',
    'transportation': 'Transportation Department',
    'cyber': 'Cyber Fraud Department',
    'other': 'Other Department',
}


def _get_user_role(user):
    if user.is_superuser:
        return 'superadmin'
    if CityAdmin.objects.filter(user=user).exists():
        return 'city_admin'
    if DepartmentUser.objects.filter(user=user).exists():
        return 'department'
    return 'citizen'


def _city_admin_complaints(city_admin):
    return Complaint.objects.filter(
        Q(city__iexact=city_admin.city_name, state__iexact=city_admin.state) |
        Q(assigned_department__city_admin=city_admin)
    ).distinct()


def _city_admin_departments(city_admin):
    return Department.objects.filter(
        Q(city_admin=city_admin) |
        Q(city__iexact=city_admin.city_name, state__iexact=city_admin.state)
    ).distinct()


def _department_type_label(department_type):
    return DEPARTMENT_TYPE_LABELS.get(department_type, department_type or 'Department')


def _admin_stat(label, value, icon, color):
    return {
        'label': label,
        'value': int(value or 0),
        'icon': icon,
        'color': color,
    }


def _admin_section(title, subtitle, count, icon, route_key, color):
    return {
        'title': title,
        'subtitle': subtitle,
        'count': int(count or 0),
        'icon': icon,
        'route': route_key,
        'color': color,
    }


def _serialize_departments(request, departments, limit=20):
    department_rows = list(departments.order_by('name')[:limit])
    data = DepartmentSerializer(
        department_rows,
        many=True,
        context={'request': request},
    ).data
    cleaned = []
    for item, department in zip(data, department_rows):
        row = dict(item)
        row['unique_id'] = department.unique_id
        row['department_type_display'] = _department_type_label(row.get('department_type'))
        row['city_admin_id'] = department.city_admin_id
        cleaned.append(row)
    return cleaned


def _admin_overview_payload(
    request,
    *,
    role,
    title,
    scope,
    complaints,
    departments,
    citizen_count,
    sections,
    city_admins=None,
):
    complaints = complaints.select_related('assigned_department', 'user')
    departments = departments.select_related('city_admin', 'city_admin__user')

    total_complaints = complaints.count()
    pending_complaints = complaints.filter(work_status='pending').count()
    in_progress_complaints = complaints.filter(work_status__in=['confirmed', 'process']).count()
    resolved_complaints = complaints.filter(work_status='solved').count()
    reopened_complaints = complaints.filter(work_status='reopened').count()
    today_complaints = complaints.filter(created_at__date=timezone.localdate()).count()

    recent_complaints = ComplaintListSerializer(
        complaints.order_by('-created_at')[:12],
        many=True,
        context={'request': request},
    ).data

    payload = {
        'success': True,
        'role': role,
        'title': title,
        'scope': scope,
        'stats': [
            _admin_stat('Total', total_complaints, 'assignment', 'blue'),
            _admin_stat('Pending', pending_complaints, 'pending', 'orange'),
            _admin_stat('In progress', in_progress_complaints, 'sync', 'purple'),
            _admin_stat('Solved', resolved_complaints, 'check', 'green'),
            _admin_stat('Reopened', reopened_complaints, 'restart', 'red'),
            _admin_stat('Today', today_complaints, 'today', 'teal'),
        ],
        'sections': sections,
        'complaints': recent_complaints,
        'departments': _serialize_departments(request, departments),
        'summary': {
            'total_complaints': total_complaints,
            'pending_complaints': pending_complaints,
            'in_progress_complaints': in_progress_complaints,
            'resolved_complaints': resolved_complaints,
            'reopened_complaints': reopened_complaints,
            'department_count': departments.count(),
            'citizen_count': int(citizen_count or 0),
        },
    }

    if city_admins is not None:
        payload['city_admins'] = [
            {
                'id': admin.id,
                'name': admin.user.get_full_name() or admin.user.username,
                'email': admin.user.email,
                'city': admin.city_name,
                'state': admin.state,
                'is_active': admin.is_active,
            }
            for admin in city_admins.select_related('user').order_by('city_name', 'user__first_name')[:20]
        ]

    return payload


def _admin_forbidden(message='This account is not allowed to open this admin dashboard.'):
    return Response(
        {'success': False, 'message': message},
        status=status.HTTP_403_FORBIDDEN,
    )


def _role_scoped_complaints(user):
    role = _get_user_role(user)
    if role == 'superadmin':
        return Complaint.objects.all()
    if role == 'city_admin':
        city_admin = CityAdmin.objects.filter(user=user, is_active=True).first()
        return _city_admin_complaints(city_admin) if city_admin else Complaint.objects.none()
    if role == 'department':
        dept_user = DepartmentUser.objects.select_related('department').filter(user=user).first()
        return Complaint.objects.filter(assigned_department=dept_user.department) if dept_user else Complaint.objects.none()
    return Complaint.objects.filter(user=user)


def _role_scoped_departments(user):
    role = _get_user_role(user)
    if role == 'superadmin':
        return Department.objects.all()
    if role == 'city_admin':
        city_admin = CityAdmin.objects.filter(user=user, is_active=True).first()
        return _city_admin_departments(city_admin) if city_admin else Department.objects.none()
    if role == 'department':
        dept_user = DepartmentUser.objects.select_related('department').filter(user=user).first()
        return Department.objects.filter(id=dept_user.department_id) if dept_user else Department.objects.none()
    return Department.objects.none()


def _role_scoped_citizens(user):
    role = _get_user_role(user)
    if role == 'superadmin':
        return CitizenProfile.objects.select_related('user').all()
    if role == 'city_admin':
        city_admin = CityAdmin.objects.filter(user=user, is_active=True).first()
        if not city_admin:
            return CitizenProfile.objects.none()
        return CitizenProfile.objects.select_related('user').filter(
            Q(city__iexact=city_admin.city_name) | Q(district__iexact=city_admin.city_name),
            state__iexact=city_admin.state,
        )
    if role == 'department':
        complaints = _role_scoped_complaints(user)
        user_ids = complaints.exclude(user__isnull=True).values_list('user_id', flat=True).distinct()
        return CitizenProfile.objects.select_related('user').filter(user_id__in=user_ids)
    return CitizenProfile.objects.none()


def _clean_department_type_display(value):
    return _department_type_label(value)


def _generate_mobile_department_code():
    for _ in range(24):
        code = ''.join(secrets.choice(string.digits) for _ in range(6))
        if not Department.objects.filter(unique_id=code).exists():
            return code
    return ''.join(secrets.choice(string.digits) for _ in range(8))


def _generate_mobile_password(length=12):
    length = max(10, int(length))
    chars = string.ascii_letters + string.digits + '!@#$'
    return ''.join(secrets.choice(chars) for _ in range(length))


def _as_bool(value, default=True):
    if value is None:
        return default
    return str(value).strip().lower() in {'1', 'true', 'yes', 'on', 'active'}


def _serialize_admin_citizen(profile):
    user = profile.user
    return {
        'id': profile.id,
        'user_id': user.id,
        'name': user.get_full_name() or user.username,
        'email': user.email,
        'mobile_no': profile.mobile_no or '',
        'state': profile.state or '',
        'city': profile.city or profile.district or '',
        'district': profile.district or '',
        'pincode': profile.pincode or '',
        'address': profile.address or '',
        'latitude': _safe_float(profile.latitude),
        'longitude': _safe_float(profile.longitude),
    }


def _serialize_city_admin(admin):
    return {
        'id': admin.id,
        'user_id': admin.user_id,
        'name': admin.user.get_full_name() or admin.user.username,
        'email': admin.user.email,
        'city': admin.city_name,
        'state': admin.state,
        'pincode': admin.pincode,
        'contact_address': admin.contact_address,
        'is_active': admin.is_active,
    }


def _serialize_category(category):
    return {
        'id': category.id,
        'key': category.key,
        'name': category.name,
        'is_active': category.is_active,
        'display_order': category.display_order,
        'subcategory_count': category.subcategories.count(),
    }


def _serialize_state(state_obj):
    return {
        'id': state_obj.id,
        'code': state_obj.code,
        'name': state_obj.name,
        'city_count': state_obj.cities.count(),
    }


def _serialize_city(city_obj):
    return {
        'id': city_obj.id,
        'code': city_obj.code,
        'name': city_obj.name,
        'state': city_obj.state.name,
        'state_id': city_obj.state_id,
    }


def _validate_email_value(email):
    try:
        validate_email(email)
        return None
    except ValidationError:
        return 'Enter a valid email address.'


# Authentication Views
@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """Register new user — accepts name, email, mobile_no, pincode, state, district, address, aadhaar, latitude, longitude"""
    try:
        data = request.data

        name = (data.get('name') or '').strip()
        email = (data.get('email') or '').strip().lower()
        mobile_no = (data.get('mobile_no') or '').strip()
        pincode = (data.get('pincode') or '').strip()
        state = (data.get('state') or '').strip()
        district = (data.get('district') or '').strip()
        address = (data.get('address') or '').strip()
        aadhaar = (data.get('aadhaar') or '').strip()
        latitude = data.get('latitude') or ''
        longitude = data.get('longitude') or ''

        if not email:
            return Response({
                'success': False, 
                'message': 'Email is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Check if user already exists and is FULLY registered
        existing_user = User.objects.filter(email__iexact=email).first()
        if existing_user and hasattr(existing_user, 'citizenprofile'):
            # If they have a real mobile_no (not default), then they're truly registered
            profile = existing_user.citizenprofile
            if profile.mobile_no and profile.mobile_no != 'Not Provided' and profile.mobile_no != '':
                return Response({
                    'success': False, 
                    'message': 'This email is already fully registered and verified'
                }, status=status.HTTP_400_BAD_REQUEST)

        # Handle name splitting safely even if empty
        name_to_split = name if name.strip() else 'Citizen'
        parts = name_to_split.split(' ', 1)
        first_name = parts[0]
        last_name = parts[1] if len(parts) > 1 else ''

        user = None
        is_new_user = False
        try:
            # Try to get existing user (created by verify_otp) or create new one
            user = User.objects.filter(email__iexact=email).first()
            if user:
                # Update their name only if provided
                if not user.first_name and first_name: user.first_name = first_name
                if not user.last_name and last_name: user.last_name = last_name
                user.save()
            else:
                is_new_user = True
                # Check if username exists independently of email to prevent IntegrityError
                if User.objects.filter(username=email).exists():
                    return Response({
                        'success': False,
                        'message': 'A user with this identifier already exists. Please login.'
                    }, status=status.HTTP_400_BAD_REQUEST)
                    
                user = User.objects.create_user(
                    username=email,
                    email=email,
                    first_name=first_name or 'Citizen',
                    last_name=last_name or '',
                )

            # Update or create citizen profile - all fields optional
            profile_kwargs = dict(
                surname=last_name or 'Citizen',
                mobile_no=mobile_no or 'Not Provided',
                state=state or 'Not Specified',
                district=district or 'Not Specified',
                city=district or 'Not Specified',
                address=address or 'Not Provided',
                pincode=pincode or '',
            )
            if aadhaar:
                profile_kwargs['aadhaar_number'] = aadhaar
            
            try:
                profile_kwargs['latitude'] = float(latitude) if (latitude and str(latitude).strip()) else 0.0
                profile_kwargs['longitude'] = float(longitude) if (longitude and str(longitude).strip()) else 0.0
            except (ValueError, TypeError):
                profile_kwargs['latitude'] = 0.0
                profile_kwargs['longitude'] = 0.0

            # Use update_or_create to handle existing profiles safely
            CitizenProfile.objects.update_or_create(
                user=user, 
                defaults=profile_kwargs
            )
            
            # Generate JWT Token
            refresh = RefreshToken.for_user(user)

            try:
                send_welcome_email(
                    user_email=email,
                    user_name=name,
                    user_mobile=mobile_no,
                    join_date=user.date_joined.strftime('%Y-%m-%d'),
                    user_role='Citizen'
                )
            except Exception as email_err:
                print(f"Error sending welcome email: {email_err}")

            return Response({
                'success': True,
                'message': 'Registration successful',
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'token': str(refresh.access_token), # Backward compatibility
                'user': UserSerializer(user).data,
                'role': 'citizen',
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            # Cleanup ONLY if we created a brand new user in THIS request
            if is_new_user and user:
                try:
                    user.delete()
                except:
                    pass
            
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'message': f'Registration Error: {str(e)}'
            }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as outer_e:
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Request Processing Error: {str(outer_e)}'
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    """Send OTP to email"""
    try:
        email = (request.data.get('email') or '').strip().lower()
        if not email:
            return Response({
                'success': False,
                'message': 'Email is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Block staff/admin from OTP login
        try:
            u = User.objects.get(email__iexact=email)
            if u.is_superuser or CityAdmin.objects.filter(user=u).exists() or DepartmentUser.objects.filter(user=u).exists():
                return Response({
                    'success': False,
                    'message': 'Staff/Admin accounts must login with password, not OTP.'
                }, status=status.HTTP_403_FORBIDDEN)
        except User.DoesNotExist:
            pass

        # Generate 6-digit OTP (Cryptographically Secure)
        otp_code = ''.join(secrets.choice('0123456789') for _ in range(6))
        
        # Delete old OTPs for this email
        OTP.objects.filter(email=email).delete()
        
        # Create new OTP
        OTP.objects.create(email=email, otp=otp_code)
        
        # Send OTP via email
        try:
            send_otp_email(email, otp_code)
        except Exception as e:
            # Don't fail the whole request if email fails (for testing), or return a specific error
            return Response({
                'success': False,
                'message': f'Failed to send OTP email: {str(e)}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        return Response({
            'success': True,
            'message': 'OTP sent to your email'
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({
            'success': False,
            'message': f'OTP Request Error: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    """Verify OTP and login/register user"""
    try:
        email = (request.data.get('email') or '').strip().lower()
        otp_code = (request.data.get('otp') or '').strip()
        
        if not email or not otp_code:
            return Response({
                'success': False,
                'message': 'Email and OTP are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check OTP
        try:
            otp = OTP.objects.get(email=email, otp=otp_code, is_verified=False)
            
            # Check if OTP is expired (10 minutes)
            if timezone.now() > otp.created_at + timedelta(minutes=10):
                return Response({
                    'success': False,
                    'message': 'OTP expired'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Mark OTP as verified
            otp.is_verified = True
            otp.save()
            
            # Get or create user
            user, created = User.objects.get_or_create(
                email__iexact=email,
                defaults={
                    'username': email,
                    'email': email
                }
            )
            
            # Ensure citizen profile exists
            CitizenProfile.objects.update_or_create(
                user=user,
                defaults={
                    'surname': user.last_name or 'Citizen',
                    'city': 'Not Specified',
                    'district': 'Not Specified',
                    'state': 'Not Specified',
                    'address': 'Not Provided',
                    'mobile_no': 'Not Provided',
                    'pincode': '',
                }
            )
            
            # Generate JWT Token
            refresh = RefreshToken.for_user(user)
            
            role = _get_user_role(user)

            return Response({
                'success': True,
                'message': 'Verification successful',
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'token': str(refresh.access_token), # Backward compatibility
                'user': UserSerializer(user).data,
                'role': role,
                'is_new_user': created
            }, status=status.HTTP_200_OK)
            
        except OTP.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Invalid OTP code'
            }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Verification error: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_with_password(request):
    """Login with email/username + password (for superadmin, city admin, department users)"""
    from .models import CityAdmin
    identifier = request.data.get('identifier', '').strip()
    password = request.data.get('password', '').strip()

    if not identifier or not password:
        return Response({'success': False, 'message': 'Email and password are required'}, status=status.HTTP_400_BAD_REQUEST)

    user = authenticate(request, username=identifier, password=password)
    if not user:
        try:
            user_obj = User.objects.get(email__iexact=identifier)
            user = authenticate(request, username=user_obj.username, password=password)
        except User.DoesNotExist:
            pass

    if not user:
        return Response({'success': False, 'message': 'Invalid email or password'}, status=status.HTTP_401_UNAUTHORIZED)

    role = _get_user_role(user)

    # Generate JWT Token
    refresh = RefreshToken.for_user(user)
    return Response({
        'success': True,
        'message': 'Login successful',
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'token': str(refresh.access_token), # Backward compatibility
        'user': UserSerializer(user).data,
        'role': role,
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_user(request):
    """Logout user - with JWT we don't necessarily delete anything on server unless using blacklist"""
    try:
        # If using blacklist, you could blacklist the refresh token here if passed in request
        return Response({
            'success': True,
            'message': 'Logged out successfully'
        }, status=status.HTTP_200_OK)
    except:
        return Response({
            'success': False,
            'message': 'Logout failed'
        }, status=status.HTTP_400_BAD_REQUEST)


# User Profile Views
@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
def user_profile(request):
    """Get or update user profile"""
    def clean_text(value, fallback=''):
        if value is None:
            return fallback
        text = str(value).strip()
        if text.lower() in {'not provided', 'not specified', 'none', 'null'}:
            return fallback
        return text

    user_role = _get_user_role(request.user)
    if user_role != 'citizen' and request.method == 'GET':
        user_data = dict(UserSerializer(request.user).data)
        user_data['role'] = user_role
        return Response({
            'success': True,
            'profile': user_data,
        })

    try:
        profile = request.user.citizenprofile
    except CitizenProfile.DoesNotExist:
        profile = CitizenProfile.objects.create(
            user=request.user,
            surname='',
            state='',
            district='',
            taluka='',
            city='',
            pincode='',
            address='',
            mobile_no=''
        )
    
    if request.method == 'GET':
        serializer = CitizenProfileSerializer(profile, context={'request': request})
        return Response({
            'success': True,
            'profile': serializer.data
        })
    
    elif request.method == 'PUT':
        # Update user fields
        user = request.user
        old_email = user.email
        if 'first_name' in request.data:
            user.first_name = clean_text(request.data.get('first_name'))
        if 'last_name' in request.data:
            user.last_name = clean_text(request.data.get('last_name'))
        incoming_email = (request.data.get('email') or '').strip().lower()
        if 'email' in request.data and incoming_email:
            if User.objects.filter(email__iexact=incoming_email).exclude(id=user.id).exists():
                return Response({
                    'success': False,
                    'message': 'This email is already linked to another account'
                }, status=status.HTTP_400_BAD_REQUEST)
            user.email = incoming_email
            if not user.username or user.username == old_email:
                user.username = incoming_email
        user.save()
        
        # Update profile fields
        if 'surname' in request.data:
            profile.surname = clean_text(request.data.get('surname'))
        if 'mobile_no' in request.data:
            profile.mobile_no = clean_text(request.data.get('mobile_no'))
        if 'state' in request.data:
            profile.state = clean_text(request.data.get('state'))
        if 'district' in request.data:
            profile.district = clean_text(request.data.get('district'))
        if 'taluka' in request.data:
            profile.taluka = clean_text(request.data.get('taluka'))
        if 'city' in request.data:
            profile.city = clean_text(request.data.get('city'))
        if 'pincode' in request.data:
            profile.pincode = clean_text(request.data.get('pincode'))
        if 'address' in request.data:
            profile.address = clean_text(request.data.get('address'))
        if 'aadhaar_number' in request.data:
            profile.aadhaar_number = clean_text(request.data.get('aadhaar_number'))
        if 'latitude' in request.data:
            try:
                profile.latitude = float(request.data.get('latitude') or 0)
            except (TypeError, ValueError):
                pass
        if 'longitude' in request.data:
            try:
                profile.longitude = float(request.data.get('longitude') or 0)
            except (TypeError, ValueError):
                pass
        profile.save()
        
        serializer = CitizenProfileSerializer(profile, context={'request': request})
        return Response({
            'success': True,
            'message': 'Profile updated successfully',
            'profile': serializer.data
        })


# Dashboard Views
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    """Get dashboard statistics"""
    user_complaints = Complaint.objects.filter(user=request.user)
    
    stats = {
        'total_complaints': user_complaints.count(),
        'pending_complaints': user_complaints.filter(work_status='pending').count(),
        'resolved_complaints': user_complaints.filter(work_status='solved').count(),
        'reopened_complaints': user_complaints.filter(work_status='reopened').count(),
        'in_progress_complaints': user_complaints.filter(work_status__in=['confirmed', 'process']).count(),
    }
    
    serializer = DashboardStatsSerializer(stats)
    return Response({
        'success': True,
        'stats': serializer.data
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def super_admin_app_overview(request):
    """Mobile dashboard payload for the main platform admin."""
    if not request.user.is_superuser:
        return _admin_forbidden('Only the main admin can open this dashboard.')

    complaints = Complaint.objects.all()
    departments = Department.objects.all()
    city_admins = CityAdmin.objects.all()
    citizens = CitizenProfile.objects.count()

    sections = [
        _admin_section(
            'City Admins',
            'Manage city-level accounts',
            city_admins.count(),
            'admin_panel_settings',
            'city_admins',
            'blue',
        ),
        _admin_section(
            'Departments',
            'All department desks',
            departments.count(),
            'account_balance',
            'departments',
            'purple',
        ),
        _admin_section(
            'Citizens',
            'Registered citizen profiles',
            citizens,
            'groups',
            'citizens',
            'green',
        ),
        _admin_section(
            'Open Problems',
            'Complaints needing action',
            complaints.filter(work_status__in=ACTIVE_WORK_STATUSES).count(),
            'warning',
            'problems',
            'orange',
        ),
        _admin_section(
            'Categories',
            'Complaint category setup',
            ComplaintCategory.objects.count(),
            'category',
            'categories',
            'teal',
        ),
        _admin_section(
            'States',
            'Managed state list',
            ManagedState.objects.count(),
            'map',
            'states',
            'blue',
        ),
        _admin_section(
            'Cities',
            'Managed city list',
            ManagedCity.objects.count(),
            'location_city',
            'cities',
            'purple',
        ),
        _admin_section(
            'Analytics',
            'Status and category breakdown',
            complaints.count(),
            'analytics',
            'analytics',
            'green',
        ),
    ]

    return Response(_admin_overview_payload(
        request,
        role='superadmin',
        title='Main Admin',
        scope='All cities and departments',
        complaints=complaints,
        departments=departments,
        citizen_count=citizens,
        sections=sections,
        city_admins=city_admins,
    ))


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def city_admin_app_overview(request):
    """Mobile dashboard payload for a city admin."""
    city_admin = CityAdmin.objects.filter(user=request.user, is_active=True).first()
    if not city_admin:
        return _admin_forbidden('This account is not linked to an active city admin profile.')

    complaints = _city_admin_complaints(city_admin)
    departments = _city_admin_departments(city_admin)
    citizens = CitizenProfile.objects.filter(
        Q(city__iexact=city_admin.city_name) | Q(district__iexact=city_admin.city_name),
        state__iexact=city_admin.state,
    ).count()

    sections = [
        _admin_section(
            'City Complaints',
            'All complaints in this city',
            complaints.count(),
            'assignment',
            'complaints',
            'blue',
        ),
        _admin_section(
            'Departments',
            'Departments under this city',
            departments.count(),
            'account_balance',
            'departments',
            'purple',
        ),
        _admin_section(
            'Citizens',
            'Citizen profiles in scope',
            citizens,
            'groups',
            'citizens',
            'green',
        ),
        _admin_section(
            'Solved',
            'Resolved city complaints',
            complaints.filter(work_status='solved').count(),
            'task_alt',
            'solved',
            'teal',
        ),
        _admin_section(
            'Analytics',
            'City performance breakdown',
            complaints.count(),
            'analytics',
            'analytics',
            'green',
        ),
    ]

    return Response(_admin_overview_payload(
        request,
        role='city_admin',
        title='City Admin',
        scope=f"{city_admin.city_name}, {city_admin.state}",
        complaints=complaints,
        departments=departments,
        citizen_count=citizens,
        sections=sections,
    ))


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def department_admin_app_overview(request):
    """Mobile dashboard payload for a department admin/officer."""
    dept_user = DepartmentUser.objects.select_related('department').filter(user=request.user).first()
    if not dept_user or not dept_user.department:
        return _admin_forbidden('This account is not linked to a department.')

    department = dept_user.department
    complaints = Complaint.objects.filter(assigned_department=department)
    departments = Department.objects.filter(id=department.id)
    citizens = complaints.exclude(user__isnull=True).values('user_id').distinct().count()

    sections = [
        _admin_section(
            'Assigned',
            'Complaints assigned to you',
            complaints.count(),
            'assignment_ind',
            'complaints',
            'blue',
        ),
        _admin_section(
            'Pending',
            'Waiting for first action',
            complaints.filter(work_status='pending').count(),
            'pending',
            'pending',
            'orange',
        ),
        _admin_section(
            'In progress',
            'Confirmed or processing',
            complaints.filter(work_status__in=['confirmed', 'process']).count(),
            'sync',
            'progress',
            'purple',
        ),
        _admin_section(
            'Solved',
            'Resolved by department',
            complaints.filter(work_status='solved').count(),
            'task_alt',
            'solved',
            'green',
        ),
        _admin_section(
            'Analytics',
            'Department performance',
            complaints.count(),
            'analytics',
            'analytics',
            'teal',
        ),
    ]

    scope_parts = [department.name]
    if department.city:
        scope_parts.append(department.city)
    if department.state:
        scope_parts.append(department.state)

    return Response(_admin_overview_payload(
        request,
        role='department',
        title='Department Admin',
        scope=' - '.join(scope_parts),
        complaints=complaints,
        departments=departments,
        citizen_count=citizens,
        sections=sections,
    ))


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def admin_app_resource(request, resource):
    """Role-scoped mobile admin resource lists and creates."""
    resource = (resource or '').strip().lower()
    if request.method == 'POST':
        return _create_admin_resource(request, resource)

    response = _build_admin_resource_payload(request, resource)
    if isinstance(response, Response):
        return response
    return Response(response)


@api_view(['PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def admin_app_resource_detail(request, resource, object_id):
    """Role-scoped mobile admin resource update/delete."""
    resource = (resource or '').strip().lower()
    if request.method == 'DELETE':
        return _delete_admin_resource(request, resource, object_id)
    return _update_admin_resource(request, resource, object_id)


@api_view(['POST', 'PATCH'])
@permission_classes([IsAuthenticated])
def admin_app_complaint_status(request, complaint_id):
    """Role-scoped mobile status update for admin complaint detail screens."""
    complaint = (
        _role_scoped_complaints(request.user)
        .select_related('assigned_department', 'user')
        .filter(id=complaint_id)
        .first()
    )
    if not complaint:
        return Response(
            {'success': False, 'message': 'Complaint not found in this admin scope.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    normalize_status = {
        'in_progress': 'process',
        'resolved': 'solved',
    }
    new_status = normalize_status.get(
        str(request.data.get('work_status') or request.data.get('status') or '').strip().lower(),
        str(request.data.get('work_status') or request.data.get('status') or '').strip().lower(),
    )
    notes = str(request.data.get('notes') or '').strip()
    proof_files = []
    for field_name in ('resolution_proofs', 'media_files', 'proof'):
        proof_files.extend(request.FILES.getlist(field_name))

    allowed_transitions = {
        'pending': {'pending', 'confirmed', 'rejected'},
        'reopened': {'reopened', 'confirmed', 'rejected'},
        'confirmed': {'confirmed', 'process'},
        'process': {'process', 'solved'},
        'solved': {'solved'},
        'rejected': {'rejected'},
    }
    current_status = normalize_status.get(complaint.work_status, complaint.work_status)
    valid_next = allowed_transitions.get(current_status, {current_status})

    if new_status not in valid_next:
        return Response(
            {
                'success': False,
                'message': f'Invalid status change from {current_status} to {new_status}.',
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if new_status == 'solved' and not notes and not complaint.resolution_notes:
        return Response(
            {'success': False, 'message': 'Resolution notes are required before marking solved.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if new_status == 'solved' and current_status != 'solved':
        if not proof_files and not complaint.resolution_proofs.exists():
            return Response(
                {'success': False, 'message': 'Completion proof is required before marking solved.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

    complaint.work_status = new_status
    if new_status == 'rejected':
        complaint.status = 'rejected'
    elif new_status in {'confirmed', 'process', 'solved'}:
        complaint.status = 'approved'
    if new_status in {'confirmed', 'process'} and not complaint.assigned_at:
        complaint.assigned_at = timezone.now()
    if notes:
        complaint.resolution_notes = notes
    if new_status == 'solved' and (current_status != 'solved' or not complaint.resolved_at):
        complaint.resolved_at = timezone.now()

    complaint.save()
    for proof in proof_files:
        proof_name = (getattr(proof, 'name', '') or '').lower()
        file_type = 'video' if proof_name.endswith(('.mp4', '.mov', '.avi', '.mkv', '.webm')) else 'image'
        ComplaintResolutionProof.objects.create(
            complaint=complaint,
            file=proof,
            file_type=file_type,
            uploaded_by=request.user if request.user.is_authenticated else None,
        )

    return Response({
        'success': True,
        'message': f'Complaint status updated to {complaint.get_work_status_display()}.',
        'complaint': ComplaintDetailSerializer(complaint, context={'request': request}).data,
    })


def _admin_status_counts(complaints):
    return {
        'total': complaints.count(),
        'pending': complaints.filter(work_status='pending').count(),
        'in_progress': complaints.filter(work_status__in=['confirmed', 'process']).count(),
        'solved': complaints.filter(work_status='solved').count(),
        'reopened': complaints.filter(work_status='reopened').count(),
        'rejected': complaints.filter(work_status='rejected').count(),
    }


def _admin_stats_from_counts(counts):
    return [
        _admin_stat('Total', counts.get('total', 0), 'assignment', 'blue'),
        _admin_stat('Pending', counts.get('pending', 0), 'pending', 'orange'),
        _admin_stat('In progress', counts.get('in_progress', 0), 'sync', 'purple'),
        _admin_stat('Solved', counts.get('solved', 0), 'check', 'green'),
        _admin_stat('Reopened', counts.get('reopened', 0), 'restart', 'red'),
        _admin_stat('Rejected', counts.get('rejected', 0), 'block', 'red'),
    ]


def _apply_work_status_filter(complaints, work_status):
    status_filter = str(work_status or '').strip().lower()
    if not status_filter:
        return complaints
    if status_filter in {'progress', 'in_progress', 'processing'}:
        return complaints.filter(work_status__in=['confirmed', 'process'])
    if status_filter in {'active', 'open', 'problems'}:
        return complaints.filter(work_status__in=ACTIVE_WORK_STATUSES)
    if status_filter == 'resolved':
        return complaints.filter(work_status='solved')
    return complaints.filter(work_status=status_filter)


def _safe_float(value, fallback=None):
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


def _serialize_complaint_point(complaint):
    lat = _safe_float(complaint.latitude)
    lng = _safe_float(complaint.longitude)
    if lat is None or lng is None:
        return None
    return {
        'id': complaint.id,
        'kind': 'complaint',
        'complaint_id': complaint.id,
        'complaint_number': complaint.complaint_number,
        'title': complaint.title,
        'subtitle': f"{complaint.city or 'Unknown city'} • {complaint.get_work_status_display()}",
        'latitude': lat,
        'longitude': lng,
        'status': complaint.work_status,
        'status_display': complaint.get_work_status_display(),
        'category': complaint.complaint_type,
        'category_display': complaint.get_complaint_type_display(),
        'created_at': complaint.created_at,
    }


def _serialize_department_point(department, active_count=0):
    lat = _safe_float(department.latitude)
    lng = _safe_float(department.longitude)
    if lat is None or lng is None:
        return None
    return {
        'id': department.id,
        'kind': 'department',
        'department_id': department.id,
        'title': department.name,
        'subtitle': _department_type_label(department.department_type),
        'latitude': lat,
        'longitude': lng,
        'status': 'active' if department.is_active else 'inactive',
        'active_cases': int(active_count or 0),
        'city': department.city,
        'state': department.state,
    }


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_app_department_detail(request, department_id):
    """Role-scoped mobile department detail, matching the web admin detail pages."""
    department = (
        _role_scoped_departments(request.user)
        .select_related('city_admin', 'city_admin__user')
        .filter(id=department_id)
        .first()
    )
    if not department:
        return Response(
            {'success': False, 'message': 'Department not found in this admin scope.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    complaints = (
        _role_scoped_complaints(request.user)
        .filter(assigned_department=department)
        .select_related('assigned_department', 'user')
        .prefetch_related('media')
    )
    counts = _admin_status_counts(complaints)
    officer = DepartmentUser.objects.select_related('user').filter(department=department).first()
    city_admin = department.city_admin

    department_data = dict(DepartmentSerializer(department, context={'request': request}).data)
    department_data['department_type_display'] = _department_type_label(department.department_type)
    department_data['city_admin_id'] = department.city_admin_id

    complaint_points = [
        point for point in (_serialize_complaint_point(item) for item in complaints.order_by('-created_at')[:80])
        if point
    ]
    department_point = _serialize_department_point(department, counts.get('total', 0))

    return Response({
        'success': True,
        'department': department_data,
        'stats': _admin_stats_from_counts(counts),
        'summary': counts,
        'officer': {
            'id': officer.user_id,
            'name': officer.user.get_full_name() or officer.user.username,
            'email': officer.user.email,
            'role': officer.role,
        } if officer else None,
        'city_admin': {
            'id': city_admin.id,
            'name': city_admin.user.get_full_name() or city_admin.user.email,
            'email': city_admin.user.email,
            'city': city_admin.city_name,
            'state': city_admin.state,
        } if city_admin else None,
        'complaints': ComplaintListSerializer(
            complaints.order_by('-created_at')[:40],
            many=True,
            context={'request': request},
        ).data,
        'map': {
            'department': department_point,
            'complaints': complaint_points,
        },
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_app_citizen_detail(request, profile_id):
    """Role-scoped mobile citizen detail for super/city/department admins."""
    profile = _role_scoped_citizens(request.user).filter(id=profile_id).first()
    if not profile:
        return Response(
            {'success': False, 'message': 'Citizen not found in this admin scope.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    complaints = (
        _role_scoped_complaints(request.user)
        .filter(user=profile.user)
        .select_related('assigned_department', 'user')
        .prefetch_related('media')
    )
    counts = _admin_status_counts(complaints)
    points = [
        point for point in (_serialize_complaint_point(item) for item in complaints.order_by('-created_at')[:80])
        if point
    ]

    return Response({
        'success': True,
        'citizen': _serialize_admin_citizen(profile),
        'stats': _admin_stats_from_counts(counts),
        'summary': counts,
        'complaints': ComplaintListSerializer(
            complaints.order_by('-created_at')[:50],
            many=True,
            context={'request': request},
        ).data,
        'map': {
            'complaints': points,
            'home': {
                'latitude': _safe_float(profile.latitude),
                'longitude': _safe_float(profile.longitude),
                'title': profile.user.get_full_name() or profile.user.username,
                'subtitle': profile.address or profile.city,
            },
        },
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_app_heatmap(request):
    """Role-scoped mobile map payload for complaints and departments."""
    complaints = _role_scoped_complaints(request.user).select_related('assigned_department', 'user')
    departments = _role_scoped_departments(request.user)

    status_filter = (request.query_params.get('work_status') or '').strip()
    category_filter = (request.query_params.get('category') or '').strip()
    department_id = request.query_params.get('department_id')

    complaints = _apply_work_status_filter(complaints, status_filter)
    if category_filter:
        complaints = complaints.filter(complaint_type=category_filter)
    if department_id:
        complaints = complaints.filter(assigned_department_id=department_id)
        departments = departments.filter(id=department_id)

    department_workload = {
        row['assigned_department_id']: row['total']
        for row in complaints.exclude(assigned_department__isnull=True)
        .values('assigned_department_id')
        .annotate(total=Count('id'))
    }

    complaint_points = [
        point for point in (
            _serialize_complaint_point(complaint)
            for complaint in complaints.order_by('-created_at')[:250]
        )
        if point
    ]
    department_points = [
        point for point in (
            _serialize_department_point(department, department_workload.get(department.id, 0))
            for department in departments.order_by('name')[:120]
        )
        if point
    ]

    all_points = complaint_points + department_points
    if all_points:
        center_lat = sum(point['latitude'] for point in all_points) / len(all_points)
        center_lng = sum(point['longitude'] for point in all_points) / len(all_points)
    else:
        center_lat, center_lng = 20.5937, 78.9629

    counts = _admin_status_counts(complaints)
    return Response({
        'success': True,
        'title': 'Admin Heatmap',
        'stats': _admin_stats_from_counts(counts),
        'summary': {
            **counts,
            'department_points': len(department_points),
            'complaint_points': len(complaint_points),
            'total_points': len(all_points),
        },
        'center': {
            'latitude': center_lat,
            'longitude': center_lng,
        },
        'complaints': complaint_points,
        'departments': department_points,
        'filters': {
            'work_status': status_filter,
            'category': category_filter,
            'department_id': department_id,
        },
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def admin_app_change_password(request):
    """Mobile admin password change using current password or email OTP."""
    role = _get_user_role(request.user)
    if role == 'citizen':
        return _admin_forbidden('Only admin accounts can use this password screen.')

    method = str(request.data.get('method') or 'old_password').strip().lower()
    email = (request.user.email or '').strip().lower()

    if not email:
        return Response(
            {'success': False, 'message': 'This admin account does not have an email address.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        validate_email(email)
    except ValidationError:
        return Response(
            {'success': False, 'message': 'This admin account email address is invalid.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if method == 'send_otp':
        otp_code = ''.join(secrets.choice('0123456789') for _ in range(6))
        OTP.objects.filter(email=email).delete()
        OTP.objects.create(email=email, otp=otp_code)

        try:
            send_otp_email(email, otp_code)
        except Exception:
            return Response(
                {'success': False, 'message': 'Unable to send OTP email right now. Please try again.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response({
            'success': True,
            'message': 'OTP sent to your admin email.',
        })

    current_password = str(request.data.get('current_password') or '').strip()
    new_password = str(request.data.get('new_password') or '').strip()
    confirm_password = str(request.data.get('confirm_password') or '').strip()

    if not new_password or not confirm_password:
        return Response(
            {'success': False, 'message': 'New password and confirmation are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if new_password != confirm_password:
        return Response(
            {'success': False, 'message': 'New password and confirmation do not match.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    otp = None
    if method == 'otp_verify':
        otp_code = str(request.data.get('otp') or '').strip()
        if not otp_code:
            return Response(
                {'success': False, 'message': 'OTP code is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            otp = OTP.objects.get(email=email, otp=otp_code, is_verified=False)
        except OTP.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Invalid OTP code.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if timezone.now() > otp.created_at + timedelta(minutes=10):
            return Response(
                {'success': False, 'message': 'OTP expired. Please request a new code.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
    elif method == 'old_password':
        if not current_password:
            return Response(
                {'success': False, 'message': 'Current password is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not request.user.check_password(current_password):
            return Response(
                {'success': False, 'message': 'Current password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
    else:
        return Response(
            {'success': False, 'message': 'Unsupported password change method.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        validate_password(new_password, request.user)
    except ValidationError as exc:
        return Response(
            {'success': False, 'message': ' '.join(exc.messages)},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if otp is not None:
        otp.is_verified = True
        otp.save(update_fields=['is_verified'])

    request.user.set_password(new_password)
    request.user.save(update_fields=['password'])
    return Response({'success': True, 'message': 'Password updated successfully.'})


def _build_admin_resource_payload(request, resource):
    user = request.user
    role = _get_user_role(user)
    query = (request.query_params.get('search') or '').strip()

    if resource in {'complaints', 'problems', 'solved', 'review', 'total'}:
        complaints = _role_scoped_complaints(user).select_related('assigned_department', 'user')
        if resource == 'problems':
            complaints = complaints.filter(work_status__in=ACTIVE_WORK_STATUSES)
        elif resource in {'solved', 'review'}:
            complaints = complaints.filter(work_status='solved')

        work_status = request.query_params.get('work_status')
        complaints = _apply_work_status_filter(complaints, work_status)
        if query:
            complaints = complaints.filter(
                Q(title__icontains=query) |
                Q(description__icontains=query) |
                Q(complaint_number__icontains=query) |
                Q(city__icontains=query)
            )

        return {
            'success': True,
            'resource': resource,
            'title': _resource_title(resource, work_status),
            'role': role,
            'items': ComplaintListSerializer(
                complaints.order_by('-created_at')[:100],
                many=True,
                context={'request': request},
            ).data,
            'count': complaints.count(),
            'can_create': False,
            'fields': [],
        }

    if resource in {'analytics', 'heatmap'}:
        complaints = _role_scoped_complaints(user)
        departments = _role_scoped_departments(user)
        status_rows = [
            {
                'id': index + 1,
                'name': row['work_status'].replace('_', ' ').title(),
                'subtitle': 'Complaint status',
                'count': row['total'],
                'color': row['work_status'],
            }
            for index, row in enumerate(
                complaints.values('work_status').annotate(total=Count('id')).order_by('-total')
            )
        ]
        category_rows = [
            {
                'id': 1000 + index,
                'name': _department_type_label(row['complaint_type']),
                'subtitle': 'Complaint category',
                'count': row['total'],
                'color': 'category',
            }
            for index, row in enumerate(
                complaints.values('complaint_type').annotate(total=Count('id')).order_by('-total')[:12]
            )
        ]
        department_rows = [
            {
                'id': 2000 + index,
                'name': row['assigned_department__name'] or 'Unassigned',
                'subtitle': 'Department workload',
                'count': row['total'],
                'color': 'department',
            }
            for index, row in enumerate(
                complaints.values('assigned_department__name').annotate(total=Count('id')).order_by('-total')[:12]
            )
        ]
        summary_rows = [
            {'id': 3001, 'name': 'Total Complaints', 'subtitle': 'In this admin scope', 'count': complaints.count(), 'color': 'blue'},
            {'id': 3002, 'name': 'Active Departments', 'subtitle': 'Available departments', 'count': departments.filter(is_active=True).count(), 'color': 'green'},
            {'id': 3003, 'name': 'Solved Complaints', 'subtitle': 'Resolution output', 'count': complaints.filter(work_status='solved').count(), 'color': 'solved'},
            {'id': 3004, 'name': 'Open Problems', 'subtitle': 'Needs action', 'count': complaints.filter(work_status__in=ACTIVE_WORK_STATUSES).count(), 'color': 'pending'},
        ]
        items = summary_rows + status_rows + category_rows + department_rows
        return {
            'success': True,
            'resource': resource,
            'title': 'Analytics',
            'role': role,
            'items': items,
            'count': len(items),
            'can_create': False,
            'fields': [],
        }

    if resource == 'departments':
        departments = _role_scoped_departments(user).select_related('city_admin', 'city_admin__user')
        if query:
            departments = departments.filter(
                Q(name__icontains=query) |
                Q(email__icontains=query) |
                Q(phone__icontains=query) |
                Q(city__icontains=query) |
                Q(state__icontains=query)
            )

        data = _serialize_departments(request, departments, limit=100)
        return {
            'success': True,
            'resource': resource,
            'title': 'Departments',
            'role': role,
            'items': data,
            'count': departments.count(),
            'can_create': role in {'superadmin', 'city_admin'},
            'fields': _department_form_fields(request),
        }

    if resource == 'citizens':
        if role == 'department':
            complaints = _role_scoped_complaints(user)
            user_ids = complaints.exclude(user__isnull=True).values_list('user_id', flat=True).distinct()
            citizens = CitizenProfile.objects.select_related('user').filter(user_id__in=user_ids)
        elif role == 'city_admin':
            city_admin = CityAdmin.objects.filter(user=user, is_active=True).first()
            if not city_admin:
                citizens = CitizenProfile.objects.none()
            else:
                citizens = CitizenProfile.objects.select_related('user').filter(
                    Q(city__iexact=city_admin.city_name) | Q(district__iexact=city_admin.city_name),
                    state__iexact=city_admin.state,
                )
        elif role == 'superadmin':
            citizens = CitizenProfile.objects.select_related('user').all()
        else:
            return _admin_forbidden()

        if query:
            citizens = citizens.filter(
                Q(user__first_name__icontains=query) |
                Q(user__last_name__icontains=query) |
                Q(user__email__icontains=query) |
                Q(mobile_no__icontains=query) |
                Q(city__icontains=query)
            )

        return {
            'success': True,
            'resource': resource,
            'title': 'Citizens',
            'role': role,
            'items': [_serialize_admin_citizen(profile) for profile in citizens.order_by('user__first_name')[:100]],
            'count': citizens.count(),
            'can_create': False,
            'fields': [],
        }

    if resource == 'city-admins':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can manage city admins.')
        admins = CityAdmin.objects.select_related('user').all()
        if query:
            admins = admins.filter(
                Q(user__first_name__icontains=query) |
                Q(user__last_name__icontains=query) |
                Q(user__email__icontains=query) |
                Q(city_name__icontains=query) |
                Q(state__icontains=query)
            )
        return {
            'success': True,
            'resource': resource,
            'title': 'City Admins',
            'role': role,
            'items': [_serialize_city_admin(admin) for admin in admins.order_by('city_name', 'user__first_name')[:100]],
            'count': admins.count(),
            'can_create': True,
            'fields': _city_admin_form_fields(),
        }

    if resource == 'categories':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can manage categories.')
        categories = ComplaintCategory.objects.prefetch_related('subcategories').all()
        if query:
            categories = categories.filter(Q(name__icontains=query) | Q(key__icontains=query))
        return {
            'success': True,
            'resource': resource,
            'title': 'Categories',
            'role': role,
            'items': [_serialize_category(category) for category in categories.order_by('display_order', 'name')[:100]],
            'count': categories.count(),
            'can_create': True,
            'fields': _category_form_fields(),
        }

    if resource == 'states':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can manage states.')
        states = ManagedState.objects.prefetch_related('cities').all()
        if query:
            states = states.filter(Q(name__icontains=query) | Q(code__icontains=query))
        return {
            'success': True,
            'resource': resource,
            'title': 'States',
            'role': role,
            'items': [_serialize_state(state_obj) for state_obj in states.order_by('name')[:100]],
            'count': states.count(),
            'can_create': True,
            'fields': _state_form_fields(),
        }

    if resource == 'cities':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can manage cities.')
        cities = ManagedCity.objects.select_related('state').all()
        if query:
            cities = cities.filter(Q(name__icontains=query) | Q(code__icontains=query) | Q(state__name__icontains=query))
        return {
            'success': True,
            'resource': resource,
            'title': 'Cities',
            'role': role,
            'items': [_serialize_city(city) for city in cities.order_by('state__name', 'name')[:100]],
            'count': cities.count(),
            'can_create': True,
            'fields': _city_form_fields(),
        }

    return Response(
        {'success': False, 'message': f'Unknown admin resource: {resource}'},
        status=status.HTTP_404_NOT_FOUND,
    )


def _resource_title(resource, work_status=None):
    status_filter = str(work_status or '').strip().lower()
    if status_filter == 'pending':
        return 'Pending Complaints'
    if status_filter in {'progress', 'in_progress', 'processing'}:
        return 'In Progress Complaints'
    if status_filter == 'reopened':
        return 'Reopened Complaints'
    if status_filter == 'rejected':
        return 'Rejected Complaints'
    return {
        'complaints': 'Complaints',
        'problems': 'Open Problems',
        'solved': 'Solved Complaints',
        'review': 'Review Queue',
        'total': 'All Complaints',
    }.get(resource, resource.title())


def _department_form_fields(request):
    role = _get_user_role(request.user)
    city_admins = []
    if role == 'superadmin':
        city_admins = [
            {
                'id': admin.id,
                'label': f"{admin.user.get_full_name() or admin.user.email} - {admin.city_name}, {admin.state}",
                'city': admin.city_name,
                'state': admin.state,
            }
            for admin in CityAdmin.objects.filter(is_active=True).select_related('user').order_by('city_name')
        ]

    return [
        {'key': 'name', 'label': 'Department name', 'type': 'text', 'required': True},
        {
            'key': 'department_type',
            'label': 'Department type',
            'type': 'select',
            'required': True,
            'options': [
                {'value': value, 'label': _clean_department_type_display(value)}
                for value, _label in Department.DEPARTMENT_TYPES
            ],
        },
        {'key': 'email', 'label': 'Login email', 'type': 'email', 'required': True},
        {'key': 'phone', 'label': 'Phone', 'type': 'phone', 'required': True},
        {'key': 'address', 'label': 'Address', 'type': 'textarea', 'required': True},
        {'key': 'unique_id', 'label': 'Department code', 'type': 'text', 'required': False},
        {'key': 'sla_hours', 'label': 'SLA hours', 'type': 'number', 'required': True, 'default': '72'},
        {'key': 'latitude', 'label': 'Latitude', 'type': 'number', 'required': False},
        {'key': 'longitude', 'label': 'Longitude', 'type': 'number', 'required': False},
        {'key': 'city_admin_id', 'label': 'City admin', 'type': 'select', 'required': role == 'superadmin', 'options': city_admins},
        {'key': 'password', 'label': 'Login password', 'type': 'password', 'required': False},
        {'key': 'is_active', 'label': 'Active', 'type': 'bool', 'required': False, 'default': True},
    ]


def _city_admin_form_fields():
    return [
        {'key': 'full_name', 'label': 'Full name', 'type': 'text', 'required': True},
        {'key': 'email', 'label': 'Login email', 'type': 'email', 'required': True},
        {'key': 'state', 'label': 'State', 'type': 'text', 'required': True},
        {'key': 'city', 'label': 'City', 'type': 'text', 'required': True},
        {'key': 'pincode', 'label': 'Pincode', 'type': 'text', 'required': False},
        {'key': 'contact_address', 'label': 'Office address', 'type': 'textarea', 'required': True},
        {'key': 'password', 'label': 'Login password', 'type': 'password', 'required': False},
        {'key': 'is_active', 'label': 'Active', 'type': 'bool', 'required': False, 'default': True},
    ]


def _category_form_fields():
    return [
        {'key': 'name', 'label': 'Category name', 'type': 'text', 'required': True},
        {'key': 'key', 'label': 'Category key', 'type': 'text', 'required': False},
        {'key': 'display_order', 'label': 'Display order', 'type': 'number', 'required': False},
        {'key': 'is_active', 'label': 'Active', 'type': 'bool', 'required': False, 'default': True},
    ]


def _state_form_fields():
    return [
        {'key': 'name', 'label': 'State name', 'type': 'text', 'required': True},
        {'key': 'code', 'label': 'State code', 'type': 'text', 'required': False},
    ]


def _city_form_fields():
    return [
        {'key': 'name', 'label': 'City name', 'type': 'text', 'required': True},
        {'key': 'code', 'label': 'City code', 'type': 'text', 'required': False},
        {
            'key': 'state_id',
            'label': 'State',
            'type': 'select',
            'required': True,
            'options': [
                {'value': state_obj.id, 'label': state_obj.name}
                for state_obj in ManagedState.objects.order_by('name')
            ],
        },
    ]


def _create_admin_resource(request, resource):
    role = _get_user_role(request.user)
    if resource == 'departments':
        if role not in {'superadmin', 'city_admin'}:
            return _admin_forbidden('This account cannot create departments.')
        return _save_department_resource(request, None)
    if resource == 'city-admins':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can create city admins.')
        return _save_city_admin_resource(request, None)
    if resource == 'categories':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can create categories.')
        return _save_category_resource(request, None)
    if resource == 'states':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can create states.')
        return _save_state_resource(request, None)
    if resource == 'cities':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can create cities.')
        return _save_city_resource(request, None)
    return Response({'success': False, 'message': 'This resource cannot be created from mobile.'}, status=status.HTTP_400_BAD_REQUEST)


def _update_admin_resource(request, resource, object_id):
    role = _get_user_role(request.user)
    if resource == 'departments':
        department = _role_scoped_departments(request.user).filter(id=object_id).first()
        if not department or role not in {'superadmin', 'city_admin'}:
            return _admin_forbidden('This account cannot update this department.')
        return _save_department_resource(request, department)
    if resource == 'city-admins':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can update city admins.')
        city_admin = CityAdmin.objects.select_related('user').filter(id=object_id).first()
        if not city_admin:
            return Response({'success': False, 'message': 'City admin not found.'}, status=status.HTTP_404_NOT_FOUND)
        return _save_city_admin_resource(request, city_admin)
    if resource == 'categories':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can update categories.')
        category = ComplaintCategory.objects.filter(id=object_id).first()
        if not category:
            return Response({'success': False, 'message': 'Category not found.'}, status=status.HTTP_404_NOT_FOUND)
        return _save_category_resource(request, category)
    if resource == 'states':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can update states.')
        state_obj = ManagedState.objects.filter(id=object_id).first()
        if not state_obj:
            return Response({'success': False, 'message': 'State not found.'}, status=status.HTTP_404_NOT_FOUND)
        return _save_state_resource(request, state_obj)
    if resource == 'cities':
        if role != 'superadmin':
            return _admin_forbidden('Only the main admin can update cities.')
        city = ManagedCity.objects.select_related('state').filter(id=object_id).first()
        if not city:
            return Response({'success': False, 'message': 'City not found.'}, status=status.HTTP_404_NOT_FOUND)
        return _save_city_resource(request, city)
    return Response({'success': False, 'message': 'This resource cannot be updated from mobile.'}, status=status.HTTP_400_BAD_REQUEST)


def _delete_admin_resource(request, resource, object_id):
    role = _get_user_role(request.user)
    if role != 'superadmin' and resource not in {'departments'}:
        return _admin_forbidden('Only the main admin can delete this resource.')

    if resource == 'departments':
        department = _role_scoped_departments(request.user).filter(id=object_id).first()
        if not department or role not in {'superadmin', 'city_admin'}:
            return _admin_forbidden('This account cannot delete this department.')
        if Complaint.objects.filter(assigned_department=department).exists():
            department.is_active = False
            department.save(update_fields=['is_active'])
            return Response({'success': True, 'message': 'Department has complaints, so it was marked inactive.'})
        DepartmentUser.objects.filter(department=department).delete()
        department.delete()
        return Response({'success': True, 'message': 'Department deleted.'})

    if resource == 'city-admins':
        city_admin = CityAdmin.objects.filter(id=object_id).first()
        if not city_admin:
            return Response({'success': False, 'message': 'City admin not found.'}, status=status.HTTP_404_NOT_FOUND)
        if Department.objects.filter(city_admin=city_admin).exists():
            city_admin.is_active = False
            city_admin.save(update_fields=['is_active'])
            return Response({'success': True, 'message': 'City admin has departments, so it was marked inactive.'})
        user_obj = city_admin.user
        city_admin.delete()
        user_obj.delete()
        return Response({'success': True, 'message': 'City admin deleted.'})

    if resource == 'categories':
        category = ComplaintCategory.objects.filter(id=object_id).first()
        if not category:
            return Response({'success': False, 'message': 'Category not found.'}, status=status.HTTP_404_NOT_FOUND)
        category.is_active = False
        category.save(update_fields=['is_active'])
        return Response({'success': True, 'message': 'Category marked inactive.'})

    if resource == 'states':
        state_obj = ManagedState.objects.filter(id=object_id).first()
        if not state_obj:
            return Response({'success': False, 'message': 'State not found.'}, status=status.HTTP_404_NOT_FOUND)
        if state_obj.cities.exists():
            return Response({'success': False, 'message': 'Delete cities under this state first.'}, status=status.HTTP_400_BAD_REQUEST)
        state_obj.delete()
        return Response({'success': True, 'message': 'State deleted.'})

    if resource == 'cities':
        city = ManagedCity.objects.filter(id=object_id).first()
        if not city:
            return Response({'success': False, 'message': 'City not found.'}, status=status.HTTP_404_NOT_FOUND)
        city.delete()
        return Response({'success': True, 'message': 'City deleted.'})

    return Response({'success': False, 'message': 'This resource cannot be deleted from mobile.'}, status=status.HTTP_400_BAD_REQUEST)


def _save_department_resource(request, department):
    data = request.data
    role = _get_user_role(request.user)

    name = str(data.get('name', department.name if department else '')).strip()
    department_type = str(data.get('department_type', department.department_type if department else '')).strip()
    email = str(data.get('email', department.email if department else '')).strip().lower()
    phone = str(data.get('phone', department.phone if department else '')).strip()
    address = str(data.get('address', department.address if department else '')).strip()
    unique_id = str(data.get('unique_id', department.unique_id if department else '')).strip() or _generate_mobile_department_code()
    sla_hours = data.get('sla_hours', department.sla_hours if department else 72)
    latitude = data.get('latitude', department.latitude if department else 20.5937)
    longitude = data.get('longitude', department.longitude if department else 78.9629)
    password = str(data.get('password', '')).strip() or _generate_mobile_password()

    if not name:
        return Response({'success': False, 'message': 'Department name is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if department_type not in {value for value, _label in Department.DEPARTMENT_TYPES}:
        return Response({'success': False, 'message': 'Valid department type is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not email:
        return Response({'success': False, 'message': 'Department email is required.'}, status=status.HTTP_400_BAD_REQUEST)
    email_error = _validate_email_value(email)
    if email_error:
        return Response({'success': False, 'message': email_error}, status=status.HTTP_400_BAD_REQUEST)
    if not phone:
        return Response({'success': False, 'message': 'Department phone is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not address:
        return Response({'success': False, 'message': 'Department address is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        sla_hours = int(sla_hours)
        latitude = float(latitude)
        longitude = float(longitude)
    except (TypeError, ValueError):
        return Response({'success': False, 'message': 'SLA and coordinates must be valid numbers.'}, status=status.HTTP_400_BAD_REQUEST)

    if department is None and User.objects.filter(Q(email__iexact=email) | Q(username__iexact=email)).exists():
        return Response({'success': False, 'message': 'A user with this department email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
    dept_user = None
    if department is not None:
        dept_user = DepartmentUser.objects.filter(department=department).select_related('user').first()
        excluded_user_id = dept_user.user_id if dept_user else None
        if User.objects.exclude(id=excluded_user_id).filter(Q(email__iexact=email) | Q(username__iexact=email)).exists():
            return Response({'success': False, 'message': 'A user with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
    if Department.objects.exclude(id=department.id if department else None).filter(unique_id=unique_id).exists():
        unique_id = _generate_mobile_department_code()

    if role == 'superadmin':
        city_admin_id = data.get('city_admin_id') or data.get('city_admin')
        city_admin = CityAdmin.objects.filter(id=city_admin_id, is_active=True).first()
        if not city_admin:
            return Response({'success': False, 'message': 'Select a valid city admin.'}, status=status.HTTP_400_BAD_REQUEST)
    else:
        city_admin = CityAdmin.objects.filter(user=request.user, is_active=True).first()
        if not city_admin:
            return _admin_forbidden('This account is not linked to a city admin.')

    try:
        with transaction.atomic():
            if department is None:
                user_obj = User.objects.create_user(
                    username=email,
                    email=email,
                    password=password,
                    first_name=name[:30],
                    last_name='Department',
                )
                department = Department.objects.create(
                    city_admin=city_admin,
                    name=name,
                    department_type=department_type,
                    unique_id=unique_id,
                    email=email,
                    phone=phone,
                    address=address,
                    latitude=latitude,
                    longitude=longitude,
                    sla_hours=sla_hours,
                    state=city_admin.state,
                    city=city_admin.city_name,
                    location_name=city_admin.city_name,
                    is_active=_as_bool(data.get('is_active'), True),
                )
                DepartmentUser.objects.create(user=user_obj, department=department, role='Officer')
            else:
                department.city_admin = city_admin
                department.name = name
                department.department_type = department_type
                department.unique_id = unique_id
                department.email = email
                department.phone = phone
                department.address = address
                department.latitude = latitude
                department.longitude = longitude
                department.sla_hours = sla_hours
                department.state = city_admin.state
                department.city = city_admin.city_name
                department.location_name = department.location_name or city_admin.city_name
                department.is_active = _as_bool(data.get('is_active'), department.is_active)
                department.save()

                if dept_user:
                    dept_user.user.email = email
                    dept_user.user.username = email
                    if data.get('password'):
                        dept_user.user.set_password(str(data.get('password')).strip())
                    dept_user.user.save()
                else:
                    user_obj = User.objects.create_user(
                        username=email,
                        email=email,
                        password=password,
                        first_name=name[:30],
                        last_name='Department',
                    )
                    DepartmentUser.objects.create(user=user_obj, department=department, role='Officer')
    except IntegrityError:
        return Response({'success': False, 'message': 'Department email/code already exists.'}, status=status.HTTP_400_BAD_REQUEST)

    return Response({
        'success': True,
        'message': 'Department saved.',
        'item': dict(_serialize_departments(request, Department.objects.filter(id=department.id))[0]),
    })


def _save_city_admin_resource(request, city_admin):
    data = request.data
    full_name = str(data.get('full_name', '') or data.get('name', '')).strip()
    if city_admin and not full_name:
        full_name = city_admin.user.get_full_name() or city_admin.user.username
    email = str(data.get('email', city_admin.user.email if city_admin else '')).strip().lower()
    city = str(data.get('city', city_admin.city_name if city_admin else '')).strip()
    state_name = str(data.get('state', city_admin.state if city_admin else '')).strip()
    pincode = str(data.get('pincode', city_admin.pincode if city_admin else '')).strip()
    contact_address = str(data.get('contact_address', city_admin.contact_address if city_admin else '')).strip()
    password = str(data.get('password', '')).strip() or _generate_mobile_password()

    if not all([full_name, email, city, state_name, contact_address]):
        return Response({'success': False, 'message': 'Name, email, state, city, and office address are required.'}, status=status.HTTP_400_BAD_REQUEST)
    email_error = _validate_email_value(email)
    if email_error:
        return Response({'success': False, 'message': email_error}, status=status.HTTP_400_BAD_REQUEST)
    if User.objects.exclude(id=city_admin.user_id if city_admin else None).filter(Q(email__iexact=email) | Q(username__iexact=email)).exists():
        return Response({'success': False, 'message': 'A user with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)

    first_name = full_name.split(' ')[0]
    last_name = ' '.join(full_name.split(' ')[1:]) if ' ' in full_name else ''
    try:
        with transaction.atomic():
            if city_admin is None:
                user_obj = User.objects.create_user(
                    username=email,
                    email=email,
                    password=password,
                    first_name=first_name,
                    last_name=last_name,
                )
                city_admin = CityAdmin.objects.create(
                    user=user_obj,
                    city_name=city,
                    state=state_name,
                    pincode=pincode,
                    contact_address=contact_address,
                    is_active=_as_bool(data.get('is_active'), True),
                )
            else:
                city_admin.user.username = email
                city_admin.user.email = email
                city_admin.user.first_name = first_name
                city_admin.user.last_name = last_name
                if data.get('password'):
                    city_admin.user.set_password(str(data.get('password')).strip())
                city_admin.user.save()
                city_admin.city_name = city
                city_admin.state = state_name
                city_admin.pincode = pincode
                city_admin.contact_address = contact_address
                city_admin.is_active = _as_bool(data.get('is_active'), city_admin.is_active)
                city_admin.save()
    except IntegrityError:
        return Response({'success': False, 'message': 'City admin email already exists.'}, status=status.HTTP_400_BAD_REQUEST)

    return Response({'success': True, 'message': 'City admin saved.', 'item': _serialize_city_admin(city_admin)})


def _save_category_resource(request, category):
    data = request.data
    name = str(data.get('name', category.name if category else '')).strip()
    key = str(data.get('key', category.key if category else '')).strip().lower().replace(' ', '-')
    if not key and name:
        key = ''.join(ch if ch.isalnum() else '-' for ch in name.lower()).strip('-')[:20]
    if not name:
        return Response({'success': False, 'message': 'Category name is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not key:
        return Response({'success': False, 'message': 'Category key is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if ComplaintCategory.objects.exclude(id=category.id if category else None).filter(key=key).exists():
        return Response({'success': False, 'message': 'Category key already exists.'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        display_order = int(data.get('display_order', category.display_order if category else 0) or 0)
    except (TypeError, ValueError):
        display_order = 0
    if category is None:
        category = ComplaintCategory.objects.create(
            key=key,
            name=name,
            display_order=display_order,
            is_active=_as_bool(data.get('is_active'), True),
        )
    else:
        category.key = key
        category.name = name
        category.display_order = display_order
        category.is_active = _as_bool(data.get('is_active'), category.is_active)
        category.save()
    return Response({'success': True, 'message': 'Category saved.', 'item': _serialize_category(category)})


def _save_state_resource(request, state_obj):
    data = request.data
    name = str(data.get('name', state_obj.name if state_obj else '')).strip()
    code = str(data.get('code', state_obj.code if state_obj else '')).strip().upper()
    if not name:
        return Response({'success': False, 'message': 'State name is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not code:
        code = ''.join(part[:2].upper() for part in name.split() if part)[:20] or name[:3].upper()
    if ManagedState.objects.exclude(id=state_obj.id if state_obj else None).filter(Q(name__iexact=name) | Q(code__iexact=code)).exists():
        return Response({'success': False, 'message': 'State name/code already exists.'}, status=status.HTTP_400_BAD_REQUEST)
    if state_obj is None:
        state_obj = ManagedState.objects.create(name=name, code=code)
    else:
        state_obj.name = name
        state_obj.code = code
        state_obj.save()
    return Response({'success': True, 'message': 'State saved.', 'item': _serialize_state(state_obj)})


def _save_city_resource(request, city):
    data = request.data
    name = str(data.get('name', city.name if city else '')).strip()
    code = str(data.get('code', city.code if city else '')).strip().upper()
    state_id = data.get('state_id') or (city.state_id if city else None)
    state_obj = ManagedState.objects.filter(id=state_id).first()
    if not name:
        return Response({'success': False, 'message': 'City name is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not state_obj:
        return Response({'success': False, 'message': 'Select a valid state.'}, status=status.HTTP_400_BAD_REQUEST)
    if not code:
        code = f"{state_obj.code}-{''.join(part[:2].upper() for part in name.split() if part)[:12] or name[:3].upper()}"
    if ManagedCity.objects.exclude(id=city.id if city else None).filter(code__iexact=code).exists():
        return Response({'success': False, 'message': 'City code already exists.'}, status=status.HTTP_400_BAD_REQUEST)
    if ManagedCity.objects.exclude(id=city.id if city else None).filter(name__iexact=name, state=state_obj).exists():
        return Response({'success': False, 'message': 'City already exists under this state.'}, status=status.HTTP_400_BAD_REQUEST)
    if city is None:
        city = ManagedCity.objects.create(name=name, code=code, state=state_obj)
    else:
        city.name = name
        city.code = code
        city.state = state_obj
        city.save()
    return Response({'success': True, 'message': 'City saved.', 'item': _serialize_city(city)})


# Complaint Views
class ComplaintViewSet(viewsets.ModelViewSet):
    def _get_uploaded_media_files(self, request):
        """Support both app and web multipart field names for complaint media."""
        images = request.FILES.getlist('media')
        if images:
            return images
        return request.FILES.getlist('media_files')

    def _get_remote_image_as_file(self, url):
        """Download remote image (Cloudinary URL) for AI verification."""
        if not url: return None
        import requests
        from django.core.files.base import ContentFile
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                # Use a specific filename for identification
                return ContentFile(response.content, name="voice_assistant_proof.jpg")
        except Exception as e:
            print(f"Failed to fetch remote image for AI verification: {e}")
        return None

    def _is_uploaded_only_verification_mode(self, request):
        """App-only mode: run Gemini validation when proof is uploaded, but do not require proof."""
        raw_value = str(request.data.get('uploaded_only_verification', '')).strip().lower()
        return raw_value in {'1', 'true', 'yes'}

    def _is_proof_expected(self, request):
        """
        Detect whether the client says it attached proof.
        This lets us fail closed when the upload never reaches the server.
        """
        raw_value = str(request.data.get('proof_expected', '')).strip().lower()
        return raw_value in {'1', 'true', 'yes'}

    def _is_retryable_ai_failure(self, ai_msg):
        normalized = str(ai_msg or '').strip().lower()
        return any(
            token in normalized
            for token in [
                'temporarily busy',
                'try the same proof again',
                'try again in a moment',
                'try again later',
                'service unavailable',
                'high demand',
                'resource exhausted',
                'rate limit',
            ]
        )

    def _build_ai_failure_response(self, selected_issue, ai_msg):
        if self._is_retryable_ai_failure(ai_msg):
            return {
                'message': ai_msg,
                'ai_verification_failed': True,
                'retryable': True,
            }, status.HTTP_503_SERVICE_UNAVAILABLE

        return {
            'message': f"Invalid proof for {selected_issue}. {ai_msg} Please upload the right image to continue.",
            'ai_verification_failed': True,
            'retryable': False,
        }, status.HTTP_400_BAD_REQUEST

    def get_permissions(self):
        if self.action == 'create':
            return [AllowAny()]
        return [IsAuthenticated()]
    
    def get_serializer_class(self):
        if self.action == 'list':
            return ComplaintListSerializer
        elif self.action == 'create':
            return ComplaintCreateSerializer
        return ComplaintDetailSerializer
    
    def get_queryset(self):
        user = self.request.user
        role = _get_user_role(user)

        if role == 'superadmin':
            queryset = Complaint.objects.all()
        elif role == 'city_admin':
            city_admin = CityAdmin.objects.filter(user=user, is_active=True).first()
            queryset = _city_admin_complaints(city_admin) if city_admin else Complaint.objects.none()
        elif role == 'department':
            dept_user = DepartmentUser.objects.select_related('department').filter(user=user).first()
            queryset = Complaint.objects.filter(assigned_department=dept_user.department) if dept_user else Complaint.objects.none()
        else:
            queryset = Complaint.objects.filter(user=user)

        queryset = queryset.order_by('-created_at')
        
        # Filter by status
        work_status = self.request.query_params.get('work_status')
        queryset = _apply_work_status_filter(queryset, work_status)
        
        # Filter by complaint type
        complaint_type = self.request.query_params.get('complaint_type')
        if complaint_type:
            queryset = queryset.filter(complaint_type=complaint_type)
        
        # Search
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) |
                Q(description__icontains=search) |
                Q(complaint_number__icontains=search)
            )
        
        return queryset.select_related('assigned_department', 'user').prefetch_related(
            'media',
            'resolution_proofs',
            'reopen_proofs',
        )
    
    @action(detail=False, methods=['post'], url_path='verify-proof')
    def verify_proof(self, request):
        """Verify if the uploaded image matches the category without creating a complaint."""
        ctype = request.data.get('complaint_type')
        category_label = dict(Complaint.COMPLAINT_TYPES).get(ctype, ctype or 'selected category')
        subcat = (request.data.get('subcategory') or '').strip()
        desc = (request.data.get('description') or '').strip()
        images = self._get_uploaded_media_files(request)
        remote_url = request.data.get('image_url')
        
        # Categories that skip AI but still might have images
        skip_keys = ['police', 'cyber', 'other']

        if not images and not remote_url:
            if ctype in skip_keys:
                return Response({'success': True, 'message': 'No images to verify (optional for this category)'})
            return Response({
                'success': False,
                'message': 'No proof file reached the server. Please upload the image again.',
                'ai_verification_failed': True,
                'proof_received': False,
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get the first available image (local or remote)
        verify_image = images[0] if images else self._get_remote_image_as_file(remote_url)
        if not verify_image:
            return Response({
                'success': False,
                'message': 'Failed to access the proof image for verification.',
                'ai_verification_failed': True
            }, status=status.HTTP_400_BAD_REQUEST)

        from .ai_utils import verify_complaint_proof
        is_valid, ai_msg = verify_complaint_proof(
            verify_image,
            category_label,
            category_key=ctype,
            subcategory=subcat,
            complaint_description=desc,
        )
        
        if not is_valid:
            selected_issue = subcat or category_label
            payload, response_status = self._build_ai_failure_response(selected_issue, ai_msg)
            return Response({
                'success': False,
                **payload,
            }, status=response_status)
            
        return Response({'success': True, 'message': 'Proof verified'})

    @action(detail=False, methods=['post'], url_path='analyze-media')
    def analyze_media(self, request):
        """Analyze uploaded media and infer complaint category/subcategory for chat intake."""
        media_files = self._get_uploaded_media_files(request)
        if not media_files:
            return Response({
                'success': False,
                'message': 'No media file reached the server. Please upload an image or video again.',
            }, status=status.HTTP_400_BAD_REQUEST)

        categories = []
        active_categories = (
            ComplaintCategory.objects
            .filter(is_active=True)
            .prefetch_related('subcategories')
            .order_by('display_order', 'name')
        )
        for category in active_categories:
            subcategories = [
                sub.name for sub in category.subcategories.all()
                if sub.is_active
            ]
            categories.append({
                'key': category.key,
                'name': category.name,
                'emoji': category.emoji or '',
                'subcategories': subcategories,
            })

        if not categories:
            categories = [
                {
                    'key': key,
                    'name': label,
                    'emoji': '',
                    'subcategories': ['Other'],
                }
                for key, label in Complaint.COMPLAINT_TYPES
            ]

        from .ai_utils import analyze_complaint_media
        analysis = analyze_complaint_media(media_files[0], categories)
        if not analysis.get('success'):
            return Response(analysis, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        category_key = str(analysis.get('category_key') or '').strip().lower()
        matched_category = next(
            (category for category in categories if category['key'] == category_key),
            None,
        )
        if matched_category is None:
            matched_category = next(
                (category for category in categories if category['key'] == 'other'),
                categories[-1],
            )
            category_key = matched_category['key']

        subcategory = str(analysis.get('subcategory') or '').strip()
        valid_subcategories = matched_category.get('subcategories') or ['Other']
        if subcategory not in valid_subcategories:
            normalized = subcategory.lower()
            subcategory = next(
                (
                    option for option in valid_subcategories
                    if option.lower() == normalized
                ),
                valid_subcategories[0],
            )

        return Response({
            'success': True,
            'analysis': {
                **analysis,
                'category_key': category_key,
                'category': matched_category['name'],
                'category_name': matched_category['name'],
                'category_emoji': matched_category.get('emoji') or '',
                'subcategory': subcategory,
                'available_subcategories': valid_subcategories,
            },
        })

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data, context={'request': request})
            if serializer.is_valid():
                # Check for duplicates before saving
                try:
                    lat = float(request.data.get('latitude') or 0)
                    lon = float(request.data.get('longitude') or 0)
                except (ValueError, TypeError):
                    lat, lon = 0.0, 0.0
                
                ctype = request.data.get('complaint_type')
                print(f"DEBUG API: Category Key received: {ctype}")
                subcat = request.data.get('subcategory', '')
                desc = request.data.get('description', '')
                uploaded_only_mode = self._is_uploaded_only_verification_mode(request)
                proof_expected = self._is_proof_expected(request)
                
                from .ai_utils import verify_complaint_proof
                # Get human-readable category name for the prompt
                category_label = dict(Complaint.COMPLAINT_TYPES).get(ctype, ctype or 'selected category')
                images = self._get_uploaded_media_files(request)
                remote_url = request.data.get('image_url')
                
                # Categories that skip AI but still might have images
                skip_keys = ['police', 'cyber', 'other']

                if images or remote_url:
                    # Get image to verify
                    verify_image = images[0] if images else self._get_remote_image_as_file(remote_url)
                    
                    if verify_image:
                        is_valid, ai_msg = verify_complaint_proof(
                            verify_image,
                            category_label,
                            category_key=ctype,
                            subcategory=subcat,
                            complaint_description=desc,
                        )
                        if not is_valid:
                            selected_issue = subcat or category_label
                            payload, response_status = self._build_ai_failure_response(selected_issue, ai_msg)
                            return Response({
                                'success': False,
                                **payload,
                            }, status=response_status)
                elif proof_expected:
                    return Response({
                        'success': False,
                        'message': 'Proof upload failed before verification. Please upload the image again.',
                        'ai_verification_failed': True,
                        'proof_received': False,
                    }, status=status.HTTP_400_BAD_REQUEST)
                elif ctype not in skip_keys and not uploaded_only_mode:
                    # No image provided for infrastructure categories
                    return Response({
                        'success': False,
                        'message': f"Proof Required: Please upload a photo of the {category_label} issue.",
                        'ai_verification_failed': True
                    }, status=status.HTTP_400_BAD_REQUEST)
                # ------------------------------------

                # Check for duplicate unless user explicitly bypasses it
                bypass = request.data.get('bypass_duplicate') == True or request.data.get('bypass_duplicate') == 'true'
                duplicate = None if bypass else Complaint.check_duplicate(lat, lon, ctype, subcat, description=desc)
                
                if duplicate:
                    # Mask ID: first 3 chars + XXXXXX
                    orig_id = duplicate.complaint_number
                    masked_id = f"{orig_id[:3]}XXXXXX" if len(orig_id) > 3 else f"{orig_id}XXXX"
                    
                    return Response({
                        'success': False,
                        'message': f'Thank you for applied complaint! This issue has already been reported by another citizen in this area. Our team is already working on it. (Ticket: {masked_id})',
                        'duplicate_found': True,
                        'existing_ticket': masked_id,
                        'original_ticket': orig_id
                    }, status=status.HTTP_400_BAD_REQUEST)

                complaint = serializer.save()
                detail_serializer = ComplaintDetailSerializer(complaint, context={'request': request})
                return Response({
                    'success': True,
                    'message': 'Complaint submitted successfully',
                    'complaint': detail_serializer.data
                }, status=status.HTTP_201_CREATED)
            
            # Extract first error message for easier debugging
            error_msg = 'Validation error'
            if serializer.errors:
                first_field = list(serializer.errors.keys())[0]
                first_err = serializer.errors[first_field]
                if isinstance(first_err, list) and first_err:
                    error_msg = f"{first_field}: {first_err[0]}"
                else:
                    error_msg = f"{first_field}: {first_err}"

            return Response({
                'success': False,
                'message': error_msg,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            import traceback
            traceback.print_exc()
            return Response({
                'success': False,
                'message': f'Submission Error: {str(e)}'
            }, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=True, methods=['post'])
    def rate(self, request, pk=None):
        """Rate a complaint"""
        complaint = self.get_object()
        
        if complaint.work_status != 'solved':
            return Response({
                'success': False,
                'message': 'Can only rate solved complaints'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        rating = request.data.get('rating')
        feedback = request.data.get('feedback', '')
        
        if not rating or not (1 <= int(rating) <= 5):
            return Response({
                'success': False,
                'message': 'Rating must be between 1 and 5'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        complaint.citizen_rating = rating
        complaint.citizen_feedback = feedback
        complaint.citizen_rated_at = timezone.now()
        complaint.save()
        
        return Response({
            'success': True,
            'message': 'Rating submitted successfully'
        })
    
    @action(detail=True, methods=['post'])
    def reopen(self, request, pk=None):
        """Reopen a complaint"""
        complaint = self.get_object()
        
        if not complaint.can_reopen:
            return Response({
                'success': False,
                'message': 'Complaint cannot be reopened'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        reason = request.data.get('reason')
        proof = (
            request.FILES.get('proof')
            or request.FILES.get('media_files')
            or request.FILES.get('resolution_proofs')
        )
        
        if not reason or not proof:
            return Response({
                'success': False,
                'message': 'Reason and proof are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create reopen proof
        ComplaintReopenProof.objects.create(
            complaint=complaint,
            reason=reason,
            proof=proof,
            requested_by=request.user
        )
        
        # Update complaint status
        complaint.work_status = 'reopened'
        complaint.reopened_at = timezone.now()
        complaint.reopen_count += 1
        complaint.reopen_reason = reason
        complaint.reopen_requested_by = request.user
        complaint.save()
        
        return Response({
            'success': True,
            'message': 'Complaint reopened successfully'
        })


# Category Views
@api_view(['GET'])
@permission_classes([AllowAny])
def get_categories(request):
    """Get all complaint categories"""
    categories = ComplaintCategory.objects.filter(is_active=True).order_by('display_order')
    serializer = ComplaintCategorySerializer(categories, many=True, context={'request': request})
    return Response({
        'success': True,
        'categories': serializer.data
    })


@api_view(['GET'])
@permission_classes([AllowAny])
def get_subcategories(request, category_key):
    """Get subcategories and dynamic fields for a category"""
    try:
        category = ComplaintCategory.objects.get(key=category_key, is_active=True)
        subcategories = category.subcategories.filter(is_active=True).prefetch_related('dynamic_fields').order_by('display_order')
        # Category-level fields (no subcategory)
        cat_fields = category.dynamic_fields.filter(is_active=True, subcategory__isnull=True).order_by('display_order')
        return Response({
            'success': True,
            'subcategories': ComplaintSubcategorySerializer(subcategories, many=True).data,
            'category_fields': ComplaintCategoryFieldSerializer(cat_fields, many=True).data,
        })
    except ComplaintCategory.DoesNotExist:
        return Response({'success': True, 'subcategories': [], 'category_fields': []})


# Guest Track Complaint
@api_view(['POST'])
@permission_classes([AllowAny])
def track_guest_complaint_api(request):
    complaint_number = request.data.get('complaint_number', '').strip()
    phone = request.data.get('phone', '').strip()
    if not complaint_number or not phone:
        return Response({'success': False, 'message': 'Complaint ID and mobile number are required'}, status=status.HTTP_400_BAD_REQUEST)
    complaint = None
    complaint_query = (
        Complaint.objects
        .select_related('assigned_department', 'user', 'user__citizenprofile')
        .prefetch_related('resolution_proofs', 'reopen_proofs')
    )
    try:
        complaint = complaint_query.get(complaint_number=complaint_number, guest_phone=phone)
    except Complaint.DoesNotExist:
        pass
    if not complaint:
        for comp in complaint_query.filter(complaint_number=complaint_number, user__isnull=False):
            if comp.user and hasattr(comp.user, 'citizenprofile') and comp.user.citizenprofile.mobile_no == phone:
                complaint = comp
                break
    if not complaint:
        return Response({'success': False, 'message': 'Invalid complaint ID or mobile number'}, status=status.HTTP_404_NOT_FOUND)
    dept = complaint.assigned_department
    data = {
        'complaint_number': complaint.complaint_number,
        'title': complaint.title,
        'complaint_type': complaint.get_complaint_type_display(),
        'complaint_type_display': complaint.get_complaint_type_display(),
        'status': complaint.status,
        'status_display': complaint.get_status_display(),
        'work_status': complaint.work_status,
        'work_status_display': complaint.get_work_status_display(),
        'description': complaint.description,
        'city': complaint.city or '',
        'state': complaint.state or '',
        'pincode': complaint.pincode or '',
        'created_at': complaint.created_at.strftime('%d %b %Y, %I:%M %p'),
        'updated_at': complaint.updated_at.strftime('%d %b %Y, %I:%M %p') if complaint.updated_at else None,
        'resolved_at': complaint.resolved_at.strftime('%d %b %Y, %I:%M %p') if complaint.resolved_at else None,
        'resolution_notes': complaint.resolution_notes or '',
        'can_reopen': complaint.can_reopen,
        'reopen_deadline': complaint.reopen_deadline.isoformat() if complaint.reopen_deadline else None,
        'citizen_rating': complaint.citizen_rating,
        'citizen_feedback': complaint.citizen_feedback or '',
        'resolution_proofs': ComplaintResolutionProofSerializer(
            complaint.resolution_proofs.all(),
            many=True,
            context={'request': request},
        ).data,
        'reopen_proofs': ComplaintReopenProofSerializer(
            complaint.reopen_proofs.all(),
            many=True,
            context={'request': request},
        ).data,
        'assigned_department': dept.name if dept else None,
        'assigned_department_phone': dept.phone if dept else None,
        'assigned_department_email': dept.email if dept else None,
        'assigned_department_latitude': float(dept.latitude) if (dept and dept.latitude) else 0.0,
        'assigned_department_longitude': float(dept.longitude) if (dept and dept.longitude) else 0.0,
        'latitude': float(complaint.latitude) if complaint.latitude else 0.0,
        'longitude': float(complaint.longitude) if complaint.longitude else 0.0,
        'contact_name': complaint.user.get_full_name() if complaint.user else (complaint.guest_name or ''),
        'mobile': complaint.user.citizenprofile.mobile_no if (complaint.user and hasattr(complaint.user, 'citizenprofile')) else (complaint.guest_phone or ''),
        'email': complaint.user.email if complaint.user else (complaint.guest_email or ''),
    }
    return Response({'success': True, 'complaint': data})


@api_view(['GET'])
@permission_classes([AllowAny])
def guest_stats(request):
    """Public live stats for guest dashboard"""
    total = Complaint.objects.count()
    pending = Complaint.objects.filter(work_status__in=['pending', 'confirmed', 'process', 'reopened']).count()
    solved = Complaint.objects.filter(work_status='solved').count()
    departments = Department.objects.filter(is_active=True).count()
    return Response({
        'success': True,
        'total_complaints': total,
        'pending_complaints': pending,
        'solved_complaints': solved,
        'active_departments': departments,
    })


# States & Cities Views
@api_view(['GET'])
@permission_classes([AllowAny])
def get_states_cities(request):
    """Get all admin-managed states and their cities"""
    try:
        from .models import ManagedState, ManagedCity
        states = list(ManagedState.objects.all().order_by('name').values('id', 'name'))
        cities = list(ManagedCity.objects.all().select_related('state').order_by('name').values('id', 'name', 'state__name'))
        cities_by_state = {}
        for city in cities:
            state_name = city['state__name']
            cities_by_state.setdefault(state_name, []).append(city['name'])
        return Response({
            'success': True,
            'states': [s['name'] for s in states],
            'cities_by_state': cities_by_state,
        })
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Error loading states/cities: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)


# Department Views
@api_view(['GET'])
@permission_classes([AllowAny])
def get_departments(request):
    """Get all departments — public"""
    try:
        departments = Department.objects.filter(is_active=True)
        serializer = DepartmentSerializer(departments, many=True, context={'request': request})
        return Response({
            'success': True,
            'departments': serializer.data
        })
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Error loading departments: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def department_forgot_password(request):
    """Reset password for department user — sends new password to their email"""
    from .email_utils import send_password_reset_credentials_email
    import string

    email = request.data.get('email', '').strip()
    if not email:
        return Response({'success': False, 'message': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({'success': False, 'message': 'No department account found with this email'}, status=status.HTTP_404_NOT_FOUND)

    # Check DepartmentUser table (department staff)
    dept_user = DepartmentUser.objects.filter(user=user).select_related('department').first()
    dept = dept_user.department if dept_user else None

    if not dept:
        return Response({'success': False, 'message': 'This email is not linked to any department account'}, status=status.HTTP_403_FORBIDDEN)

    # Generate new 10-char password
    chars = string.ascii_letters + string.digits + '@#$'
    new_password = ''.join(random.choices(chars, k=10))

    user.set_password(new_password)
    user.save()

    send_password_reset_credentials_email(
        email=email,
        user_name=user.get_full_name() or dept.name,
        new_password=new_password,
        department=dept,
    )

    return Response({'success': True, 'message': 'New password sent to your email'}, status=status.HTTP_200_OK)


# AI Assistant Views
@api_view(['POST'])
@permission_classes([AllowAny])
def ai_chat(request):
    """Chat with AI assistant for complaint booking - now using CityFix LLM"""
    try:
        user_input = request.data.get('message', '').strip()
        session_id = request.data.get('session_id', 'default')
        user_email = request.data.get('user_email')
        user_name = request.data.get('user_name')
        preferred_language = request.data.get('preferred_language', 'english')
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        city = request.data.get('city')
        state = request.data.get('state')
        
        if not user_input:
            return Response({
                'success': False,
                'message': 'Message is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if CityFix LLM is available
        if cityfix_llm.health_check():
            # Use CityFix LLM
            llm_response = cityfix_llm.chat(
                message=user_input,
                session_id=session_id,
                user_name=user_name,
                preferred_language=preferred_language
            )
            
            return Response({
                'success': True,
                'response': llm_response.get('response', 'I understand your concern. How can I help you today?'),
                'detected_category': llm_response.get('detected_category'),
                'detected_subcategory': llm_response.get('detected_subcategory'),
                'urgency': llm_response.get('urgency', 'medium'),
                'emotion': llm_response.get('emotion', 'neutral'),
                'language': llm_response.get('language', preferred_language),
                'is_emergency': llm_response.get('is_emergency', False),
                'confidence': llm_response.get('confidence', 0.5),
                'next_step': llm_response.get('next_step', 'intake'),
                'missing_fields': llm_response.get('missing_fields', []),
                'alternatives': llm_response.get('alternatives', []),
                'processing_ms': llm_response.get('processing_ms', 0),
                'session_id': llm_response.get('session_id', session_id),
                'llm_powered': True
            })
        else:
            # Fallback to rule-based AI
            ai_assistant = SmartCityAI.for_session(session_id)
            
            # Update location data if provided
            if latitude and longitude:
                ai_assistant.complaint_data['latitude'] = float(latitude)
                ai_assistant.complaint_data['longitude'] = float(longitude)
            if city:
                ai_assistant.complaint_data['city'] = city
            if state:
                ai_assistant.complaint_data['state'] = state
            
            response_data = ai_assistant.generate_response(
                user_input,
                user_email=user_email,
                user_name=user_name,
                preferred_language=preferred_language,
            )
            
            # Check for duplicate if location is available
            duplicate_info = None
            if latitude and longitude and ai_assistant.complaint_data.get('category') and ai_assistant.complaint_data.get('subcategory'):
                if not ai_assistant.complaint_data.get('duplicate_check_done'):
                    duplicate_info = ai_assistant.check_duplicate_complaint(float(latitude), float(longitude))
                    ai_assistant.complaint_data['duplicate_check_done'] = True
                    
                    if duplicate_info and duplicate_info.get('found'):
                        response_data['response'] = f"⚠️ {duplicate_info['message']}\n\nThis complaint is already being handled by our team. You can track it using the ticket number provided.\n\nWould you like to submit a new complaint for a different issue?"
                        response_data['duplicate_found'] = True
                        response_data['duplicate_ticket'] = duplicate_info['masked_id']
            
            # Get nearest department if location is available
            department_info = None
            if latitude and longitude and ai_assistant.complaint_data.get('category'):
                if not ai_assistant.complaint_data.get('department_assigned'):
                    department_info = ai_assistant.get_nearest_department(float(latitude), float(longitude))
                    if department_info:
                        ai_assistant.complaint_data['department_assigned'] = department_info
                        response_data['assigned_department'] = department_info
                        response_data['response'] += f"\n\n📍 Your complaint will be assigned to: {department_info['name']}\n📞 Contact: {department_info['phone']}\n⏱️ Expected resolution: {department_info['sla_hours']} hours"
            
            return Response({
                'success': True,
                'response': response_data['response'],
                'detected_category': response_data.get('detected_category'),
                'urgency': response_data.get('urgency'),
                'emotion': response_data.get('emotion'),
                'language': response_data.get('language'),
                'next_step': response_data.get('next_step'),
                'session_id': session_id,
                'llm_powered': False,
                'duplicate_found': response_data.get('duplicate_found', False),
                'duplicate_ticket': response_data.get('duplicate_ticket'),
                'assigned_department': response_data.get('assigned_department'),
            })
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'AI Chat Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_nudge(request):
    """Generate localized AI re-engagement notification content."""
    try:
        session_id = request.data.get('session_id', 'default')
        user_name = request.data.get('user_name')
        preferred_language = request.data.get('preferred_language')

        ai_assistant = SmartCityAI.for_session(session_id)
        if user_name:
            ai_assistant.user_context['user_name'] = str(user_name).strip()
        if preferred_language:
            ai_assistant.user_context['preferred_language'] = str(preferred_language).strip()
        ai_assistant._persist_cached_state()

        nudge = ai_assistant.generate_reengagement_nudge()
        return Response({
            'success': True,
            'session_id': session_id,
            'title': nudge['title'],
            'body': nudge['body'],
        })
    except Exception as e:
        return Response({
            'success': False,
            'message': f'AI Nudge Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_extract_complaint(request):
    """Extract structured complaint data from AI conversation - now using CityFix LLM"""
    try:
        session_id = request.data.get('session_id', 'default')
        
        # Check if CityFix LLM is available
        if cityfix_llm.health_check():
            # Get session data from CityFix LLM
            try:
                import requests
                response = requests.get(
                    f"{cityfix_llm.base_url}/session/{session_id}",
                    timeout=10
                )
                if response.status_code == 200:
                    session_data = response.json()
                    complaint_info = {
                        'category': session_data.get('category'),
                        'subcategory': session_data.get('subcategory'),
                        'location': session_data.get('location'),
                        'description': session_data.get('description'),
                        'urgency': session_data.get('urgency'),
                        'language': session_data.get('language'),
                    }
                else:
                    complaint_info = {}
            except:
                complaint_info = {}
        else:
            # Fallback to rule-based AI
            ai_assistant = SmartCityAI.for_session(session_id)
            complaint_info = ai_assistant.extract_complaint_info()
        
        return Response({
            'success': True,
            'complaint_data': complaint_info
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Extraction Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_voice_chat(request):
    """Voice-enabled AI chat for complaint booking"""
    try:
        # This would handle voice input/output
        # For now, treating it as text input
        user_input = request.data.get('message', '').strip()
        voice_enabled = request.data.get('voice_enabled', False)
        language = request.data.get('language', 'english')
        
        if not user_input:
            return Response({
                'success': False,
                'message': 'Message is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        session_id = request.data.get('session_id', 'default')
        ai_assistant = SmartCityAI.for_session(session_id)
        response_data = ai_assistant.generate_response(user_input)
        
        # Add voice-specific metadata
        response_data['voice_enabled'] = voice_enabled
        response_data['suggested_voice_tone'] = 'caring' if response_data.get('emotion') in ['worried', 'frustrated'] else 'friendly'
        
        return Response({
            'success': True,
            'session_id': session_id,
            **response_data
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Voice Chat Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_history(request):
    """Return AI conversation history for a session."""
    try:
        session_id = request.data.get('session_id', 'default')
        ai_assistant = SmartCityAI.for_session(session_id)
        return Response({
            'success': True,
            'session_id': session_id,
            'history': ai_assistant.get_history(),
            'complaint_data': ai_assistant.extract_complaint_info(),
        })
    except Exception as e:
        return Response({
            'success': False,
            'message': f'AI History Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_reset(request):
    """Reset AI session conversation."""
    try:
        session_id = request.data.get('session_id', 'default')
        SmartCityAI.clear_session(session_id)
        return Response({
            'success': True,
            'session_id': session_id,
            'message': 'AI session reset'
        })
    except Exception as e:
        return Response({
            'success': False,
            'message': f'AI Reset Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_check_duplicate(request):
    """Check for duplicate complaints before submission."""
    try:
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        category = request.data.get('category')
        subcategory = request.data.get('subcategory')
        description = request.data.get('description', '')
        
        if not all([latitude, longitude, category, subcategory]):
            return Response({
                'success': False,
                'message': 'Latitude, longitude, category, and subcategory are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Map category display name to key
        category_key_map = {
            "Police Complaint": "police",
            "Traffic Complaint": "traffic",
            "Construction Complaint": "construction",
            "Water Supply": "water",
            "Electricity": "electricity",
            "Garbage/Sanitation": "garbage",
            "Road/Pothole": "road",
            "Drainage/Sewage": "drainage",
            "Illegal Activities": "illegal",
            "Transportation": "transportation",
            "Cyber Crime": "cyber",
            "Other Complaint": "other",
        }
        
        category_key = category_key_map.get(category, category.lower().replace(" ", ""))
        
        # Check for duplicate
        duplicate = Complaint.check_duplicate(
            latitude=float(latitude),
            longitude=float(longitude),
            complaint_type=category_key,
            subcategory=subcategory,
            description=description
        )
        
        if duplicate:
            # Mask the complaint ID for privacy
            orig_id = duplicate.complaint_number
            masked_id = f"{orig_id[:3]}XXXXXX" if len(orig_id) > 3 else f"{orig_id}XXXX"
            
            return Response({
                'success': True,
                'duplicate_found': True,
                'masked_ticket': masked_id,
                'original_ticket': orig_id,
                'message': f'This issue has already been reported by another citizen in this area. Ticket: {masked_id}',
                'complaint_status': duplicate.get_work_status_display(),
                'created_at': duplicate.created_at.strftime('%Y-%m-%d %H:%M'),
            })
        
        return Response({
            'success': True,
            'duplicate_found': False,
            'message': 'No duplicate found. You can proceed with submission.'
        })
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Duplicate Check Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([AllowAny])
def ai_gemini_status(request):
    """Lightweight diagnostics endpoint for deployed Gemini configuration."""
    api_key = getattr(settings, 'GEMINI_API_KEY', '').strip()
    model_name = getattr(settings, 'GEMINI_MODEL', 'gemini-1.5-flash')

    return Response({
        'success': True,
        'configured': bool(api_key),
        'model': model_name,
        'skip_categories': [],
        'message': 'Gemini verification is configured.' if api_key else 'Gemini API key is missing on the server.',
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def ai_get_department(request):
    """Get nearest department for complaint."""
    try:
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        category = request.data.get('category')
        city = request.data.get('city', '')
        state = request.data.get('state', '')
        
        if not all([latitude, longitude, category]):
            return Response({
                'success': False,
                'message': 'Latitude, longitude, and category are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Map category display name to key
        category_key_map = {
            "Police Complaint": "police",
            "Traffic Complaint": "traffic",
            "Construction Complaint": "construction",
            "Water Supply": "water",
            "Electricity": "electricity",
            "Garbage/Sanitation": "garbage",
            "Road/Pothole": "road",
            "Drainage/Sewage": "drainage",
            "Illegal Activities": "illegal",
            "Transportation": "transportation",
            "Cyber Crime": "cyber",
            "Other Complaint": "other",
        }
        
        category_key = category_key_map.get(category, category.lower().replace(" ", ""))
        
        # Create temporary complaint object to use backend logic
        temp_complaint = Complaint(
            complaint_type=category_key,
            latitude=float(latitude),
            longitude=float(longitude),
            city=city,
            state=state
        )
        
        # Get nearest department
        nearest_dept = temp_complaint.get_nearest_department()
        
        if nearest_dept:
            return Response({
                'success': True,
                'department': {
                    'id': nearest_dept.id,
                    'name': nearest_dept.name,
                    'type': nearest_dept.get_department_type_display(),
                    'email': nearest_dept.email,
                    'phone': nearest_dept.phone,
                    'address': nearest_dept.formatted_address,
                    'sla_hours': nearest_dept.sla_hours,
                    'latitude': float(nearest_dept.latitude) if nearest_dept.latitude else 0.0,
                    'longitude': float(nearest_dept.longitude) if nearest_dept.longitude else 0.0,
                },
                'message': f'Your complaint will be assigned to {nearest_dept.name}'
            })
        
        return Response({
            'success': False,
            'message': 'No department found for this category and location'
        }, status=status.HTTP_404_NOT_FOUND)
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Department Lookup Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def get_cloudinary_signature(request):
    """Generate Cloudinary upload signature for secure client-side uploads."""
    try:
        import hashlib
        import time
        from django.conf import settings
        
        timestamp = int(time.time())
        folder = 'complaints'
        
        # Get Cloudinary config
        cloudinary_config = settings.CLOUDINARY_STORAGE
        api_secret = cloudinary_config.get('API_SECRET', '')
        cloud_name = cloudinary_config.get('CLOUD_NAME', '')
        api_key = cloudinary_config.get('API_KEY', '')
        
        if not api_secret or not cloud_name or not api_key:
            return Response({
                'success': False,
                'message': 'Cloudinary not configured properly'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        # Build params for signature (alphabetically sorted)
        params_to_sign = f"folder={folder}&timestamp={timestamp}"
        
        # Generate signature using SHA-1 (Cloudinary requirement)
        signature = hashlib.sha1(f"{params_to_sign}{api_secret}".encode()).hexdigest()
        
        return Response({
            'success': True,
            'signature': signature,
            'timestamp': timestamp,
            'cloud_name': cloud_name,
            'api_key': api_key,
            'folder': folder,
        })
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Signature Generation Error: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
