from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from complaints.models import Complaint
from complaints.push_notifications import push_service
from complaints.conversational_ai import SmartCityAI
import logging

logger = logging.getLogger(__name__)

class AIReminderSystem:
    """AI-powered reminder system for Smart City complaints"""
    
    def __init__(self):
        self.reminder_intervals = {
            'incomplete_complaint': timedelta(hours=2),
            'pending_feedback': timedelta(days=1),
            'follow_up_required': timedelta(days=3),
            'overdue_complaint': timedelta(hours=6)
        }
    
    def trigger_incomplete_complaint_reminders(self):
        """Send reminders for incomplete AI chat sessions"""
        cutoff_time = timezone.now() - self.reminder_intervals['incomplete_complaint']
        
        # Get users with incomplete AI sessions
        incomplete_sessions = self._get_incomplete_ai_sessions(cutoff_time)
        
        for session_id, user_data in incomplete_sessions.items():
            try:
                ai = SmartCityAI.for_session(session_id)
                complaint_info = ai.extract_complaint_info()
                
                if self._should_send_reminder(complaint_info):
                    nudge = ai.generate_reengagement_nudge()
                    
                    # Send push notification
                    user = User.objects.filter(email=user_data.get('email')).first()
                    if user:
                        push_service.send_ai_reminder(
                            user, 
                            'incomplete_complaint',
                            {
                                'category': complaint_info.get('category'),
                                'session_id': session_id,
                                'title': nudge.get('title'),
                                'body': nudge.get('body')
                            }
                        )
                        logger.info(f"Sent incomplete complaint reminder to {user.email}")
                
            except Exception as e:
                logger.error(f"Error sending reminder for session {session_id}: {e}")
    
    def trigger_dashboard_reminders(self):
        """Trigger reminders from dashboard analytics"""
        # Overdue complaints
        overdue_complaints = Complaint.objects.filter(
            work_status__in=['pending', 'confirmed', 'process'],
            created_at__lt=timezone.now() - timedelta(days=7)
        ).select_related('user', 'assigned_department')
        
        for complaint in overdue_complaints:
            if complaint.user:
                push_service.send_ai_reminder(
                    complaint.user,
                    'follow_up',
                    {
                        'complaint_number': complaint.complaint_number,
                        'category': complaint.get_complaint_type_display(),
                        'days_pending': (timezone.now() - complaint.created_at).days
                    }
                )
        
        # Feedback requests for resolved complaints
        resolved_complaints = Complaint.objects.filter(
            work_status='solved',
            citizen_rating__isnull=True,
            resolved_at__lt=timezone.now() - timedelta(hours=24),
            resolved_at__gt=timezone.now() - timedelta(days=7)
        ).select_related('user')
        
        for complaint in resolved_complaints:
            if complaint.user:
                push_service.send_ai_reminder(
                    complaint.user,
                    'feedback_request',
                    {
                        'complaint_number': complaint.complaint_number,
                        'category': complaint.get_complaint_type_display()
                    }
                )
    
    def trigger_department_reminders(self):
        """Send reminders to department users"""
        from complaints.models import DepartmentUser
        
        # New complaints not acknowledged
        new_complaints = Complaint.objects.filter(
            work_status='pending',
            created_at__gt=timezone.now() - timedelta(hours=2),
            assigned_department__isnull=False
        ).select_related('assigned_department')
        
        for complaint in new_complaints:
            dept_users = User.objects.filter(
                departmentuser__department=complaint.assigned_department
            )
            
            notification_type = 'urgent_complaint' if complaint.priority == 'high' else 'new_complaint'
            push_service.send_department_notification(dept_users, complaint, notification_type)
        
        # Overdue complaints
        overdue_complaints = Complaint.objects.filter(
            work_status__in=['confirmed', 'process'],
            assigned_department__isnull=False
        )
        
        for complaint in overdue_complaints:
            if complaint.is_overdue:
                dept_users = User.objects.filter(
                    departmentuser__department=complaint.assigned_department
                )
                push_service.send_department_notification(dept_users, complaint, 'overdue_complaint')
    
    def trigger_smart_reminders(self, trigger_type='all'):
        """Main method to trigger all types of reminders"""
        try:
            if trigger_type in ['all', 'incomplete']:
                self.trigger_incomplete_complaint_reminders()
            
            if trigger_type in ['all', 'dashboard']:
                self.trigger_dashboard_reminders()
            
            if trigger_type in ['all', 'department']:
                self.trigger_department_reminders()
                
            logger.info(f"AI reminders triggered successfully: {trigger_type}")
            
        except Exception as e:
            logger.error(f"Error triggering AI reminders: {e}")
    
    def _get_incomplete_ai_sessions(self, cutoff_time):
        """Get AI sessions that are incomplete and need reminders"""
        # This would typically query a session store or cache
        # For now, we'll use a simplified approach
        from django.core.cache import cache
        
        incomplete_sessions = {}
        # In a real implementation, you'd iterate through active sessions
        # and check their completion status
        
        return incomplete_sessions
    
    def _should_send_reminder(self, complaint_info):
        """Determine if a reminder should be sent based on complaint info"""
        missing_fields = complaint_info.get('missing_fields', [])
        
        # Send reminder if critical fields are missing
        critical_fields = ['category', 'location', 'description']
        has_critical_missing = any(field in str(missing_fields) for field in critical_fields)
        
        # Don't spam - check if we sent a reminder recently
        last_reminder = complaint_info.get('last_reminder_sent')
        if last_reminder:
            # Implement cooldown logic here
            pass
        
        return has_critical_missing

# Management Command
class Command(BaseCommand):
    help = 'Trigger AI reminders for Smart City complaints'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--type',
            type=str,
            default='all',
            choices=['all', 'incomplete', 'dashboard', 'department'],
            help='Type of reminders to trigger'
        )
    
    def handle(self, *args, **options):
        reminder_system = AIReminderSystem()
        reminder_system.trigger_smart_reminders(options['type'])
        self.stdout.write(
            self.style.SUCCESS(f'Successfully triggered {options["type"]} reminders')
        )

# Global instance
ai_reminder_system = AIReminderSystem()