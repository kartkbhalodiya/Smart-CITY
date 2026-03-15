from django.core.management.base import BaseCommand
from django.db import transaction
from complaints.models import ComplaintCategory, ComplaintSubcategory, ComplaintCategoryField

class Command(BaseCommand):
    help = 'Populate categories, subcategories and fields'

    def handle(self, *args, **options):
        # Category definitions
        categories_data = [
            ('police', 'Police Complaint', '🚓'),
            ('traffic', 'Traffic Complaint', '🚦'),
            ('construction', 'Construction Complaint', '🏗️'),
            ('water', 'Water Supply', '🚰'),
            ('electricity', 'Electricity', '💡'),
            ('garbage', 'Garbage/Sanitation', '🗑️'),
            ('road', 'Road/Pothole', '🛣️'),
            ('drainage', 'Drainage/Sewage', '🌊'),
            ('illegal', 'Illegal Activities', '⚠️'),
            ('transportation', 'Transportation', '🚌'),
            ('cyber', 'Cyber Crime', '🛡️'),
            ('other', 'Other Complaint', '📋'),
        ]

        # Common default fields to reach 4-5 fields if needed
        default_fields = [
            {'label': 'Location Description', 'field_type': 'text', 'is_required': True},
            {'label': 'Date of Incident', 'field_type': 'date', 'is_required': False},
            {'label': 'Severity', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': False},
            {'label': 'Additional Remarks', 'field_type': 'textarea', 'is_required': False},
            {'label': 'Any Landmark Nearby', 'field_type': 'text', 'is_required': False},
        ]

        # Specific subcategories data
        subcats_data = {
            'police': [
                'Theft / Robbery', 'Cyber Crime', 'Domestic Violence', 'Missing Person',
                'Drug / Narcotics', 'Physical Assault', 'Fraud / Scam',
                'Harassment / Threat', 'Property Damage', 'Illegal Activity', 'Other'
            ],
            'traffic': [
                'Signal Jumping', 'Wrong Side Driving', 'Overspeeding', 'Illegal Parking',
                'No Helmet / Triple Riding', 'No Seatbelt', 'Drunk Driving', 'Rash / Dangerous Driving',
                'Using Mobile While Driving', 'Heavy Vehicle Violation', 'Traffic Obstruction', 'Other'
            ],
            'construction': [
                'Road Damage / Potholes', 'Footpath / Sidewalk Damage', 'Drainage Construction Issues',
                'Bridge / Flyover Issue', 'Illegal Construction', 'Construction Debris',
                'Public Building Damage', 'Structure Collapse Risk', 'Unsafe Excavation', 'Other'
            ],
            'water': [
                'No Water Supply', 'Low Water Pressure', 'Water Leakage', 'Burst Water Pipeline',
                'Dirty / Contaminated Water', 'Water Tank Overflow', 'Broken Water Tap',
                'Water Meter Problem', 'Water Tanker Complaint', 'Other'
            ],
            'electricity': [
                'Power Outage', 'Frequent Power Cuts', 'Street Light Not Working',
                'Exposed Electrical Wires', 'Electric Pole Damage', 'Transformer Issue',
                'Electric Spark', 'Electricity Meter Problem', 'Illegal Connection', 'Other'
            ],
            'garbage': [
                'Garbage Not Collected', 'Overflowing Garbage Bin', 'Illegal Garbage Dumping',
                'Dead Animal Removal', 'Garbage Burning', 'Public Dustbin Damage',
                'Missed Door-to-Door', 'Garbage Truck Issue', 'Construction Waste', 'Other'
            ],
            'road': [
                'Pothole on Road', 'Broken Road', 'Water Logging on Road',
                'Road Construction Delay', 'Road Blocked by Materials', 'Missing Road Markings',
                'Speed Breaker Issue', 'Road Shoulder Damage', 'Dangerous Conditions', 'Other'
            ],
            'drainage': [
                'Blocked Drain', 'Drain Overflow', 'Water Logging Area',
                'Broken Drain Cover', 'Damaged Drain Structure', 'Sewage Leakage',
                'Illegal Drain Connection', 'Drain Cleaning Required', 'Manhole Issue', 'Other'
            ],
            'illegal': [
                'Illegal Construction', 'Unauthorized Street Vendors', 'Illegal Waste Dumping',
                'Unauthorized Water Connection', 'Power Theft', 'Illegal Parking',
                'Illegal Advertisement', 'Noise Pollution', 'Unauthorized Business', 'Other'
            ],
            'transportation': [
                'Public Bus Issue', 'Bus Stop Issue', 'Traffic Signal Failure',
                'Traffic Congestion', 'Illegal Parking (Transport)', 'Damaged Road Sign',
                'Auto / Taxi Complaint', 'Pedestrian Crossing Issue', 'Railway Crossing Issue', 'Other'
            ],
            'cyber': [
                'Online Payment Fraud', 'Phishing Scam', 'OTP / Banking Fraud', 'Social Media Hacking',
                'Online Shopping Fraud', 'Identity Theft', 'Fake Job Scam',
                'Investment Fraud', 'Mobile App Fraud', 'Other'
            ],
            'other': [
                'Public Facility Issue', 'Animal Related Issue', 'Noise Complaint', 'Public Safety Concern',
                'Government Service Complaint', 'Public Park Issue', 'Public Event Disturbance',
                'Environmental Issue', 'General Complaint', 'Other'
            ]
        }

        fields_data = {
            'Theft / Robbery': [
                {'label': 'Item Stolen', 'field_type': 'text', 'is_required': True},
                {'label': 'Estimated Value', 'field_type': 'text', 'is_required': False},
                {'label': 'Date & Time', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Stolen From', 'field_type': 'text', 'is_required': False},
                {'label': 'Any Witnesses', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
            ],
            'Domestic Violence': [
                {'label': 'Relationship with Accused', 'field_type': 'text', 'is_required': True},
                {'label': 'Type of Violence', 'field_type': 'select', 'options': 'Physical,Emotional,Financial,Sexual', 'is_required': True},
                {'label': 'Duration of Abuse', 'field_type': 'text', 'is_required': False},
                {'label': 'Immediate Danger', 'field_type': 'select', 'options': 'Yes,No', 'is_required': True},
                {'label': 'Are children involved', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
            ],
            'Missing Person': [
                {'label': 'Person Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Age', 'field_type': 'number', 'is_required': True},
                {'label': 'Last Seen At', 'field_type': 'text', 'is_required': True},
                {'label': 'Last Seen Date & Time', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Identifying Marks', 'field_type': 'text', 'is_required': False},
            ],
            'Signal Jumping': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Vehicle Type', 'field_type': 'select', 'options': 'Two Wheeler,Car,Bus,Truck,Auto', 'is_required': False},
                {'label': 'Signal Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Time of Incident', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Direction of Travel', 'field_type': 'text', 'is_required': False},
            ],
            'Wrong Side Driving': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Vehicle Type', 'field_type': 'select', 'options': 'Two Wheeler,Car,Bus,Truck,Auto', 'is_required': False},
                {'label': 'Location / Road', 'field_type': 'text', 'is_required': True},
                {'label': 'Time of Incident', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Severity of Obstruction', 'field_type': 'select', 'options': 'Minor,Major,Dangerous', 'is_required': False},
            ],
            'No Water Supply': [
                {'label': 'Duration', 'field_type': 'select', 'options': 'Few Hours,1 Day,2-3 Days,More Than 3 Days', 'is_required': True},
                {'label': 'Water Source Type', 'field_type': 'select', 'options': 'Municipal Supply,Tanker,Borewell', 'is_required': False},
                {'label': 'Number of Houses Affected', 'field_type': 'number', 'is_required': False},
                {'label': 'Area / Locality Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Previous Complaint ID', 'field_type': 'text', 'is_required': False},
            ],
            'Low Water Pressure': [
                {'label': 'Since When', 'field_type': 'text', 'is_required': True},
                {'label': 'Time of Day', 'field_type': 'select', 'options': 'Morning,Afternoon,Evening,All Day', 'is_required': False},
                {'label': 'Type of Connection', 'field_type': 'select', 'options': 'Residential,Commercial,Industrial', 'is_required': False},
                {'label': 'Is it for entire street', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Last supply date', 'field_type': 'date', 'is_required': False},
            ],
            'Power Outage': [
                {'label': 'Since When', 'field_type': 'select', 'options': 'Few Minutes,1 Hour,Several Hours,More Than 1 Day', 'is_required': True},
                {'label': 'Affected Area Size', 'field_type': 'select', 'options': 'Single House,Building,Entire Street,Entire Area', 'is_required': False},
                {'label': 'Is Emergency', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Local Area Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Power Cut Type', 'field_type': 'select', 'options': 'Full Cut,Low Voltage,Partial Phase', 'is_required': False},
            ],
            'Street Light Not Working': [
                {'label': 'Pole Number (if visible)', 'field_type': 'text', 'is_required': False},
                {'label': 'Number of lights out', 'field_type': 'number', 'is_required': True},
                {'label': 'Nearest Landmark', 'field_type': 'text', 'is_required': True},
                {'label': 'Duration of issue', 'field_type': 'text', 'is_required': False},
                {'label': 'Safety concern', 'field_type': 'select', 'options': 'Low,High', 'is_required': False},
            ],
            'Pothole on Road': [
                {'label': 'Number of Potholes', 'field_type': 'number', 'is_required': True},
                {'label': 'Approximate Size', 'field_type': 'select', 'options': 'Small,Medium,Large', 'is_required': False},
                {'label': 'Danger Level', 'field_type': 'select', 'options': 'Low,Medium,High,Dangerous', 'is_required': False},
                {'label': 'Road Type', 'field_type': 'select', 'options': 'Main Road,Internal Road,Service Road', 'is_required': False},
                {'label': 'Road Name / Area', 'field_type': 'text', 'is_required': True},
            ],
            'Garbage Not Collected': [
                {'label': 'Last Collection Date', 'field_type': 'date', 'is_required': True},
                {'label': 'Area / Locality', 'field_type': 'text', 'is_required': True},
                {'label': 'Bin Location', 'field_type': 'text', 'is_required': False},
                {'label': 'Frequency of Issue', 'field_type': 'select', 'options': 'First Time,Recurring,Regular Problem', 'is_required': False},
                {'label': 'Odour Level', 'field_type': 'select', 'options': 'Tolerable,Strong,Unbearable', 'is_required': False},
            ],
            'Blocked Drain': [
                {'label': 'Location of Blockage', 'field_type': 'text', 'is_required': True},
                {'label': 'Is Water Overflowing', 'field_type': 'select', 'options': 'Yes,No', 'is_required': True},
                {'label': 'Type of Drain', 'field_type': 'select', 'options': 'Surface,Closed,Main Sewer', 'is_required': False},
                {'label': 'Severity of Smell', 'field_type': 'select', 'options': 'None,Mild,Strong', 'is_required': False},
                {'label': 'Impact on Road Traffic', 'field_type': 'select', 'options': 'None,Partial,Full Blockage', 'is_required': False},
            ],
            'Illegal Construction': [
                {'label': 'Construction Site Address', 'field_type': 'text', 'is_required': True},
                {'label': 'Type of Structure', 'field_type': 'select', 'options': 'Residential,Commercial,Encroachment', 'is_required': True},
                {'label': 'Current Status', 'field_type': 'select', 'options': 'Starting,Ongoing,Near Completion', 'is_required': False},
                {'label': 'Permission Details (if known)', 'field_type': 'text', 'is_required': False},
                {'label': 'Safety Violation', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
            ],
            'Cyber Crime': [
                {'label': 'Type of Fraud', 'field_type': 'select', 'options': 'Banking,Social Media,Hacking,Online Shopping', 'is_required': True},
                {'label': 'Amount Lost', 'field_type': 'text', 'is_required': False},
                {'label': 'Website / App Involved', 'field_type': 'text', 'is_required': False},
                {'label': 'Transaction Date', 'field_type': 'date', 'is_required': True},
                {'label': 'Suspect Details', 'field_type': 'text', 'is_required': False},
            ],
            'Public Bus Issue': [
                {'label': 'Bus Number / Route', 'field_type': 'text', 'is_required': True},
                {'label': 'Issue Type', 'field_type': 'select', 'options': 'Delay,Rash Driving,Staff Behaviour,Cleanliness', 'is_required': True},
                {'label': 'Time of Issue', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Bus Stop Name', 'field_type': 'text', 'is_required': False},
                {'label': 'Employee Name / ID (if any)', 'field_type': 'text', 'is_required': False},
            ],
            'Other': [
                {'label': 'Specific Category', 'field_type': 'text', 'is_required': True},
                {'label': 'Urgency', 'field_type': 'select', 'options': 'Low,Normal,Urgent,Critical', 'is_required': True},
                {'label': 'Related Department', 'field_type': 'text', 'is_required': False},
                {'label': 'Is it a public issue', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Previous Reference (if any)', 'field_type': 'text', 'is_required': False},
            ]
        }

        self.stdout.write('Starting population of categories, subcategories and fields...')

        with transaction.atomic():
            for key, name, emoji in categories_data:
                category, _ = ComplaintCategory.objects.update_or_create(
                    key=key,
                    defaults={'name': name, 'emoji': emoji, 'is_active': True}
                )
                
                self.stdout.write(f'Processing category: {name}')

                subcats = subcats_data.get(key, ['Other'])
                while len(subcats) < 10:
                    idx = len(subcats) + 1
                    subcats.append(f'Other Subcategory {idx}')

                for i, sub_name in enumerate(subcats):
                    subcategory, _ = ComplaintSubcategory.objects.update_or_create(
                        category=category,
                        name=sub_name,
                        defaults={'is_active': True, 'display_order': i}
                    )
                    
                    # Clear existing fields for this subcategory to ensure exactly 5 fresh ones
                    ComplaintCategoryField.objects.filter(category=category, subcategory=subcategory).delete()

                    s_fields = fields_data.get(sub_name, [])
                    final_fields = list(s_fields)
                    
                    # If no specific fields, generate some based on category/subcategory name
                    if not final_fields:
                        if key == 'police':
                            final_fields.append({'label': f'Incident Details for {sub_name}', 'field_type': 'textarea', 'is_required': True})
                            final_fields.append({'label': 'Time of Incident', 'field_type': 'datetime-local', 'is_required': True})
                            final_fields.append({'label': 'Suspect Description', 'field_type': 'text', 'is_required': False})
                        elif key == 'traffic':
                            final_fields.append({'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Location Description', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Incident Time', 'field_type': 'datetime-local', 'is_required': True})
                        elif key == 'water':
                            final_fields.append({'label': 'Supply Issue Since', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Locality Affected', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Pressure Level', 'field_type': 'select', 'options': 'None,Low,Normal', 'is_required': False})
                        elif key == 'electricity':
                            final_fields.append({'label': 'Issue Type', 'field_type': 'select', 'options': 'No Power,Fluctuation,Sparks', 'is_required': True})
                            final_fields.append({'label': 'Pole/Transformer ID', 'field_type': 'text', 'is_required': False})
                            final_fields.append({'label': 'Since When', 'field_type': 'text', 'is_required': True})
                        elif key == 'garbage':
                            final_fields.append({'label': 'Location of Waste', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Type of Waste', 'field_type': 'select', 'options': 'Dry,Wet,Construction,Dead Animal', 'is_required': True})
                            final_fields.append({'label': 'Volume of Garbage', 'field_type': 'select', 'options': 'Small,Medium,Large', 'is_required': False})
                        elif key == 'road':
                            final_fields.append({'label': 'Road Condition', 'field_type': 'textarea', 'is_required': True})
                            final_fields.append({'label': 'Approx Length (m)', 'field_type': 'number', 'is_required': False})
                            final_fields.append({'label': 'Hazard Level', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': True})
                        else:
                            final_fields.append({'label': f'Specific Details about {sub_name}', 'field_type': 'textarea', 'is_required': True})
                            final_fields.append({'label': 'Occurrence Date', 'field_type': 'date', 'is_required': True})
                            final_fields.append({'label': 'Severity', 'field_type': 'select', 'options': 'Low,Medium,High,Critical', 'is_required': True})

                    for df in default_fields:
                        if len(final_fields) >= 5:
                            break
                        if not any(f['label'] == df['label'] for f in final_fields):
                            final_fields.append(df)
                    
                    for j, f_data in enumerate(final_fields):
                        ComplaintCategoryField.objects.create(
                                category=category,
                                subcategory=subcategory,
                                label=f_data['label'],
                                field_type=f_data['field_type'],
                                options=f_data.get('options', ''),
                                is_required=f_data.get('is_required', False),
                                display_order=j,
                                is_active=True
                            )

        self.stdout.write(self.style.SUCCESS('Successfully populated categories, subcategories and fields.'))
