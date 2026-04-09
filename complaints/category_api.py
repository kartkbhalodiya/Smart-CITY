"""
API endpoint to display all categories and subcategories
"""
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from complaints.models import ComplaintCategory


@api_view(['GET'])
@permission_classes([AllowAny])
def get_all_categories_subcategories(request):
    """
    Get all active categories with their subcategories
    
    GET /api/categories/all-with-subcategories/
    
    Returns: {
        "success": true,
        "total_categories": 12,
        "categories": [
            {
                "key": "police",
                "name": "Police Complaint",
                "subcategory_count": 12,
                "subcategories": ["Theft / Robbery", "Cyber Crime", ...]
            },
            ...
        ]
    }
    """
    try:
        categories = ComplaintCategory.objects.filter(is_active=True).prefetch_related('subcategories')
        
        result = []
        for category in categories:
            subcategories = category.subcategories.filter(is_active=True).order_by('display_order', 'name')
            result.append({
                'key': category.key,
                'name': category.name,
                'emoji': category.emoji,
                'subcategory_count': subcategories.count(),
                'subcategories': [sub.name for sub in subcategories]
            })
        
        return Response({
            'success': True,
            'total_categories': len(result),
            'categories': result
        })
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)
