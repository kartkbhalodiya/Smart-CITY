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
                {'label': 'Item Stolen', 'field_type': 'text', 'is_required': True},
                {'label': 'Estimated Value', 'field_type': 'text', 'is_required': False},
                {'label': 'Date & Time', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Stolen From', 'field_type': 'text', 'is_required': False},
                {'label': 'Any Witnesses', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Suspect Description', 'field_type': 'textarea', 'is_required': False},
                {'label': 'CCTV Available', 'field_type': 'select', 'options': 'Yes,No,Unknown', 'is_required': False},
                {'label': 'Police Notified', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Insurance Claimed', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Recovered Items', 'field_type': 'text', 'is_required': False},
            ],
            'Domestic Violence': [
                {'label': 'Relationship with Accused', 'field_type': 'text', 'is_required': True},
                {'label': 'Type of Violence', 'field_type': 'select', 'options': 'Physical,Emotional,Financial,Sexual', 'is_required': True},
                {'label': 'Duration of Abuse', 'field_type': 'text', 'is_required': False},
                {'label': 'Immediate Danger', 'field_type': 'select', 'options': 'Yes,No', 'is_required': True},
                {'label': 'Are children involved', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Any Witness Present', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Medical Help Required', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Is Safe Now', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Police Presence Requested', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Additional History', 'field_type': 'textarea', 'is_required': False},
            ],
            'Signal Jumping': [
                {'label': 'Vehicle Number', 'field_type': 'text', 'is_required': True},
                {'label': 'Vehicle Type', 'field_type': 'select', 'options': 'Two Wheeler,Car,Bus,Truck,Auto', 'is_required': False},
                {'label': 'Signal Location', 'field_type': 'text', 'is_required': True},
                {'label': 'Time of Incident', 'field_type': 'datetime-local', 'is_required': True},
                {'label': 'Direction of Travel', 'field_type': 'text', 'is_required': False},
                {'label': 'Traffic Density', 'field_type': 'select', 'options': 'Low,Medium,High', 'is_required': False},
                {'label': 'Officer Present', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'CCTV Working at Site', 'field_type': 'select', 'options': 'Yes,No,Unknown', 'is_required': False},
                {'label': 'Pedestrian Danger', 'field_type': 'select', 'options': 'Low,High', 'is_required': False},
                {'label': 'Accident Occurred', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
            ],
            'No Water Supply': [
                {'label': 'Duration', 'field_type': 'select', 'options': 'Few Hours,1 Day,2-3 Days,More Than 3 Days', 'is_required': True},
                {'label': 'Water Source Type', 'field_type': 'select', 'options': 'Municipal Supply,Tanker,Borewell', 'is_required': False},
                {'label': 'Number of Houses Affected', 'field_type': 'number', 'is_required': False},
                {'label': 'Area / Locality Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Is Tanker Required', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Previous Complaint ID', 'field_type': 'text', 'is_required': False},
                {'label': 'Water Pressure Level', 'field_type': 'select', 'options': 'Zero,Very Low,Intermittent', 'is_required': False},
                {'label': 'Supply Timing', 'field_type': 'text', 'is_required': False},
                {'label': 'Any Leakage Spotted', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Type of Line', 'field_type': 'select', 'options': 'Main Line,Branch Line,Individual Connection', 'is_required': False},
            ],
            'Power Outage': [
                {'label': 'Since When', 'field_type': 'select', 'options': 'Few Minutes,1 Hour,Several Hours,More Than 1 Day', 'is_required': True},
                {'label': 'Affected Area Size', 'field_type': 'select', 'options': 'Single House,Building,Entire Street,Entire Area', 'is_required': False},
                {'label': 'Is Emergency', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Local Area Name', 'field_type': 'text', 'is_required': True},
                {'label': 'Power Cut Type', 'field_type': 'select', 'options': 'Full Cut,Low Voltage,Partial Phase', 'is_required': False},
                {'label': 'Any Sparks Seen', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Transformer Condition', 'field_type': 'select', 'options': 'Normal,Smoking,Leaking Oil', 'is_required': False},
                {'label': 'Meter ID', 'field_type': 'text', 'is_required': False},
                {'label': 'Is Underground Line', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Previous Power Cut Duration', 'field_type': 'text', 'is_required': False},
            ],
            'Pothole on Road': [
                {'label': 'Number of Potholes', 'field_type': 'number', 'is_required': True},
                {'label': 'Approximate Size', 'field_type': 'select', 'options': 'Small,Medium,Large', 'is_required': False},
                {'label': 'Danger Level', 'field_type': 'select', 'options': 'Low,Medium,High,Dangerous', 'is_required': False},
                {'label': 'Road Type', 'field_type': 'select', 'options': 'Main Road,Internal Road,Service Road', 'is_required': False},
                {'label': 'Road Name / Area', 'field_type': 'text', 'is_required': True},
                {'label': 'Visibility at Night', 'field_type': 'select', 'options': 'Good,Poor,None', 'is_required': False},
                {'label': 'Vehicle Damage Caused', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Traffic Flow Impact', 'field_type': 'select', 'options': 'Minor,Major,Blocked', 'is_required': False},
                {'label': 'Water Logging in Pothole', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Approximate Depth (cm)', 'field_type': 'number', 'is_required': False},
            ],
            'Garbage Not Collected': [
                {'label': 'Last Collection Date', 'field_type': 'date', 'is_required': True},
                {'label': 'Area / Locality', 'field_type': 'text', 'is_required': True},
                {'label': 'Bin Location', 'field_type': 'text', 'is_required': False},
                {'label': 'Frequency of Issue', 'field_type': 'select', 'options': 'First Time,Recurring,Regular Problem', 'is_required': False},
                {'label': 'Odour Level', 'field_type': 'select', 'options': 'Tolerable,Strong,Unbearable', 'is_required': False},
                {'label': 'Health Risk', 'field_type': 'select', 'options': 'Low,High', 'is_required': False},
                {'label': 'Animal Activity', 'field_type': 'select', 'options': 'Stray Dogs,Cattle,Insects', 'is_required': False},
                {'label': 'Collection Timing', 'field_type': 'text', 'is_required': False},
                {'label': 'Volume of Garbage', 'field_type': 'select', 'options': 'Small,Medium,Huge', 'is_required': False},
                {'label': 'Is Public Road Blocked', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
            ],
            'Other': [
                {'label': 'Specific Category', 'field_type': 'text', 'is_required': True},
                {'label': 'Urgency', 'field_type': 'select', 'options': 'Low,Normal,Urgent,Critical', 'is_required': True},
                {'label': 'Related Department', 'field_type': 'text', 'is_required': False},
                {'label': 'Is it a public issue', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Previous Reference', 'field_type': 'text', 'is_required': False},
                {'label': 'Impact Area', 'field_type': 'text', 'is_required': False},
                {'label': 'Number of people affected', 'field_type': 'number', 'is_required': False},
                {'label': 'Legal advice sought', 'field_type': 'select', 'options': 'Yes,No', 'is_required': False},
                {'label': 'Resolution expected within', 'field_type': 'select', 'options': '24h,3 days,1 week', 'is_required': False},
                {'label': 'Additional details', 'field_type': 'textarea', 'is_required': False},
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
