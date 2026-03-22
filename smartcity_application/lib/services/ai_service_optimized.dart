// Add these methods to your ai_service.dart to make it faster

// 1. Add at top of AIService class (after other variables)
final Map<String, Map<String, dynamic>> _llmCache = {};
final Map<String, DateTime> _llmCacheTimestamp = {};
static const Duration _llmCacheExpiry = Duration(minutes: 10);

// 2. Replace your _callCityFixLLM method with this optimized version:
Future<Map<String, dynamic>?> _callCityFixLLM(String text) async {
  // Normalize text for cache key
  final cacheKey = text.toLowerCase().trim();
  
  // Check cache first
  if (_llmCache.containsKey(cacheKey)) {
    final timestamp = _llmCacheTimestamp[cacheKey];
    if (timestamp != null && DateTime.now().difference(timestamp) < _llmCacheExpiry) {
      print('✅ Using cached LLM result (${_llmCache.length} items in cache)');
      return _llmCache[cacheKey];
    } else {
      // Cache expired
      _llmCache.remove(cacheKey);
      _llmCacheTimestamp.remove(cacheKey);
    }
  }

  try {
    print('🚀 Calling CityFix LLM API...');
    final startTime = DateTime.now();
    
    final response = await http.post(
      Uri.parse('https://kartik1911-cityfix-llm-demo.hf.space/api/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': [text]}),
    ).timeout(const Duration(seconds: 10)); // Reduced from 30 to 10 seconds

    final duration = DateTime.now().difference(startTime);
    print('⏱️ LLM API responded in ${duration.inMilliseconds}ms');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null && data['data'].isNotEmpty) {
        final result = data['data'][0] as Map<String, dynamic>;
        
        // Cache the result
        _llmCache[cacheKey] = result;
        _llmCacheTimestamp[cacheKey] = DateTime.now();
        
        // Limit cache size to prevent memory issues
        if (_llmCache.length > 100) {
          final oldestKey = _llmCacheTimestamp.entries
              .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
              .key;
          _llmCache.remove(oldestKey);
          _llmCacheTimestamp.remove(oldestKey);
          print('🗑️ Removed oldest cache entry');
        }
        
        print('✅ LLM prediction cached');
        return result;
      }
    }
    
    print('❌ LLM API returned invalid response');
    return null;
  } catch (e) {
    print('❌ CityFix LLM error: $e');
    return null;
  }
}

// 3. Add method to clear cache when needed
void clearLLMCache() {
  _llmCache.clear();
  _llmCacheTimestamp.clear();
  print('🗑️ LLM cache cleared');
}

// 4. Update reset() method to also clear LLM cache
void reset() {
  _history.clear();
  _complaintData.clear();
  _currentLanguage = 'en';
  _userMood = 'neutral';
  _sessionId = '';
  _conversationState = 'greeting';
  _categoryConfirmed = false;
  _responseCache.clear();
  clearLLMCache(); // Add this line
  print('AI Service reset - new session will be created');
}
