# MapmyIndia (Mappls) Integration Setup

## Features Added

The complaint registration form now includes three location selection methods:

1. **Auto Detect** - Automatically detects user's current location using GPS
2. **Select on Map** - Interactive map where users can click or drag marker to select location
3. **Manual Entry** - Users can manually fill in location details

## Setup Instructions

### 1. Get MapmyIndia API Key

1. Visit [https://apis.mappls.com/console/](https://apis.mappls.com/console/)
2. Sign up or log in to your account
3. Create a new project or select existing one
4. Copy your API key from the dashboard

### 2. Configure API Key

1. Open your `.env` file (or create one from `.env.example`)
2. Add your MapmyIndia API key:
   ```
   MAPMYINDIA_API_KEY=your-actual-api-key-here
   ```

### 3. Test the Features

1. Run the development server:
   ```
   python manage.py runserver
   ```

2. Navigate to Submit Complaint page

3. Test each location method:
   - **Auto Detect**: Click the button and allow location access in browser
   - **Select on Map**: Click to open interactive map, click/drag marker to select location
   - **Manual Entry**: Click to manually fill in all location fields

## How It Works

### Auto Detect
- Uses browser's Geolocation API to get current GPS coordinates
- Automatically fills all location fields using MapmyIndia reverse geocoding
- Shows success message when location is detected

### Select on Map
- Opens an interactive MapmyIndia map
- Users can click anywhere on map or drag the marker
- Click "Confirm Location" to fetch address details
- Automatically fills all location fields

### Manual Entry
- Hides the map
- Users manually fill in: State, District, City, Area, Road, Landmark, Pincode, Address
- Useful when GPS is unavailable or user wants to report a different location

## Location Fields Auto-Filled

When using Auto Detect or Select on Map, these fields are automatically populated:
- State
- District
- City/Village
- Area/Locality
- Road Name
- Pincode
- Full Address
- Latitude & Longitude (hidden fields)

## Troubleshooting

### Map not loading
- Verify your API key is correct in `.env` file
- Check browser console for errors
- Ensure you have active internet connection

### Location not detected
- Allow location access in browser when prompted
- Check if location services are enabled on device
- Try using "Select on Map" or "Manual Entry" as alternative

### Address not fetching
- Verify API key has geocoding permissions
- Check MapmyIndia API usage limits
- Ensure coordinates are within India (MapmyIndia primarily covers India)

## API Documentation

For more details on MapmyIndia APIs:
- [Map SDK Documentation](https://github.com/mappls-api/mappls-web-maps)
- [Reverse Geocoding API](https://github.com/mappls-api/mappls-rest-apis/tree/main/docs/custom/Reverse-Geocoding-API.md)
