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
    get_states_cities, guest_stats,
    ai_chat, ai_extract_complaint, ai_voice_chat, ai_history, ai_reset, ai_nudge,
    ai_check_duplicate, ai_gemini_status, ai_get_department, get_cloudinary_signature
)
from .enhanced_ai_views import enhanced_ai_chat, ai_reset_session, ai_session_status
from .test_cityfix import test_cityfix_llm
from .ml_voice_api_views import (
    ml_voice_process, ml_voice_emotion_detect, ml_voice_resolve_date,
    ml_voice_session_summary, ml_voice_reset_session, ml_voice_generate_response,
    ml_voice_intake_analyze,
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
    
    # AI Assistant (Enhanced Step-by-Step)
    path('ai/chat/', enhanced_ai_chat, name='api_enhanced_ai_chat'),
    path('ai/chat/legacy/', ai_chat, name='api_ai_chat_legacy'),  # Keep old endpoint for compatibility
    path('ai/session/reset/', ai_reset_session, name='api_ai_reset_session'),
    path('ai/session/status/', ai_session_status, name='api_ai_session_status'),
    path('ai/nudge/', ai_nudge, name='api_ai_nudge'),
    path('ai/extract-complaint/', ai_extract_complaint, name='api_ai_extract'),
    path('ai/voice-chat/', ai_voice_chat, name='api_ai_voice_chat'),
    path('ai/history/', ai_history, name='api_ai_history'),
    path('ai/reset/', ai_reset, name='api_ai_reset'),
    path('ai/check-duplicate/', ai_check_duplicate, name='api_ai_check_duplicate'),
    path('ai/gemini-status/', ai_gemini_status, name='api_ai_gemini_status'),
    path('ai/get-department/', ai_get_department, name='api_ai_get_department'),
    
    # ML Voice Assistant (Advanced)
    path('ml-voice/process/', ml_voice_process, name='ml_voice_process'),
    path('ml-voice/intake-analyze/', ml_voice_intake_analyze, name='ml_voice_intake_analyze'),
    path('ml-voice/emotion/', ml_voice_emotion_detect, name='ml_voice_emotion'),
    path('ml-voice/resolve-date/', ml_voice_resolve_date, name='ml_voice_date'),
    path('ml-voice/session/<str:session_id>/', ml_voice_session_summary, name='ml_voice_session'),
    path('ml-voice/session/<str:session_id>/reset/', ml_voice_reset_session, name='ml_voice_reset'),
    path('ml-voice/generate-response/', ml_voice_generate_response, name='ml_voice_generate'),
    
    # Cloudinary
    path('cloudinary/signature/', get_cloudinary_signature, name='api_cloudinary_signature'),
    
    # Test CityFix LLM
    path('test/cityfix-llm/', test_cityfix_llm, name='test_cityfix_llm'),
    
    # Router URLs
    path('', include(router.urls)),
]
