from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import (
    TokenRefreshView,
    TokenVerifyView,
)
from .api_views import (
    ComplaintViewSet,
    register_user, send_otp, verify_otp, logout_user, login_with_password,
    user_profile, dashboard_stats,
    get_categories, get_subcategories, get_departments,
    track_guest_complaint_api, department_forgot_password,
    get_states_cities, guest_stats
)

router = DefaultRouter()
router.register(r'complaints', ComplaintViewSet, basename='complaint')

urlpatterns = [
    # Authentication
    path('auth/register/', register_user, name='api_register'),
    path('auth/login/', login_with_password, name='api_login'),
    path('auth/send-otp/', send_otp, name='api_send_otp'),
    path('auth/verify-otp/', verify_otp, name='api_verify_otp'),
    path('auth/logout/', logout_user, name='api_logout'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/token/verify/', TokenVerifyView.as_view(), name='token_verify'),
    
    # User Profile
    path('user/profile/', user_profile, name='api_user_profile'),
    
    # Dashboard
    path('dashboard/stats/', dashboard_stats, name='api_dashboard_stats'),
    
    # Categories
    path('categories/', get_categories, name='api_categories'),
    path('categories/<str:category_key>/subcategories/', get_subcategories, name='api_subcategories'),
    
    # Departments
    path('departments/', get_departments, name='api_departments'),
    
    # Guest Track
    path('track-guest/', track_guest_complaint_api, name='api_track_guest'),
    
    # Department Forgot Password
    path('auth/department-forgot-password/', department_forgot_password, name='api_dept_forgot_password'),
    
    # States & Cities
    path('states-cities/', get_states_cities, name='api_states_cities'),
    path('guest/stats/', guest_stats, name='api_guest_stats'),
    
    # Router URLs
    path('', include(router.urls)),
]
