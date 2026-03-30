# Flutter App Performance Optimization Guide

## Quick Fixes (Do These First!)

### 1. Enable Release Mode
```bash
# Instead of debug mode, use release mode
flutter run --release

# Or build APK
flutter build apk --release
```

### 2. Optimize AI Service - Add Caching

Add this to your `ai_service.dart`:

```dart
// Add at top of AIService class
static const String _llmCacheKey = 'cityfix_llm_cache';
final Map<String, Map<String, dynamic>> _llmCache = {};

// Replace _callCityFixLLM with this optimized version:
Future<Map<String, dynamic>?> _callCityFixLLM(String text) async {
  // Check cache first
  final cacheKey = text.toLowerCase().trim();
  if (_llmCache.containsKey(cacheKey)) {
    print('Using cached LLM result');
    return _llmCache[cacheKey];
  }

  try {
    final response = await http.post(
      Uri.parse('https://kartik1911-cityfix-llm-demo.hf.space/api/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': [text]}),
    ).timeout(const Duration(seconds: 10)); // Reduced timeout

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null && data['data'].isNotEmpty) {
        final result = data['data'][0] as Map<String, dynamic>;
        
        // Cache result
        _llmCache[cacheKey] = result;
        
        // Limit cache size
        if (_llmCache.length > 50) {
          _llmCache.remove(_llmCache.keys.first);
        }
        
        return result;
      }
    }
    return null;
  } catch (e) {
    print('CityFix LLM error: $e');
    return null;
  }
}
```

### 3. Reduce Image Sizes

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_image_compress: ^2.0.0
```

Create `lib/utils/image_optimizer.dart`:
```dart
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageOptimizer {
  static Future<File?> compressImage(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf('.');
    final outPath = "${filePath.substring(0, lastIndex)}_compressed.jpg";
    
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 70, // Reduce quality
      minWidth: 1024, // Max width
      minHeight: 1024, // Max height
    );
    
    return result;
  }
}
```

### 4. Lazy Load Widgets

Replace heavy widgets with lazy loading:
```dart
// Instead of loading all at once
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ComplaintCard(items[index]);
  },
)
```

### 5. Optimize Network Calls

Create `lib/utils/api_cache.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ApiCache {
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  static Future<Map<String, dynamic>?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached == null) return null;
    
    final data = jsonDecode(cached);
    final timestamp = DateTime.parse(data['timestamp']);
    
    if (DateTime.now().difference(timestamp) > _cacheExpiry) {
      await prefs.remove(key);
      return null;
    }
    
    return data['value'];
  }
  
  static Future<void> set(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'value': value,
    };
    await prefs.setString(key, jsonEncode(data));
  }
}
```

### 6. Reduce App Size

Add to `android/app/build.gradle`:
```gradle
android {
    buildTypes {
        release {
            shrinkResources true
            minifyEnabled true
        }
    }
    
    // Split APKs by architecture
    splits {
        abi {
            enable true
            reset()
            include 'armeabi-v7a', 'arm64-v8a'
            universalApk false
        }
    }
}
```

### 7. Optimize Imports

Remove unused imports:
```bash
flutter pub run dart_code_metrics:metrics analyze lib
```

### 8. Use Const Widgets

```dart
// Bad
Text('Hello')

// Good
const Text('Hello')

// Bad
Container(child: Text('Hello'))

// Good
const SizedBox(child: Text('Hello'))
```

### 9. Debounce API Calls

For search/typing:
```dart
import 'dart:async';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

// Usage in AI chat
final _debouncer = Debouncer(delay: Duration(milliseconds: 800));

void _onTextChanged(String text) {
  _debouncer.call(() {
    // Call AI only after user stops typing
    _analyzeComplaint(text);
  });
}
```

### 10. Optimize ListView

```dart
// Use this for long lists
ListView.builder(
  itemCount: items.length,
  cacheExtent: 100, // Preload items
  addAutomaticKeepAlives: false, // Don't keep all items alive
  addRepaintBoundaries: false, // Reduce repaints
  itemBuilder: (context, index) {
    return ComplaintCard(items[index]);
  },
)
```

## Performance Checklist

- [ ] Run in release mode
- [ ] Add LLM response caching
- [ ] Compress images before upload
- [ ] Use const widgets everywhere
- [ ] Lazy load lists
- [ ] Cache API responses
- [ ] Debounce text inputs
- [ ] Remove unused packages
- [ ] Enable code shrinking
- [ ] Use ListView.builder for long lists

## Measure Performance

```bash
# Check app size
flutter build apk --analyze-size

# Profile performance
flutter run --profile

# Check for jank
flutter run --trace-skia
```

## Expected Results

Before optimization:
- App size: ~50MB
- Cold start: 3-5 seconds
- AI response: 3-5 seconds

After optimization:
- App size: ~20MB
- Cold start: 1-2 seconds
- AI response: 0.5-2 seconds (with cache)

## Quick Command

```bash
# Build optimized release APK
flutter build apk --release --split-per-abi --shrink
```

This will create 3 smaller APKs instead of 1 large one!
