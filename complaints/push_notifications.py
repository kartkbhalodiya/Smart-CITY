from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from datetime import timedelta
import json
import requests
import logging

logger = logging.getLogger(__name__)

class PushNotificationService:
    """Web Push Notification Service for Smart City"""
    
    def __init__(self):
        self.vapid_public_key = getattr(settings, 'VAPID_PUBLIC_KEY', '')
        self.vapid_private_key = getattr(settings, 'VAPID_PRIVATE_KEY', '')
        self.vapid_email = getattr(settings, 'VAPID_EMAIL', 'admin@smartcity.com')
    
    def send_push_notification(self, subscription_info, title, body, data=None, badge=None):
        """Send push notification to a specific subscription"""
        try:
            from pywebpush import webpush, WebPushException
            
            payload = {
                'title': title,
                'body': body,
                'icon': '/static/icons/notification-icon.png',
                'badge': badge or '/static/icons/badge-icon.png',
                'data': data or {},
                'actions': [
                    {'action': 'view', 'title': 'View Details'},
                    {'action': 'dismiss', 'title': 'Dismiss'}
                ]
            }
            
            webpush(
                subscription_info=subscription_info,
                data=json.dumps(payload),
                vapid_private_key=self.vapid_private_key,
                vapid_claims={
                    "sub": f"mailto:{self.vapid_email}"
                }
            )
            return True
            
        except WebPushException as e:
            logger.error(f"Push notification failed: {e}")
            return False
        except Exception as e:
            logger.error(f"Push notification error: {e}")
            return False
    
    def send_complaint_status_update(self, user, complaint, status):
        """Send notification when complaint status changes"""
        subscriptions = self.get_user_subscriptions(user)
        
        title_map = {
            'confirmed': f"Complaint #{complaint.complaint_number} Confirmed ✅",
            'process': f"Work Started on #{complaint.complaint_number} 🔧",
            'solved': f"Complaint #{complaint.complaint_number} Resolved ✅",
            'rejected': f"Complaint #{complaint.complaint_number} Rejected ❌"
        }
        
        body_map = {
            'confirmed': f"Your {complaint.get_complaint_type_display()} complaint has been confirmed by the department.",
            'process': f"Department has started working on your {complaint.get_complaint_type_display()} complaint.",
            'solved': f"Your {complaint.get_complaint_type_display()} complaint has been successfully resolved.",
            'rejected': f"Your {complaint.get_complaint_type_display()} complaint was rejected. Check details for more info."
        }
        
        for subscription in subscriptions:
            self.send_push_notification(
                subscription,
                title_map.get(status, f"Complaint #{complaint.complaint_number} Updated"),
                body_map.get(status, "Your complaint status has been updated."),
                data={'complaint_id': complaint.id, 'type': 'status_update'}
            )
    
    def send_ai_reminder(self, user, reminder_type, data=None):
        """Send AI-powered reminder notifications"""
        subscriptions = self.get_user_subscriptions(user)
        
        if reminder_type == 'incomplete_complaint':
            title = "Complete Your Complaint 📝"
            body = f"You have an incomplete {data.get('category', 'complaint')} that needs attention."
        elif reminder_type == 'follow_up':
            title = "Follow Up Required 📞"
            body = f"Your complaint #{data.get('complaint_number')} may need follow-up action."
        elif reminder_type == 'feedback_request':
            title = "Rate Our Service ⭐"
            body = f"How was our service for complaint #{data.get('complaint_number')}?"
        else:
            title = "Smart City Update 🏙️"
            body = "You have a new update from Smart City services."
        
        for subscription in subscriptions:
            self.send_push_notification(
                subscription,
                title,
                body,
                data={'type': reminder_type, 'data': data or {}}
            )
    
    def send_department_notification(self, department_users, complaint, notification_type):
        """Send notifications to department users"""
        title_map = {
            'new_complaint': f"New {complaint.get_complaint_type_display()} Complaint",
            'urgent_complaint': f"🚨 URGENT: {complaint.get_complaint_type_display()}",
            'overdue_complaint': f"⏰ Overdue: #{complaint.complaint_number}"
        }
        
        body_map = {
            'new_complaint': f"New complaint #{complaint.complaint_number} assigned to your department.",
            'urgent_complaint': f"High priority complaint #{complaint.complaint_number} requires immediate attention.",
            'overdue_complaint': f"Complaint #{complaint.complaint_number} is overdue and needs action."
        }
        
        for user in department_users:
            subscriptions = self.get_user_subscriptions(user)
            for subscription in subscriptions:
                self.send_push_notification(
                    subscription,
                    title_map.get(notification_type, "Department Update"),
                    body_map.get(notification_type, "You have a new department update."),
                    data={'complaint_id': complaint.id, 'type': notification_type}
                )
    
    def get_user_subscriptions(self, user):
        """Get all push subscriptions for a user"""
        cache_key = f"push_subscriptions_{user.id}"
        subscriptions = cache.get(cache_key, [])
        return subscriptions
    
    def save_user_subscription(self, user, subscription_info):
        """Save user's push subscription"""
        cache_key = f"push_subscriptions_{user.id}"
        subscriptions = cache.get(cache_key, [])
        
        # Remove existing subscription with same endpoint
        subscriptions = [s for s in subscriptions if s.get('endpoint') != subscription_info.get('endpoint')]
        subscriptions.append(subscription_info)
        
        cache.set(cache_key, subscriptions, timeout=86400 * 30)  # 30 days
        return True
    
    def remove_user_subscription(self, user, endpoint):
        """Remove user's push subscription"""
        cache_key = f"push_subscriptions_{user.id}"
        subscriptions = cache.get(cache_key, [])
        subscriptions = [s for s in subscriptions if s.get('endpoint') != endpoint]
        cache.set(cache_key, subscriptions, timeout=86400 * 30)
        return True

# Global instance
push_service = PushNotificationService()