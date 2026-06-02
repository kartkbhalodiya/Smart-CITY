import 'dart:convert';

/// Smart complaint extractor that understands complex queries with cause-effect relationships
class SmartComplaintExtractor {
  // Cause-effect indicators
  static const List<String> _causeIndicators = [
    'to', 'isliye', 'because', 'so', 'that\'s why', 'toh', 'therefore',
    'jisse', 'jis se', 'ki wajah se', 'due to', 'kyunki'
  ];

  // Category keywords with priority (lower = more important/root cause)
  static const Map<String, Map<String, dynamic>> _categoryKeywords = {
    'road': {
      'keywords': ['road', 'sadak', 'pothole', 'gadda', 'khadda', 'gaddha', 'hole', 'footpath', 'pavement'],
      'priority': 1,
      'display_name': 'Road/Pothole'
    },
    'water': {
      'keywords': ['water', 'paani', 'pani', 'leak', 'pipe', 'supply', 'tap', 'nal'],
      'priority': 1,
      'display_name': 'Water Supply'
    },
    'electricity': {
      'keywords': ['electricity', 'bijli', 'light', 'wire', 'power', 'current', 'shock', 'cable'],
      'priority': 1,
      'display_name': 'Electricity'
    },
    'garbage': {
      'keywords': ['garbage', 'kachra', 'waste', 'dustbin', 'trash', 'safai', 'cleaning'],
      'priority': 1,
      'display_name': 'Garbage'
    },
    'drainage': {
      'keywords': ['drainage', 'drain', 'naali', 'nali', 'sewage', 'overflow', 'waterlog', 'paani bhara'],
      'priority': 1,
      'display_name': 'Drainage'
    },
    'traffic': {
      'keywords': ['accident', 'crash', 'takkar', 'traffic', 'signal', 'jam'],
      'priority': 2, // Often consequence
      'display_name': 'Traffic'
    },
    'police': {
      'keywords': ['police', 'crime', 'theft', 'chori', 'fight', 'ladai', 'violence'],
      'priority': 1,
      'display_name': 'Police'
    },
    'construction': {
      'keywords': ['construction', 'building', 'imarat', 'collapse', 'unsafe'],
      'priority': 1,
      'display_name': 'Construction'
    },
    'illegal': {
      'keywords': ['illegal', 'encroachment', 'unauthorized', 'kabza'],
      'priority': 1,
      'display_name': 'Illegal Activity'
    },
    'transportation': {
      'keywords': ['bus', 'auto', 'transport', 'rickshaw'],
      'priority': 2,
      'display_name': 'Transportation'
    },
    'cyber': {
      'keywords': ['cyber', 'fraud', 'scam', 'online', 'hack', 'phishing', 'dhokha', 'fake'],
      'priority': 1,
      'display_name': 'Cyber Crime'
    },
  };

  // Severity keywords
  static const Map<String, List<String>> _severityKeywords = {
    'critical': ['accident', 'death', 'maut', 'serious', 'dangerous', 'khatarnak', 'emergency', 'urgent', 'jaan', 'life'],
    'high': ['bahut bada', 'very big', 'bajot baddha', 'huge', 'bada', 'big', 'major'],
    'medium': ['medium', 'normal', 'regular'],
    'low': ['chhota', 'small', 'minor', 'thoda']
  };

  // Subcategory keywords
  static const Map<String, Map<String, List<String>>> _subcategoryKeywords = {
    'road': {
      'pothole': ['pothole', 'gadda', 'khadda', 'gaddha', 'hole'],
      'broken_road': ['broken', 'damaged', 'toota', 'crack'],
      'footpath': ['footpath', 'pavement', 'sidewalk']
    },
    'water': {
      'no_water': ['no water', 'paani nahi', 'supply nahi', 'water nahi'],
      'pipe_leak': ['leak', 'pipe leak', 'pipe toot', 'leakage'],
      'dirty_water': ['dirty', 'ganda paani', 'contaminated']
    },
    'electricity': {
      'power_cut': ['power cut', 'bijli nahi', 'no power', 'blackout'],
      'wire_hanging': ['wire', 'hanging', 'gir gaya', 'loose wire'],
      'street_light': ['street light', 'light not working', 'lamp']
    },
    'garbage': {
      'not_collected': ['not collected', 'nahi uthaya', 'not picked'],
      'overflowing': ['overflow', 'bhar gaya', 'full']
    },
    'drainage': {
      'blocked': ['blocked', 'band', 'clogged'],
      'overflow': ['overflow', 'bhar gaya', 'overflowing']
    },
  };

  // Location patterns
  static final List<RegExp> _locationPatterns = [
    RegExp(r'ghar\s+(?:ke\s+)?(?:paas|pase|pass|ke\s+samne)', caseSensitive: false),
    RegExp(r'near\s+(?:my\s+)?home', caseSensitive: false),
    RegExp(r'(\w+\s+Road)', caseSensitive: false),
    RegExp(r'(\w+\s+Street)', caseSensitive: false),
    RegExp(r'(\w+\s+Chowk)', caseSensitive: false),
    RegExp(r'ke\s+paas\s+(\w+)', caseSensitive: false),
    RegExp(r'near\s+(\w+)', caseSensitive: false),
  ];

  /// Extract complaint data from complex natural language text
  Map<String, dynamic> extract(String text) {
    final textLower = text.toLowerCase();

    // Step 1: Find all matching categories
    final foundCategories = _findAllCategories(textLower);

    // Step 2: Analyze cause-effect relationship
    final primaryCategory = _determinePrimaryCategory(textLower, foundCategories);

    // Step 3: Detect severity and safety risk
    final severityData = _detectSeverity(textLower);

    // Step 4: Extract location
    final location = _extractLocation(text);

    // Step 5: Detect subcategory
    final subcategory = _detectSubcategory(textLower, primaryCategory);

    // Step 6: Build smart description
    final description = _buildSmartDescription(text, foundCategories, primaryCategory);

    return {
      'category': primaryCategory,
      'subcategory': subcategory,
      'severity': severityData['severity'],
      'urgency': severityData['urgency'],
      'safety_risk': severityData['safety_risk'],
      'location': location,
      'description': description,
      'all_issues': foundCategories.map((c) => c['category']).toList(),
      'raw_text': text,
      'category_display': _getCategoryDisplayName(primaryCategory),
    };
  }

  List<Map<String, dynamic>> _findAllCategories(String text) {
    final found = <Map<String, dynamic>>[];

    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final data = entry.value;
      final keywords = data['keywords'] as List<String>;

      for (final keyword in keywords) {
        if (text.contains(keyword)) {
          final position = text.indexOf(keyword);
          found.add({
            'category': category,
            'priority': data['priority'],
            'keyword': keyword,
            'position': position,
          });
          break; // Only add once per category
        }
      }
    }

    return found;
  }

  String _determinePrimaryCategory(String text, List<Map<String, dynamic>> foundCategories) {
    if (foundCategories.isEmpty) return 'other';
    if (foundCategories.length == 1) return foundCategories[0]['category'];

    // Check for cause-effect indicators
    final hasCauseIndicator = _causeIndicators.any((ind) => text.contains(ind));

    if (hasCauseIndicator) {
      // Find position of first cause indicator
      int? causeIndicatorPos;
      for (final indicator in _causeIndicators) {
        if (text.contains(indicator)) {
          final pos = text.indexOf(indicator);
          if (causeIndicatorPos == null || pos < causeIndicatorPos) {
            causeIndicatorPos = pos;
          }
        }
      }

      if (causeIndicatorPos != null) {
        // Categories before the cause indicator are primary (root cause)
        final categoriesBefore = foundCategories
            .where((c) => c['position'] < causeIndicatorPos!)
            .toList();

        if (categoriesBefore.isNotEmpty) {
          // Sort by priority (lower = more important)
          categoriesBefore.sort((a, b) => a['priority'].compareTo(b['priority']));
          return categoriesBefore.first['category'];
        }
      }
    }

    // No cause-effect or no category before indicator - take highest priority
    foundCategories.sort((a, b) => a['priority'].compareTo(b['priority']));
    return foundCategories.first['category'];
  }

  Map<String, dynamic> _detectSeverity(String text) {
    String severity = 'medium';
    String urgency = 'normal';
    bool safetyRisk = false;

    for (final entry in _severityKeywords.entries) {
      final level = entry.key;
      final keywords = entry.value;

      if (keywords.any((kw) => text.contains(kw))) {
        severity = level;
        if (level == 'critical' || level == 'high') {
          urgency = 'high';
          safetyRisk = true;
        }
        break;
      }
    }

    return {
      'severity': severity,
      'urgency': urgency,
      'safety_risk': safetyRisk,
    };
  }

  String? _extractLocation(String text) {
    for (final pattern in _locationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  String _detectSubcategory(String text, String category) {
    if (_subcategoryKeywords.containsKey(category)) {
      final subcats = _subcategoryKeywords[category]!;
      for (final entry in subcats.entries) {
        final subcatKey = entry.key;
        final keywords = entry.value;

        if (keywords.any((kw) => text.contains(kw))) {
          return subcatKey;
        }
      }
    }
    return 'general';
  }

  String _buildSmartDescription(String text, List<Map<String, dynamic>> allCategories, String primaryCategory) {
    if (allCategories.length > 1) {
      // Multiple issues - explain relationship
      final otherCategories = allCategories
          .where((c) => c['category'] != primaryCategory)
          .map((c) => c['category'])
          .toList();

      return '$text (Primary: $primaryCategory, Related: ${otherCategories.join(', ')})';
    }
    return text;
  }

  String _getCategoryDisplayName(String key) {
    if (_categoryKeywords.containsKey(key)) {
      return _categoryKeywords[key]!['display_name'];
    }
    return key;
  }

  /// Get a human-friendly explanation of what was understood
  String getUnderstandingExplanation(Map<String, dynamic> extracted, String language) {
    final category = extracted['category_display'];
    final subcategory = extracted['subcategory'];
    final severity = extracted['severity'];
    final safetyRisk = extracted['safety_risk'] as bool;
    final allIssues = extracted['all_issues'] as List;

    if (language == 'hindi' || language == 'hinglish') {
      String explanation = '';

      if (safetyRisk) {
        explanation += 'Arre yaar! Bahut serious problem hai! ';
      } else {
        explanation += 'Achha, ';
      }

      if (allIssues.length > 1) {
        explanation += 'Main samajh gayi - yeh ek $category ki problem hai jisme ';
        final otherIssues = allIssues.where((i) => i != extracted['category']).join(', ');
        explanation += '$otherIssues bhi involved hai. ';
      } else {
        explanation += 'main samajh gayi - yeh $category category ki problem hai';
        if (subcategory != 'general') {
          explanation += ', specifically $subcategory';
        }
        explanation += '. ';
      }

      if (safetyRisk) {
        explanation += '\n\nYeh dangerous hai, HIGH PRIORITY complaint hai. Jaldi fix hona chahiye.';
      }

      explanation += '\n\nSahi hai na?';

      return explanation;
    } else {
      // English
      String explanation = '';

      if (safetyRisk) {
        explanation += 'This is a serious problem! ';
      } else {
        explanation += 'Okay, ';
      }

      if (allIssues.length > 1) {
        explanation += 'I understand - this is a $category issue that also involves ';
        final otherIssues = allIssues.where((i) => i != extracted['category']).join(', ');
        explanation += '$otherIssues. ';
      } else {
        explanation += 'I understand - this is a $category complaint';
        if (subcategory != 'general') {
          explanation += ', specifically $subcategory';
        }
        explanation += '. ';
      }

      if (safetyRisk) {
        explanation += '\n\nThis is dangerous and HIGH PRIORITY. It needs to be fixed quickly.';
      }

      explanation += '\n\nIs that correct?';

      return explanation;
    }
  }
}
