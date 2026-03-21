# Cloudinary Upload Preset Setup Instructions

## Quick Fix: Use Unsigned Upload Preset

Since the backend endpoint needs to be deployed, here's a faster solution using Cloudinary's unsigned upload preset:

### Step 1: Create Upload Preset in Cloudinary Dashboard

1. Go to https://cloudinary.com/console
2. Login with your account (Cloud name: dk1q50evg)
3. Click on **Settings** (gear icon) → **Upload**
4. Scroll down to **Upload presets**
5. Click **Add upload preset**
6. Configure:
   - **Preset name**: `smartcity_complaints`
   - **Signing Mode**: **Unsigned**
   - **Folder**: `complaints`
   - **Access mode**: Public
   - **Unique filename**: Yes
   - **Overwrite**: No
7. Click **Save**

### Step 2: Update Flutter Code (Temporary Fix)

Use this simpler upload code that doesn't require backend signature:

```dart
Future<String?> _uploadToCloudinary(File imageFile) async {
  try {
    setState(() {
      _messages.add(ChatMessage(
        text: '☁️ Uploading image...',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    const cloudName = 'dk1q50evg';
    const uploadPreset = 'smartcity_complaints';
    
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url);
    
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'complaints';
    
    final multipartFile = await http.MultipartFile.fromPath('file', imageFile.path);
    request.files.add(multipartFile);
    
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Upload timeout'),
    );
    
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final imageUrl = jsonData['secure_url'] as String;
      
      setState(() {
        _messages.add(ChatMessage(
          text: '✅ Image uploaded!',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      
      return imageUrl;
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  } catch (e) {
    print('Upload error: $e');
    setState(() {
      _messages.add(ChatMessage(
        text: '❌ Upload failed: ${e.toString()}',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
    return null;
  }
}
```

## Why This Works

- Unsigned presets are designed for client-side uploads
- No backend signature needed
- Still secure (you control what can be uploaded via preset settings)
- Works immediately without backend deployment

## Later: Deploy Backend Signature Endpoint

Once you deploy the backend changes to Vercel, you can switch to the signed upload method for better security.

To deploy backend:
```bash
git add .
git commit -m "Add Cloudinary signature endpoint"
git push
```

Vercel will auto-deploy the changes.
