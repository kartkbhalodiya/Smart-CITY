import os
import logging
from threading import Thread
from django.conf import settings

logger = logging.getLogger(__name__)

def send_sms(phone_number, message):
    """
    Send SMS notification to a phone number.
    Runs in a background thread to avoid blocking.
    """
    if not phone_number:
        return
    
    # Clean phone number - basic normalization
    phone_number = str(phone_number).strip()
    if not phone_number:
        return

    # Start background thread
    Thread(target=_send_sms_task, args=(phone_number, message), daemon=True).start()

def _send_sms_task(phone_number, message):
    """Actual task to send SMS based on configured backend."""
    backend = getattr(settings, 'SMS_BACKEND', 'console')
    
    try:
        if backend == 'console':
            print("\n" + "="*30)
            print(f"SMS SENT TO: {phone_number}")
            print(f"MESSAGE: {message}")
            print("="*30 + "\n")
            
        elif backend == 'twilio':
            try:
                from twilio.rest import Client
                
                account_sid = getattr(settings, 'TWILIO_ACCOUNT_SID', '')
                auth_token = getattr(settings, 'TWILIO_AUTH_TOKEN', '')
                from_number = getattr(settings, 'TWILIO_FROM_NUMBER', '')
                
                if all([account_sid, auth_token, from_number]):
                    client = Client(account_sid, auth_token)
                    client.messages.create(
                        body=message,
                        from_=from_number,
                        to=phone_number
                    )
                else:
                    logger.error("Twilio configuration missing")
            except ImportError:
                logger.error("twilio library not installed")
            except Exception as e:
                logger.error(f"Twilio error: {str(e)}")
        
        else:
            logger.warning(f"Unsupported SMS backend: {backend}")
            
    except Exception as e:
        logger.error(f"Error in _send_sms_task: {str(e)}")
