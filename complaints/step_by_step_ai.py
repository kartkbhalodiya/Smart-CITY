"""
Enhanced Step-by-Step Conversational AI for Smart City Complaints
Provides guided conversation flow with proper state management
"""
import re
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from django.core.cache import cache
from django.utils import timezone

class ConversationStep:
    """Represents a step in the conversation flow"""
    GREETING = "greeting"
    PROBLEM_IDENTIFICATION = "problem_identification"
    CATEGORY_CONFIRMATION = "category_confirmation"
    SUBCATEGORY_SELECTION = "subcategory_selection"
    DETAIL_COLLECTION = "detail_collection"
    LOCATION_REQUEST = "location_request"
    LOCATION_CONFIRMATION = "location_confirmation"
    PHOTO_REQUEST = "photo_request"
    FINAL_REVIEW = "final_review"
    SUBMISSION = "submission"
    COMPLETED = "completed"

class ConversationState:
    """Manages conversation state and data"""
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.current_step = ConversationStep.GREETING
        self.user_data = {
            'name': None,
            'language': 'english',
            'problem_description': None,
            'category': None,
            'subcategory': None,
            'location': None,
            'latitude': None,
            'longitude': None,
            'photos': [],
            'urgency': 'medium',
            'additional_details': None
        }
        self.conversation_history = []
        self.created_at = timezone.now()
        self.updated_at = timezone.now()
    
    def to_dict(self) -> Dict:
        return {
            'session_id': self.session_id,
            'current_step': self.current_step,
            'user_data': self.user_data,
            'conversation_history': self.conversation_history,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
    
    @classmethod
    def from_dict(cls, data: Dict) -> 'ConversationState':
        state = cls(data['session_id'])
        state.current_step = data.get('current_step', ConversationStep.GREETING)
        state.user_data = data.get('user_data', {})
        state.conversation_history = data.get('conversation_history', [])
        state.created_at = datetime.fromisoformat(data.get('created_at', timezone.now().isoformat()))
        state.updated_at = datetime.fromisoformat(data.get('updated_at', timezone.now().isoformat()))
        return state

class StepByStepAI:
    """Enhanced AI with step-by-step conversation flow"""
    
    def __init__(self):
        self.category_keywords = {
            'Electricity': {
                'keywords': ['bijli', 'light', 'power', 'electricity', 'current', 'wire', 'transformer', 'pole', 'street light'],
                'hindi_keywords': ['बिजली', 'लाइट', 'करंट', 'तार', 'खंभा'],
                'subcategories': {
                    'Power Outage': ['no power', 'power cut', 'bijli nahi', 'light nahi', 'blackout'],
                    'Street Light Issue': ['street light', 'pole light', 'road light', 'गली की लाइट'],
                    'Exposed Wires': ['open wire', 'hanging wire', 'dangerous wire', 'खुला तार'],
                    'Transformer Problem': ['transformer', 'blast', 'noise', 'ट्रांसफार्मर']
                }
            },
            'Road/Pothole': {
                'keywords': ['road', 'sadak', 'pothole', 'gadda', 'hole', 'crack', 'broken road'],
                'hindi_keywords': ['सड़क', 'रास्ता', 'गड्ढा', 'टूटी सड़क'],
                'subcategories': {
                    'Pothole': ['pothole', 'hole', 'gadda', 'गड्ढा', 'crater'],
                    'Broken Road': ['broken road', 'cracked road', 'damaged road', 'टूटी सड़क'],
                    'Waterlogging': ['water logging', 'flood', 'pani jama', 'पानी जमा'],
                    'Road Blockage': ['blocked road', 'obstruction', 'रास्ता बंद']
                }
            },
            'Water Supply': {
                'keywords': ['water', 'pani', 'tap', 'pipeline', 'leak', 'pressure'],
                'hindi_keywords': ['पानी', 'नल', 'पाइप', 'लीक'],
                'subcategories': {
                    'No Water Supply': ['no water', 'pani nahi', 'dry tap', 'पानी नहीं'],
                    'Low Pressure': ['low pressure', 'weak flow', 'कम दबाव'],
                    'Water Leakage': ['leak', 'pipe burst', 'लीक', 'पाइप फटा'],
                    'Dirty Water': ['dirty water', 'contaminated', 'गंदा पानी']
                }
            },
            'Garbage/Sanitation': {
                'keywords': ['garbage', 'kachra', 'waste', 'dustbin', 'dirty', 'smell'],
                'hindi_keywords': ['कचरा', 'कूड़ा', 'गंदगी', 'बदबू'],
                'subcategories': {
                    'Garbage Not Collected': ['not collected', 'garbage pending', 'कचरा नहीं उठा'],
                    'Overflowing Dustbin': ['dustbin full', 'overflow', 'डस्टबिन भरा'],
                    'Illegal Dumping': ['illegal dumping', 'waste dumping', 'गलत जगह कचरा'],
                    'Bad Smell': ['smell', 'stink', 'odor', 'बदबू']
                }
            },
            'Drainage/Sewage': {
                'keywords': ['drain', 'nali', 'sewer', 'gutter', 'overflow', 'block'],
                'hindi_keywords': ['नाली', 'गटर', 'सीवर', 'बंद'],
                'subcategories': {
                    'Blocked Drain': ['blocked drain', 'nali jam', 'नाली बंद'],
                    'Drain Overflow': ['overflow', 'गटर भरा', 'drain full'],
                    'Open Manhole': ['open manhole', 'manhole cover', 'मैनहोल खुला'],
                    'Sewage Leak': ['sewage leak', 'गंदा पानी लीक']
                }
            },
            'Traffic': {
                'keywords': ['traffic', 'signal', 'parking', 'accident', 'vehicle'],
                'hindi_keywords': ['ट्रैफिक', 'सिग्नल', 'पार्किंग', 'गाड़ी'],
                'subcategories': {
                    'Traffic Signal Issue': ['signal not working', 'broken signal', 'सिग्नल खराब'],
                    'Illegal Parking': ['wrong parking', 'illegal parking', 'गलत पार्किंग'],
                    'Traffic Jam': ['traffic jam', 'congestion', 'ट्रैफिक जाम'],
                    'Rash Driving': ['rash driving', 'overspeeding', 'तेज़ ड्राइविंग']
                }
            },
            'Police': {
                'keywords': ['police', 'crime', 'theft', 'robbery', 'fight', 'violence'],
                'hindi_keywords': ['पुलिस', 'चोरी', 'लूट', 'मारपीट'],
                'subcategories': {
                    'Theft/Robbery': ['theft', 'robbery', 'stolen', 'चोरी', 'लूट'],
                    'Violence/Fight': ['fight', 'violence', 'assault', 'मारपीट'],
                    'Suspicious Activity': ['suspicious', 'शक्की व्यक्ति'],
                    'Noise Disturbance': ['loud music', 'noise', 'शोर']
                }
            }
        }
    
    def get_conversation_state(self, session_id: str) -> ConversationState:
        """Get or create conversation state"""
        cache_key = f"conversation_state_{session_id}"
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return ConversationState.from_dict(cached_data)
        else:
            return ConversationState(session_id)
    
    def save_conversation_state(self, state: ConversationState):
        """Save conversation state to cache"""
        state.updated_at = timezone.now()
        cache_key = f"conversation_state_{state.session_id}"
        cache.set(cache_key, state.to_dict(), timeout=3600)  # 1 hour
    
    def process_message(self, session_id: str, message: str, user_name: str = None, 
                       preferred_language: str = 'english') -> Dict[str, Any]:
        """Process user message and return appropriate response"""
        state = self.get_conversation_state(session_id)
        
        # Update user info
        if user_name:
            state.user_data['name'] = user_name
        state.user_data['language'] = preferred_language
        
        # Add message to history
        state.conversation_history.append({
            'role': 'user',
            'message': message,
            'timestamp': timezone.now().isoformat()
        })
        
        # Process based on current step
        response = self._process_step(state, message)
        
        # Add response to history
        state.conversation_history.append({
            'role': 'assistant',
            'message': response['response'],
            'timestamp': timezone.now().isoformat(),
            'step': state.current_step,
            'data': response.get('data', {})
        })
        
        # Save state
        self.save_conversation_state(state)
        
        return response
    
    def _process_step(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Process message based on current conversation step"""
        
        if state.current_step == ConversationStep.GREETING:
            return self._handle_greeting(state, message)
        
        elif state.current_step == ConversationStep.PROBLEM_IDENTIFICATION:
            return self._handle_problem_identification(state, message)
        
        elif state.current_step == ConversationStep.CATEGORY_CONFIRMATION:
            return self._handle_category_confirmation(state, message)
        
        elif state.current_step == ConversationStep.SUBCATEGORY_SELECTION:
            return self._handle_subcategory_selection(state, message)
        
        elif state.current_step == ConversationStep.DETAIL_COLLECTION:
            return self._handle_detail_collection(state, message)
        
        elif state.current_step == ConversationStep.LOCATION_REQUEST:
            return self._handle_location_request(state, message)
        
        elif state.current_step == ConversationStep.LOCATION_CONFIRMATION:
            return self._handle_location_confirmation(state, message)
        
        elif state.current_step == ConversationStep.PHOTO_REQUEST:
            return self._handle_photo_request(state, message)
        
        elif state.current_step == ConversationStep.FINAL_REVIEW:
            return self._handle_final_review(state, message)
        
        else:
            return self._handle_default(state, message)
    
    def _handle_greeting(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle initial greeting and introduction"""
        user_name = state.user_data.get('name', 'Friend')
        language = state.user_data.get('language', 'english')
        
        # Move to next step
        state.current_step = ConversationStep.PROBLEM_IDENTIFICATION
        
        if language == 'hindi':
            response = f"🙏 नमस्ते {user_name}! मैं आपका JanHelp AI असिस्टेंट हूं। 😊\n\n" \
                      f"मैं आपकी शिकायत दर्ज करने में मदद करूंगा। आइए शुरू करते हैं!\n\n" \
                      f"🤔 **कृपया बताएं कि आपकी क्या समस्या है?**\n\n" \
                      f"उदाहरण:\n" \
                      f"• \"बिजली नहीं आ रही है\"\n" \
                      f"• \"सड़क में गड्ढा है\"\n" \
                      f"• \"कचरा नहीं उठाया गया\""
        else:
            response = f"👋 Hello {user_name}! I'm your JanHelp AI Assistant! 😊\n\n" \
                      f"I'll help you file your complaint step by step. Let's get started!\n\n" \
                      f"🤔 **What problem would you like to report?**\n\n" \
                      f"Examples:\n" \
                      f"• \"No electricity in my area\"\n" \
                      f"• \"There's a pothole on the road\"\n" \
                      f"• \"Garbage not collected\""
        
        return {
            'response': response,
            'step': state.current_step,
            'next_action': 'describe_problem',
            'show_examples': True,
            'data': {
                'examples': [
                    "No electricity", "Road problem", "Water issue", 
                    "Garbage not collected", "Drain blocked"
                ]
            }
        }
    
    def _handle_problem_identification(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Identify problem category from user description"""
        language = state.user_data.get('language', 'english')
        
        # Store problem description
        state.user_data['problem_description'] = message
        
        # Detect category
        detected_category, confidence = self._detect_category(message)
        
        if confidence > 0.7 and detected_category:
            # High confidence - confirm category
            state.user_data['category'] = detected_category
            state.current_step = ConversationStep.CATEGORY_CONFIRMATION
            
            category_emoji = self._get_category_emoji(detected_category)
            
            if language == 'hindi':
                response = f"✅ समझ गया! आपकी समस्या **{detected_category}** से संबंधित है। {category_emoji}\n\n" \
                          f"📝 आपने कहा: \"{message}\"\n\n" \
                          f"❓ **क्या यह सही है?**\n\n" \
                          f"👍 हां, सही है\n" \
                          f"👎 नहीं, कुछ और है"
            else:
                response = f"✅ Got it! Your problem is related to **{detected_category}**. {category_emoji}\n\n" \
                          f"📝 You said: \"{message}\"\n\n" \
                          f"❓ **Is this correct?**\n\n" \
                          f"👍 Yes, that's right\n" \
                          f"👎 No, it's something else"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'confirm_category',
                'show_confirmation': True,
                'data': {
                    'detected_category': detected_category,
                    'confidence': confidence,
                    'buttons': ['Yes', 'No']
                }
            }
        
        else:
            # Low confidence - ask for clarification
            if language == 'hindi':
                response = f"🤔 मुझे आपकी समस्या पूरी तरह समझ नहीं आई।\n\n" \
                          f"📝 आपने कहा: \"{message}\"\n\n" \
                          f"🔍 **कृपया इनमें से कौन सा सबसे करीब है?**\n\n"
            else:
                response = f"🤔 I need a bit more clarity about your problem.\n\n" \
                          f"📝 You said: \"{message}\"\n\n" \
                          f"🔍 **Which category is closest to your issue?**\n\n"
            
            # Show category options
            categories = list(self.category_keywords.keys())
            for i, category in enumerate(categories, 1):
                emoji = self._get_category_emoji(category)
                response += f"{i}. {emoji} {category}\n"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'select_category',
                'show_categories': True,
                'data': {
                    'categories': categories,
                    'detected_category': detected_category,
                    'confidence': confidence
                }
            }
    
    def _handle_category_confirmation(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle category confirmation"""
        language = state.user_data.get('language', 'english')
        message_lower = message.lower()
        
        if any(word in message_lower for word in ['yes', 'हां', 'सही', 'correct', 'right']):
            # Category confirmed - move to subcategory
            category = state.user_data['category']
            state.current_step = ConversationStep.SUBCATEGORY_SELECTION
            
            subcategories = list(self.category_keywords[category]['subcategories'].keys())
            category_emoji = self._get_category_emoji(category)
            
            if language == 'hindi':
                response = f"👍 बहुत बढ़िया! {category_emoji}\n\n" \
                          f"🎯 **अब बताएं कि {category} में कौन सी समस्या है?**\n\n"
            else:
                response = f"👍 Perfect! {category_emoji}\n\n" \
                          f"🎯 **What specific {category} issue are you facing?**\n\n"
            
            for i, subcat in enumerate(subcategories, 1):
                response += f"{i}. {subcat}\n"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'select_subcategory',
                'show_subcategories': True,
                'data': {
                    'category': category,
                    'subcategories': subcategories
                }
            }
        
        else:
            # Category not confirmed - go back to identification
            state.current_step = ConversationStep.PROBLEM_IDENTIFICATION
            
            if language == 'hindi':
                response = f"👌 कोई बात नहीं!\n\n" \
                          f"🔍 **कृपया अपनी समस्या को और विस्तार से बताएं:**\n\n" \
                          f"जैसे:\n" \
                          f"• कहां है समस्या?\n" \
                          f"• कब से है?\n" \
                          f"• कैसी दिखती है?"
            else:
                response = f"👌 No problem!\n\n" \
                          f"🔍 **Please describe your problem in more detail:**\n\n" \
                          f"Such as:\n" \
                          f"• Where is the problem?\n" \
                          f"• Since when?\n" \
                          f"• What does it look like?"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'describe_problem_detailed'
            }
    
    def _detect_category(self, message: str) -> Tuple[Optional[str], float]:
        """Detect category from message with confidence score"""
        message_lower = message.lower()
        scores = {}
        
        for category, data in self.category_keywords.items():
            score = 0
            
            # Check English keywords
            for keyword in data['keywords']:
                if keyword.lower() in message_lower:
                    score += 2
            
            # Check Hindi keywords
            for keyword in data.get('hindi_keywords', []):
                if keyword in message:
                    score += 2
            
            # Check subcategory keywords
            for subcat, keywords in data['subcategories'].items():
                for keyword in keywords:
                    if keyword.lower() in message_lower:
                        score += 3
            
            if score > 0:
                scores[category] = score
        
        if not scores:
            return None, 0.0
        
        best_category = max(scores, key=scores.get)
        max_score = scores[best_category]
        confidence = min(1.0, max_score / 5.0)  # Normalize to 0-1
        
        return best_category, confidence
    
    def _get_category_emoji(self, category: str) -> str:
        """Get emoji for category"""
        emoji_map = {
            'Electricity': '⚡',
            'Road/Pothole': '🛣️',
            'Water Supply': '💧',
            'Garbage/Sanitation': '🗑️',
            'Drainage/Sewage': '🚰',
            'Traffic': '🚦',
            'Police': '👮‍♂️'
        }
        return emoji_map.get(category, '📝')
    
    def _handle_subcategory_selection(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle subcategory selection"""
        language = state.user_data.get('language', 'english')
        category = state.user_data['category']
        subcategories = list(self.category_keywords[category]['subcategories'].keys())
        
        # Try to match subcategory from message
        selected_subcategory = None
        message_lower = message.lower()
        
        # Check if user selected by number
        if message.strip().isdigit():
            index = int(message.strip()) - 1
            if 0 <= index < len(subcategories):
                selected_subcategory = subcategories[index]
        
        # Check if user mentioned subcategory by name
        if not selected_subcategory:
            for subcat in subcategories:
                if subcat.lower() in message_lower:
                    selected_subcategory = subcat
                    break
        
        # Check subcategory keywords
        if not selected_subcategory:
            for subcat, keywords in self.category_keywords[category]['subcategories'].items():
                for keyword in keywords:
                    if keyword.lower() in message_lower:
                        selected_subcategory = subcat
                        break
                if selected_subcategory:
                    break
        
        if selected_subcategory:
            state.user_data['subcategory'] = selected_subcategory
            state.current_step = ConversationStep.DETAIL_COLLECTION
            
            if language == 'hindi':
                response = f"✅ बहुत बढ़िया! आपकी समस्या: **{selected_subcategory}** 🎯\n\n" \
                          f"📋 **अब कुछ और जानकारी दें:**\n\n" \
                          f"• यह समस्या कब से है?\n" \
                          f"• कितनी गंभीर है?\n" \
                          f"• कोई और विशेष बात?\n\n" \
                          f"💬 **विस्तार से बताएं:**"
            else:
                response = f"✅ Perfect! Your issue: **{selected_subcategory}** 🎯\n\n" \
                          f"📋 **Now tell me more details:**\n\n" \
                          f"• How long has this been a problem?\n" \
                          f"• How severe is it?\n" \
                          f"• Any other important details?\n\n" \
                          f"💬 **Please elaborate:**"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'provide_details',
                'data': {
                    'subcategory': selected_subcategory,
                    'category': category
                }
            }
        
        else:
            # Subcategory not recognized
            if language == 'hindi':
                response = f"🤔 मुझे समझ नहीं आया।\n\n" \
                          f"🔢 **कृपया नंबर चुनें (1-{len(subcategories)}):**\n\n"
            else:
                response = f"🤔 I didn't understand that.\n\n" \
                          f"🔢 **Please select a number (1-{len(subcategories)}):**\n\n"
            
            for i, subcat in enumerate(subcategories, 1):
                response += f"{i}. {subcat}\n"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'select_subcategory',
                'show_subcategories': True,
                'data': {
                    'subcategories': subcategories
                }
            }
    
    def _handle_detail_collection(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle additional detail collection"""
        language = state.user_data.get('language', 'english')
        
        # Store additional details
        state.user_data['additional_details'] = message
        
        # Detect urgency from message
        urgency = self._detect_urgency(message)
        state.user_data['urgency'] = urgency
        
        # Move to location request
        state.current_step = ConversationStep.LOCATION_REQUEST
        
        urgency_emoji = {'low': '🟢', 'medium': '🟡', 'high': '🔴', 'critical': '🚨'}[urgency]
        
        if language == 'hindi':
            response = f"📝 जानकारी मिल गई! धन्यवाद।\n\n" \
                      f"{urgency_emoji} **तात्कालिकता:** {urgency.upper()}\n\n" \
                      f"📍 **अब मुझे सटीक स्थान बताएं:**\n\n" \
                      f"🗺️ आप नक्शे पर स्थान चुन सकते हैं या टाइप कर सकते हैं:\n\n" \
                      f"• पूरा पता\n" \
                      f"• नजदीकी लैंडमार्क\n" \
                      f"• गली/मोहल्ले का नाम\n\n" \
                      f"🎯 **स्थान बताएं या 'MAP' लिखें:**"
        else:
            response = f"📝 Got the details! Thank you.\n\n" \
                      f"{urgency_emoji} **Urgency Level:** {urgency.upper()}\n\n" \
                      f"📍 **Now I need the exact location:**\n\n" \
                      f"🗺️ You can select on map or type the location:\n\n" \
                      f"• Full address\n" \
                      f"• Nearby landmark\n" \
                      f"• Street/area name\n\n" \
                      f"🎯 **Share location or type 'MAP':**"
        
        return {
            'response': response,
            'step': state.current_step,
            'next_action': 'provide_location',
            'show_map_option': True,
            'data': {
                'urgency': urgency,
                'details': message
            }
        }
    
    def _handle_location_request(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle location request"""
        language = state.user_data.get('language', 'english')
        message_lower = message.lower()
        
        if 'map' in message_lower:
            # User wants to use map
            if language == 'hindi':
                response = f"🗺️ **नक्शा खोला जा रहा है...**\n\n" \
                          f"📍 कृपया नक्शे पर सटीक स्थान पर टैप करें जहां समस्या है।\n\n" \
                          f"✅ स्थान चुनने के बाद 'CONFIRM' दबाएं।"
            else:
                response = f"🗺️ **Opening map...**\n\n" \
                          f"📍 Please tap on the exact location where the problem is.\n\n" \
                          f"✅ After selecting location, press 'CONFIRM'."
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'open_map',
                'show_map': True,
                'data': {
                    'map_instruction': 'select_location'
                }
            }
        
        elif any(coord in message for coord in ['lat', 'lng', 'latitude', 'longitude']) or \
             re.search(r'\d+\.\d+.*\d+\.\d+', message):
            # User provided coordinates
            coords = re.findall(r'\d+\.\d+', message)
            if len(coords) >= 2:
                state.user_data['latitude'] = float(coords[0])
                state.user_data['longitude'] = float(coords[1])
                state.user_data['location'] = f"Coordinates: {coords[0]}, {coords[1]}"
                state.current_step = ConversationStep.LOCATION_CONFIRMATION
                
                if language == 'hindi':
                    response = f"📍 **स्थान मिल गया:**\n\n" \
                              f"🎯 {coords[0]}, {coords[1]}\n\n" \
                              f"❓ **क्या यह सही स्थान है?**\n\n" \
                              f"👍 हां, सही है\n" \
                              f"👎 नहीं, दूसरा स्थान"
                else:
                    response = f"📍 **Location received:**\n\n" \
                              f"🎯 {coords[0]}, {coords[1]}\n\n" \
                              f"❓ **Is this the correct location?**\n\n" \
                              f"👍 Yes, that's right\n" \
                              f"👎 No, different location"
                
                return {
                    'response': response,
                    'step': state.current_step,
                    'next_action': 'confirm_location',
                    'show_confirmation': True,
                    'data': {
                        'latitude': coords[0],
                        'longitude': coords[1],
                        'buttons': ['Yes', 'No']
                    }
                }
        
        else:
            # User provided text location
            state.user_data['location'] = message
            state.current_step = ConversationStep.LOCATION_CONFIRMATION
            
            if language == 'hindi':
                response = f"📍 **स्थान मिल गया:**\n\n" \
                          f"🎯 {message}\n\n" \
                          f"❓ **क्या यह सही स्थान है?**\n\n" \
                          f"👍 हां, सही है\n" \
                          f"👎 नहीं, दूसरा स्थान\n" \
                          f"🗺️ नक्शे पर दिखाएं"
            else:
                response = f"📍 **Location received:**\n\n" \
                          f"🎯 {message}\n\n" \
                          f"❓ **Is this the correct location?**\n\n" \
                          f"👍 Yes, that's right\n" \
                          f"👎 No, different location\n" \
                          f"🗺️ Show on map"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'confirm_location',
                'show_confirmation': True,
                'data': {
                    'location': message,
                    'buttons': ['Yes', 'No', 'Show Map']
                }
            }
    
    def _handle_location_confirmation(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle location confirmation"""
        language = state.user_data.get('language', 'english')
        message_lower = message.lower()
        
        if any(word in message_lower for word in ['yes', 'हां', 'सही', 'correct', 'right']):
            # Location confirmed - move to photo request
            state.current_step = ConversationStep.PHOTO_REQUEST
            
            category = state.user_data['category']
            subcategory = state.user_data['subcategory']
            
            if language == 'hindi':
                response = f"✅ **स्थान कन्फर्म हो गया!** 📍\n\n" \
                          f"📷 **अब फोटो अपलोड करें:**\n\n" \
                          f"🎯 {subcategory} की तस्वीर लें जो समस्या को स्पष्ट रूप से दिखाए।\n\n" \
                          f"💡 **टिप्स:**\n" \
                          f"• साफ और स्पष्ट फोटो\n" \
                          f"• समस्या का क्लोज-अप\n" \
                          f"• अच्छी रोशनी में\n\n" \
                          f"📱 **फोटो अपलोड करें या 'SKIP' लिखें:**"
            else:
                response = f"✅ **Location confirmed!** 📍\n\n" \
                          f"📷 **Now upload a photo:**\n\n" \
                          f"🎯 Take a picture of the {subcategory} that clearly shows the problem.\n\n" \
                          f"💡 **Tips:**\n" \
                          f"• Clear and sharp photo\n" \
                          f"• Close-up of the issue\n" \
                          f"• Good lighting\n\n" \
                          f"📱 **Upload photo or type 'SKIP':**"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'upload_photo',
                'show_camera': True,
                'data': {
                    'category': category,
                    'subcategory': subcategory
                }
            }
        
        elif 'map' in message_lower:
            # User wants to see map
            state.current_step = ConversationStep.LOCATION_REQUEST
            
            if language == 'hindi':
                response = f"🗺️ **नक्शा खोला जा रहा है...**\n\n" \
                          f"📍 सटीक स्थान पर टैप करें।"
            else:
                response = f"🗺️ **Opening map...**\n\n" \
                          f"📍 Tap on the exact location."
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'open_map',
                'show_map': True
            }
        
        else:
            # Location not confirmed - ask again
            if language == 'hindi':
                response = f"👌 कोई बात नहीं!\n\n" \
                          f"📍 **कृपया सही स्थान बताएं:**\n\n" \
                          f"🗺️ या 'MAP' लिखकर नक्शा खोलें।"
            else:
                response = f"👌 No problem!\n\n" \
                          f"📍 **Please provide the correct location:**\n\n" \
                          f"🗺️ Or type 'MAP' to open map."
            
            state.current_step = ConversationStep.LOCATION_REQUEST
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'provide_location'
            }
    
    def _detect_urgency(self, message: str) -> str:
        """Detect urgency level from message"""
        message_lower = message.lower()
        
        critical_words = ['emergency', 'urgent', 'danger', 'fire', 'accident', 'तुरंत', 'आपातकाल']
        high_words = ['serious', 'bad', 'terrible', 'गंभीर', 'बहुत', 'ज्यादा']
        low_words = ['small', 'minor', 'little', 'छोटी', 'कम']
        
        if any(word in message_lower for word in critical_words):
            return 'critical'
        elif any(word in message_lower for word in high_words):
            return 'high'
        elif any(word in message_lower for word in low_words):
            return 'low'
        else:
            return 'medium'
    
    def _handle_photo_request(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle photo upload request"""
        language = state.user_data.get('language', 'english')
        message_lower = message.lower()
        
        if 'skip' in message_lower:
            # User skipped photo - move to final review
            state.current_step = ConversationStep.FINAL_REVIEW
            
            if language == 'hindi':
                response = f"👌 **ठीक है, फोटो के बिना आगे बढ़ते हैं।**\n\n" \
                          f"📋 **आपकी शिकायत का सारांश:**\n\n" \
                          f"🏷️ **कैटेगरी:** {state.user_data['category']}\n" \
                          f"🎯 **समस्या:** {state.user_data['subcategory']}\n" \
                          f"📍 **स्थान:** {state.user_data['location']}\n" \
                          f"📋 **विवरण:** {state.user_data['additional_details']}\n" \
                          f"⚡ **तात्कालिकता:** {state.user_data['urgency'].upper()}\n\n" \
                          f"❓ **क्या सब कुछ सही है?**\n\n" \
                          f"✅ हां, सबमिट करें\n" \
                          f"✏️ कुछ बदलना है"
            else:
                response = f"👌 **Okay, proceeding without photo.**\n\n" \
                          f"📋 **Your Complaint Summary:**\n\n" \
                          f"🏷️ **Category:** {state.user_data['category']}\n" \
                          f"🎯 **Issue:** {state.user_data['subcategory']}\n" \
                          f"📍 **Location:** {state.user_data['location']}\n" \
                          f"📋 **Details:** {state.user_data['additional_details']}\n" \
                          f"⚡ **Urgency:** {state.user_data['urgency'].upper()}\n\n" \
                          f"❓ **Is everything correct?**\n\n" \
                          f"✅ Yes, submit complaint\n" \
                          f"✏️ Need to change something"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'final_review',
                'show_confirmation': True,
                'data': {
                    'summary': state.user_data,
                    'buttons': ['Submit', 'Edit']
                }
            }
        
        elif 'uploaded' in message_lower or 'photo' in message_lower:
            # User uploaded photo
            state.user_data['photos'].append({
                'uploaded_at': timezone.now().isoformat(),
                'description': message
            })
            state.current_step = ConversationStep.FINAL_REVIEW
            
            if language == 'hindi':
                response = f"📷 **फोटो अपलोड हो गया!** ✅\n\n" \
                          f"📋 **आपकी शिकायत का सारांश:**\n\n" \
                          f"🏷️ **कैटेगरी:** {state.user_data['category']}\n" \
                          f"🎯 **समस्या:** {state.user_data['subcategory']}\n" \
                          f"📍 **स्थान:** {state.user_data['location']}\n" \
                          f"📋 **विवरण:** {state.user_data['additional_details']}\n" \
                          f"⚡ **तात्कालिकता:** {state.user_data['urgency'].upper()}\n" \
                          f"📷 **फोटो:** अपलोड किया गया\n\n" \
                          f"❓ **क्या सब कुछ सही है?**\n\n" \
                          f"✅ हां, सबमिट करें\n" \
                          f"✏️ कुछ बदलना है"
            else:
                response = f"📷 **Photo uploaded successfully!** ✅\n\n" \
                          f"📋 **Your Complaint Summary:**\n\n" \
                          f"🏷️ **Category:** {state.user_data['category']}\n" \
                          f"🎯 **Issue:** {state.user_data['subcategory']}\n" \
                          f"📍 **Location:** {state.user_data['location']}\n" \
                          f"📋 **Details:** {state.user_data['additional_details']}\n" \
                          f"⚡ **Urgency:** {state.user_data['urgency'].upper()}\n" \
                          f"📷 **Photo:** Uploaded\n\n" \
                          f"❓ **Is everything correct?**\n\n" \
                          f"✅ Yes, submit complaint\n" \
                          f"✏️ Need to change something"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'final_review',
                'show_confirmation': True,
                'data': {
                    'summary': state.user_data,
                    'buttons': ['Submit', 'Edit']
                }
            }
        
        else:
            # Remind user about photo upload
            if language == 'hindi':
                response = f"📷 **फोटो अपलोड करने के लिए:**\n\n" \
                          f"📱 कैमरा बटन दबाएं\n" \
                          f"🖼️ गैलरी से चुनें\n" \
                          f"⏭️ या 'SKIP' लिखें"
            else:
                response = f"📷 **To upload photo:**\n\n" \
                          f"📱 Tap camera button\n" \
                          f"🖼️ Choose from gallery\n" \
                          f"⏭️ Or type 'SKIP'"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'upload_photo',
                'show_camera': True
            }
    
    def _handle_final_review(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle final review before submission"""
        language = state.user_data.get('language', 'english')
        message_lower = message.lower()
        
        if any(word in message_lower for word in ['submit', 'yes', 'हां', 'सबमिट', 'confirm']):
            # Submit complaint
            state.current_step = ConversationStep.SUBMISSION
            
            # Generate complaint ID
            complaint_id = f"JH{timezone.now().strftime('%Y%m%d')}{state.session_id[-4:]}"
            state.user_data['complaint_id'] = complaint_id
            
            if language == 'hindi':
                response = f"🎉 **शिकायत सफलतापूर्वक दर्ज हो गई!** ✅\n\n" \
                          f"🏷️ **शिकायत आईडी:** {complaint_id}\n\n" \
                          f"📞 **आगे क्या होगा:**\n" \
                          f"• 24 घंटे में विभाग को भेजा जाएगा\n" \
                          f"• SMS/Email से अपडेट मिलेगा\n" \
                          f"• 3-5 दिन में कार्यवाही शुरू\n\n" \
                          f"📱 **ट्रैक करने के लिए:** JanHelp ऐप में 'My Complaints' देखें\n\n" \
                          f"🙏 **धन्यवाद! आपकी आवाज सुनी गई है।** 🎆"
            else:
                response = f"🎉 **Complaint Successfully Registered!** ✅\n\n" \
                          f"🏷️ **Complaint ID:** {complaint_id}\n\n" \
                          f"📞 **What happens next:**\n" \
                          f"• Forwarded to department within 24 hours\n" \
                          f"• You'll get SMS/Email updates\n" \
                          f"• Action will start in 3-5 days\n\n" \
                          f"📱 **To track:** Check 'My Complaints' in JanHelp app\n\n" \
                          f"🙏 **Thank you! Your voice has been heard.** 🎆"
            
            # Mark as completed
            state.current_step = ConversationStep.COMPLETED
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'completed',
                'complaint_submitted': True,
                'data': {
                    'complaint_id': complaint_id,
                    'complaint_data': state.user_data
                }
            }
        
        elif any(word in message_lower for word in ['edit', 'change', 'बदल', 'एडिट']):
            # User wants to edit - ask what to change
            if language == 'hindi':
                response = f"✏️ **क्या बदलना है?**\n\n" \
                          f"1️⃣ समस्या का प्रकार\n" \
                          f"2️⃣ विवरण\n" \
                          f"3️⃣ स्थान\n" \
                          f"4️⃣ फोटो\n" \
                          f"5️⃣ सब कुछ दोबारा शुरू करें"
            else:
                response = f"✏️ **What would you like to change?**\n\n" \
                          f"1️⃣ Problem type\n" \
                          f"2️⃣ Details\n" \
                          f"3️⃣ Location\n" \
                          f"4️⃣ Photo\n" \
                          f"5️⃣ Start over completely"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'select_edit_option',
                'show_edit_options': True,
                'data': {
                    'edit_options': ['Problem type', 'Details', 'Location', 'Photo', 'Start over']
                }
            }
        
        else:
            # Show summary again
            if language == 'hindi':
                response = f"📋 **कृपया पुष्टि करें:**\n\n" \
                          f"✅ सबमिट करें (शिकायत दर्ज करें)\n" \
                          f"✏️ एडिट करें (कुछ बदलें)"
            else:
                response = f"📋 **Please confirm:**\n\n" \
                          f"✅ Submit (Register complaint)\n" \
                          f"✏️ Edit (Change something)"
            
            return {
                'response': response,
                'step': state.current_step,
                'next_action': 'final_review',
                'show_confirmation': True,
                'data': {
                    'buttons': ['Submit', 'Edit']
                }
            }
    
    def _handle_default(self, state: ConversationState, message: str) -> Dict[str, Any]:
        """Handle default/fallback responses"""
        language = state.user_data.get('language', 'english')
        
        if language == 'hindi':
            response = "😅 माफ करें, मुझे समझ नहीं आया। कृपया फिर से बताएं।"
        else:
            response = "😅 Sorry, I didn't understand. Could you please try again?"
        
        return {
            'response': response,
            'step': state.current_step,
            'next_action': 'retry'
        }

# Global instance
step_by_step_ai = StepByStepAI()