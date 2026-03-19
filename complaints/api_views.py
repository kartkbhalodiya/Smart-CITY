from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db.models import Q, Count
from django.utils import timezone
from datetime import timedelta
import random
import string
import secrets

from .models import (
    Complaint, ComplaintMedia, ComplaintResolutionProof, ComplaintReopenProof,
    CitizenProfile, Department, DepartmentUser, ComplaintCategory, ComplaintSubcategory,
    ComplaintCategoryField, ComplaintFieldResponse, OTP, CityAdmin
)
from .serializers import (
    ComplaintListSerializer, ComplaintDetailSerializer, ComplaintCreateSerializer,
    CitizenProfileSerializer, DepartmentSerializer, ComplaintCategorySerializer,
    ComplaintSubcategorySerializer, ComplaintCategoryFieldSerializer, UserSerializer, RegisterSerializer,
    OTPSerializer, DashboardStatsSerializer
)
from .email_utils import (
    send_welcome_email, send_otp_email, send_password_reset_credentials_email
)
from .conversational_ai import SmartCityAI


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
            
            role = 'citizen'
            if user.is_superuser:
                role = 'superadmin'
            elif CityAdmin.objects.filter(user=user).exists():
                role = 'city_admin'
            elif DepartmentUser.objects.filter(user=user).exists():
                role = 'department'

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

    role = 'citizen'
    if user.is_superuser:
        role = 'superadmin'
    elif CityAdmin.objects.filter(user=user).exists():
        role = 'city_admin'
    elif DepartmentUser.objects.filter(user=user).exists():
        role = 'department'

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
    try:
        profile = request.user.citizenprofile
    except CitizenProfile.DoesNotExist:
        profile = CitizenProfile.objects.create(
            user=request.user,
            surname='',
            city='',
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
        user.first_name = request.data.get('first_name', user.first_name)
        user.last_name = request.data.get('last_name', user.last_name)
        user.save()
        
        # Update profile fields
        profile.surname = request.data.get('surname', profile.surname)
        profile.mobile_no = request.data.get('mobile_no', profile.mobile_no)
        profile.state = request.data.get('state', profile.state)
        profile.district = request.data.get('district', profile.district)
        profile.city = request.data.get('city', profile.city)
        profile.address = request.data.get('address', profile.address)
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


# Complaint Views
class ComplaintViewSet(viewsets.ModelViewSet):
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
        queryset = Complaint.objects.filter(user=user).order_by('-created_at')
        
        # Filter by status
        work_status = self.request.query_params.get('work_status')
        if work_status:
            queryset = queryset.filter(work_status=work_status)
        
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
        
        return queryset.prefetch_related('media', 'resolution_proofs', 'assigned_department')
    
    @action(detail=False, methods=['post'], url_path='verify-proof')
    def verify_proof(self, request):
        """Verify if the uploaded image matches the category without creating a complaint."""
        ctype = request.data.get('complaint_type')
        category_label = dict(Complaint.COMPLAINT_TYPES).get(ctype, ctype)
        images = request.FILES.getlist('media')
        
        # Categories that skip AI but still might have images
        skip_keys = ['police', 'cyber', 'other']

        if not images:
            if ctype in skip_keys:
                return Response({'success': True, 'message': 'No images to verify (optional for this category)'})
            else:
                return Response({
                    'success': False,
                    'message': f"Proof Required: Please upload a photo of the {category_label} issue.",
                    'ai_verification_failed': True
                }, status=status.HTTP_400_BAD_REQUEST)

        from .ai_utils import verify_complaint_proof
        is_valid, ai_msg = verify_complaint_proof(images[0], category_label, category_key=ctype)
        
        if not is_valid:
            return Response({
                'success': False,
                'message': f"Invalid Proof: please upload a right proof for {category_label} to continue complaint.",
                'ai_verification_failed': True
            }, status=status.HTTP_400_BAD_REQUEST)
            
        return Response({'success': True, 'message': 'Proof verified'})

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
                
                # --- AI Image Verification (New) ---
                from .ai_utils import verify_complaint_proof
                # Get human-readable category name for the prompt
                category_label = dict(Complaint.COMPLAINT_TYPES).get(ctype, ctype)
                images = request.FILES.getlist('media')
                
                # Categories that skip AI but still might have images
                skip_keys = ['police', 'cyber', 'other']

                if images:
                    # Check first uploaded image
                    is_valid, ai_msg = verify_complaint_proof(images[0], category_label, category_key=ctype)
                    if not is_valid:
                        return Response({
                            'success': False,
                            'message': f"Invalid Proof: please upload a right proof for {category_label} to continue complaint.",
                            'ai_verification_failed': True
                        }, status=status.HTTP_400_BAD_REQUEST)
                elif ctype not in skip_keys:
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
        proof = request.FILES.get('proof')
        
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
    try:
        complaint = Complaint.objects.select_related('assigned_department').get(complaint_number=complaint_number, guest_phone=phone)
    except Complaint.DoesNotExist:
        pass
    if not complaint:
        for comp in Complaint.objects.filter(complaint_number=complaint_number, user__isnull=False).select_related('assigned_department', 'user__citizenprofile'):
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
        'work_status': complaint.work_status,
        'description': complaint.description,
        'city': complaint.city or '',
        'state': complaint.state or '',
        'pincode': complaint.pincode or '',
        'created_at': complaint.created_at.strftime('%d %b %Y, %I:%M %p'),
        'updated_at': complaint.updated_at.strftime('%d %b %Y, %I:%M %p') if complaint.updated_at else None,
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
    """Chat with AI assistant for complaint booking"""
    try:
        user_input = request.data.get('message', '').strip()
        session_id = request.data.get('session_id', 'default')
        user_email = request.data.get('user_email')
        user_name = request.data.get('user_name')
        preferred_language = request.data.get('preferred_language')
        
        if not user_input:
            return Response({
                'success': False,
                'message': 'Message is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Initialize or get existing AI session
        ai_assistant = SmartCityAI.for_session(session_id)
        
        # Generate response
        response_data = ai_assistant.generate_response(
            user_input,
            user_email=user_email,
            user_name=user_name,
            preferred_language=preferred_language,
        )
        
        return Response({
            'success': True,
            'response': response_data['response'],
            'detected_category': response_data.get('detected_category'),
            'urgency': response_data.get('urgency'),
            'emotion': response_data.get('emotion'),
            'language': response_data.get('language'),
            'next_step': response_data.get('next_step'),
            'session_id': session_id
        })
        
    except Exception as e:
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
    """Extract structured complaint data from AI conversation"""
    try:
        session_id = request.data.get('session_id', 'default')
        
        # Initialize AI assistant with persisted session
        ai_assistant = SmartCityAI.for_session(session_id)
        
        # Extract complaint information
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
