"""
URL configuration for smartcity project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path, include
from django.shortcuts import redirect
from django.conf import settings
from django.conf.urls.static import static

def admin_dashboard_redirect(request):
    if not request.user.is_authenticated:
        return redirect('login')
    
    if request.user.is_superuser:
        return redirect('super_admin_dashboard')
    
    # Check if city admin
    from complaints.models import CityAdmin
    if CityAdmin.objects.filter(user=request.user, is_active=True).exists():
        return redirect('city_admin_dashboard')
        
    return admin.site.index(request)

urlpatterns = [
    path("admin/", admin_dashboard_redirect, name="admin_dashboard_redirect"),
    path("admin/", admin.site.urls),
    path("", include('complaints.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
