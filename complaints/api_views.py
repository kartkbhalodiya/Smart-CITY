from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db.models import Q, Count
from django.utils import timezone
from datetime import timedelta
import random

from .models import (
    Complaint, ComplaintMedia, ComplaintResolutionProof, ComplaintReopenProof,
    CitizenProfile, Department, ComplaintCategory, ComplaintSubcategory,
    ComplaintCategoryField, ComplaintFieldResponse, OTP
)
from .serializers import (
    ComplaintListSerializer, ComplaintDetailSerializer, ComplaintCreateSerializer,
    CitizenProfileSerializer, DepartmentSerializer, ComplaintCategorySerializer,
    ComplaintSubcategorySerializer, UserSerializer, RegisterSerializer,
    OTPSerializer, DashboardStatsSerializer
)


# Authentication Views
@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """Register new user"""
    serializer = RegisterSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'success': True,
            'message': 'User registered successfully',
            'token': token.key,
            'user': UserSerializer(user).data
        }, status=status.HTTP_201_CREATED)
    return Response({
        'success': False,
        'errors': serializer.errors
    }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def send_otp(request):
    """Send OTP to email"""
    email = request.data.get('email')
    if not email:
        return Response({
            'success': False,
            'message': 'Email is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    # Generate 6-digit OTP
    otp_code = str(random.randint(100000, 999999))
    
    # Delete old OTPs for this email
    OTP.objects.filter(email=email).delete()
    
    # Create new OTP
    otp = OTP.objects.create(email=email, otp=otp_code)
    
    # TODO: Send email (for now, return OTP in response for testing)
    # In production, send via email service
    
    return Response({
        'success': True,
        'message': 'OTP sent successfully',
        'otp': otp_code  # Remove this in production!
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    """Verify OTP and login/register user"""
    email = request.data.get('email')
    otp_code = request.data.get('otp')
    
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
            email=email,
            defaults={'username': email.split('@')[0]}
        )
        
        # Create citizen profile if new user
        if created:
            CitizenProfile.objects.create(
                user=user,
                surname='',
                city='',
                address='',
                mobile_no=''
            )
        
        # Get or create token
        token, _ = Token.objects.get_or_create(user=user)
        
        return Response({
            'success': True,
            'message': 'Login successful',
            'token': token.key,
            'user': UserSerializer(user).data,
            'is_new_user': created
        }, status=status.HTTP_200_OK)
        
    except OTP.DoesNotExist:
        return Response({
            'success': False,
            'message': 'Invalid OTP'
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_user(request):
    """Logout user"""
    try:
        request.user.auth_token.delete()
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
    permission_classes = [IsAuthenticated]
    
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
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            complaint = serializer.save()
            detail_serializer = ComplaintDetailSerializer(complaint, context={'request': request})
            return Response({
                'success': True,
                'message': 'Complaint submitted successfully',
                'complaint': detail_serializer.data
            }, status=status.HTTP_201_CREATED)
        return Response({
            'success': False,
            'errors': serializer.errors
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
@permission_classes([IsAuthenticated])
def get_categories(request):
    """Get all complaint categories"""
    categories = ComplaintCategory.objects.filter(is_active=True).order_by('display_order')
    serializer = ComplaintCategorySerializer(categories, many=True, context={'request': request})
    return Response({
        'success': True,
        'categories': serializer.data
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_subcategories(request, category_key):
    """Get subcategories for a category"""
    try:
        category = ComplaintCategory.objects.get(key=category_key, is_active=True)
        subcategories = category.subcategories.filter(is_active=True).order_by('display_order')
        serializer = ComplaintSubcategorySerializer(subcategories, many=True)
        return Response({
            'success': True,
            'subcategories': serializer.data
        })
    except ComplaintCategory.DoesNotExist:
        return Response({
            'success': False,
            'message': 'Category not found'
        }, status=status.HTTP_404_NOT_FOUND)


# Department Views
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_departments(request):
    """Get all departments"""
    departments = Department.objects.filter(is_active=True)
    serializer = DepartmentSerializer(departments, many=True, context={'request': request})
    return Response({
        'success': True,
        'departments': serializer.data
    })
