from django.core.management.base import BaseCommand
from django.db import transaction
from complaints.models import ComplaintCategory, ComplaintSubcategory, ComplaintCategoryField

class Command(BaseCommand):
    help = 'Populate categories, subcategories and fields'

    def add_arguments(self, parser):
        parser.add_argument('--category', type=str, help='Process only this specific category key')

    def handle(self, *args, **options):
        specific_category = options.get('category')
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

        # Common default fields to reach 10 fields if needed
        default_fields = [
            {'label': 'Location Description', 'field_type': 'text', 'is_required': True},
            {'label': 'Date of Incident', 'field_type': 'date', 'is_required': False},
            {'label': 'Severity', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': False},
            {'label': 'Additional Remarks', 'field_type': 'textarea', 'is_required': False},
            {'label': 'Any Landmark Nearby', 'field_type': 'text', 'is_required': False},
            {'label': 'Photo Evidence Attached', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
            {'label': 'Public Safety Impact', 'field_type': 'select', 'options': 'None,Low,Moderate,High', 'is_required': False},
            {'label': 'Frequency of Issue', 'field_type': 'select', 'options': 'First Time,Occasional,Persistent', 'is_required': False},
            {'label': 'Contact Preference', 'field_type': 'select', 'options': 'Phone,Email,SMS', 'is_required': False},
            {'label': 'Urgency Level', 'field_type': 'select', 'options': 'Normal,Urgent,Immediate', 'is_required': False},
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
                {'label': 'Incident Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Date & Time of Incident', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Type of Property Stolen', 'field_type': 'text', 'is_required': True},
                {'label': 'Estimated Value of Loss', 'field_type': 'text', 'is_required': False},
                {'label': 'Suspect Description (if known)', 'field_type': 'textarea', 'is_required': False},
                {'label': 'Witness Details', 'field_type': 'textarea', 'is_required': False},
            ],
            'Cyber Crime': [
                {'label': 'Platform / Website / App Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Fraud Type', 'field_type': 'select', 'options': 'UPI Fraud,Credit Card,Bank Transfer,Social Media,Other', 'is_required': True},
                {'label': 'Amount Lost', 'field_type': 'text', 'is_required': True},
                {'label': 'Transaction ID', 'field_type': 'text', 'is_required': False},
                {'label': 'Date of Incident', 'field_type': 'date', 'is_required': True},
                {'label': 'Contact Number Used', 'field_type': 'text', 'is_required': False},
            ],
            'Domestic Violence': [
                {'label': 'Victim Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Incident Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Relationship to Accused', 'field_type': 'text', 'is_required': True},
                {'label': 'Date of Incident', 'field_type': 'date', 'is_required': True},
                {'label': 'Type of Abuse', 'field_type': 'select', 'options': 'Physical,Emotional,Financial,Other', 'is_required': True},
                {'label': 'Immediate Danger', 'field_type': 'select', 'options': 'Yes,No', 'is_required': True},
            ],
            'Missing Person': [
                {'label': 'Name of Missing Person', 'field_type': 'text', 'is_required': True},
                {'label': 'Age', 'field_type': 'number', 'is_required': True},
                {'label': 'Last Seen Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Date Last Seen', 'field_type': 'date', 'is_required': True},
                {'label': 'Physical Description', 'field_type': 'textarea', 'is_required': True},
                {'label': 'Contact Person', 'field_type': 'text', 'is_required': True},
            ],
            'Physical Assault': [
                {'label': 'Incident Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Date & Time', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Number of Attackers', 'field_type': 'number', 'is_required': False},
                {'label': 'Injury Details', 'field_type': 'textarea', 'is_required': True},
                {'label': 'Suspect Description', 'field_type': 'textarea', 'is_required': False},
                {'label': 'Witness Details', 'field_type': 'textarea', 'is_required': False},
            ],
            'Signal Jumping': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Signal Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Date & Time', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Vehicle Type', 'field_type': 'select', 'options': 'Two Wheeler,Four Wheeler,Heavy Vehicle,Other', 'is_required': False},
            ],
            'Wrong Side Driving': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Road Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Date & Time', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Traffic Risk Level', 'field_type': 'select', 'options': 'Low,Medium,High,Very Dangerous', 'is_required': True},
            ],
            'Overspeeding': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Road Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Estimated Speed', 'field_type': 'text', 'is_required': True},
                {'label': 'Speed Limit Area', 'field_type': 'text', 'is_required': False},
                {'label': 'Date & Time', 'field_type': 'datetime-local', 'is_required': True},
            ],
            'Illegal Parking': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Parking Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Duration Parked', 'field_type': 'text', 'is_required': False},
                {'label': 'Road Blocked', 'field_type': 'select', 'options': 'Yes,No', 'is_required': True},
            ],
            'Road Damage / Potholes': [
                {'label': 'Road Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Pothole Size', 'field_type': 'select', 'options': 'Small,Medium,Large,Very Large', 'is_required': True},
                {'label': 'Depth Estimate', 'field_type': 'text', 'is_required': False},
                {'label': 'Traffic Risk Level', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': True},
            ],
            'Footpath / Sidewalk Damage': [
                {'label': 'Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Damage Type', 'field_type': 'select', 'options': 'Broken Tiles,Encroachment,Missing Section,Other', 'is_required': True},
                {'label': 'Length of Damage', 'field_type': 'text', 'is_required': False},
                {'label': 'Pedestrian Risk', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': True},
            ],
            'Other': [
                {'label': 'Incident Description', 'field_type': 'textarea', 'is_required': True},
                {'label': 'Location Details', 'field_type': 'text', 'is_required': True},
                {'label': 'Date of Occurrence', 'field_type': 'date', 'is_required': True},
                {'label': 'Supporting Information', 'field_type': 'textarea', 'is_required': False},
            ]
        }


        self.stdout.write('Starting population of categories, subcategories and fields...')

        with transaction.atomic():
            for key, name, emoji in categories_data:
                if specific_category and key != specific_category:
                    continue
                
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
                            final_fields.append({'label': 'Witness Name', 'field_type': 'text', 'is_required': False})
                            final_fields.append({'label': 'Weapon Involved', 'field_type': 'select', 'options': 'None,Firearm,Knife,Other', 'is_required': False})
                        elif key == 'traffic':
                            final_fields.append({'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Location Description', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Incident Time', 'field_type': 'datetime-local', 'is_required': True})
                            final_fields.append({'label': 'Vehicle Color', 'field_type': 'text', 'is_required': False})
                            final_fields.append({'label': 'Traffic Flow Impact', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': False})
                        elif key == 'water':
                            final_fields.append({'label': 'Supply Issue Since', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Locality Affected', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Pressure Level', 'field_type': 'select', 'options': 'None,Low,Normal', 'is_required': False})
                            final_fields.append({'label': 'Water Color', 'field_type': 'select', 'options': 'Clear,Brown,Yellow', 'is_required': False})
                            final_fields.append({'label': 'Tanker Service Needed', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False})
                        elif key == 'electricity':
                            final_fields.append({'label': 'Issue Type', 'field_type': 'select', 'options': 'No Power,Fluctuation,Sparks', 'is_required': True})
                            final_fields.append({'label': 'Pole/Transformer ID', 'field_type': 'text', 'is_required': False})
                            final_fields.append({'label': 'Since When', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Appliances Damaged', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False})
                            final_fields.append({'label': 'Danger to Public', 'field_type': 'select', 'options': 'Low,High', 'is_required': False})
                        elif key == 'garbage':
                            final_fields.append({'label': 'Location of Waste', 'field_type': 'text', 'is_required': True})
                            final_fields.append({'label': 'Type of Waste', 'field_type': 'select', 'options': 'Dry,Wet,Construction,Dead Animal', 'is_required': True})
                            final_fields.append({'label': 'Volume of Garbage', 'field_type': 'select', 'options': 'Small,Medium,Large', 'is_required': False})
                            final_fields.append({'label': 'Burning Reported', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False})
                            final_fields.append({'label': 'Near Water Body', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False})
                        elif key == 'road':
                            final_fields.append({'label': 'Road Condition', 'field_type': 'textarea', 'is_required': True})
                            final_fields.append({'label': 'Approx Length (m)', 'field_type': 'number', 'is_required': False})
                            final_fields.append({'label': 'Hazard Level', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': True})
                            final_fields.append({'label': 'Is it a Main Road', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False})
                            final_fields.append({'label': 'Night Lighting Available', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False})
                        else:
                            final_fields.append({'label': f'Specific Details about {sub_name}', 'field_type': 'textarea', 'is_required': True})
                            final_fields.append({'label': 'Occurrence Date', 'field_type': 'date', 'is_required': True})
                            final_fields.append({'label': 'Severity', 'field_type': 'select', 'options': 'Low,Medium,High,Critical', 'is_required': True})
                            final_fields.append({'label': 'Number of People Affected', 'field_type': 'number', 'is_required': False})
                            final_fields.append({'label': 'Contact for Visit', 'field_type': 'tel', 'is_required': False})

                    for df in default_fields:
                        if len(final_fields) >= 10:
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
