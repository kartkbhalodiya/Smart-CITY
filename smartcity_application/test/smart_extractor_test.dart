import '../services/smart_complaint_extractor.dart';

/// Test examples for smart complaint extraction
void main() {
  final extractor = SmartComplaintExtractor();

  print('=== SMART COMPLAINT EXTRACTOR TEST ===\n');

  // Test 1: Complex query with cause-effect
  print('TEST 1: Complex cause-effect query');
  print('Input: "Mera ghar pase bajot baddha gadda he to ek bike ka accident huva"');
  final result1 = extractor.extract('Mera ghar pase bajot baddha gadda he to ek bike ka accident huva');
  print('Category: ${result1['category']}');
  print('Subcategory: ${result1['subcategory']}');
  print('Severity: ${result1['severity']}');
  print('Safety Risk: ${result1['safety_risk']}');
  print('Location: ${result1['location']}');
  print('All Issues: ${result1['all_issues']}');
  print('Description: ${result1['description']}');
  print('\nAI Understanding (Hindi):');
  print(extractor.getUnderstandingExplanation(result1, 'hindi'));
  print('\n---\n');

  // Test 2: Water leak causing road flooding
  print('TEST 2: Water leak causing drainage issue');
  print('Input: "Paani ki pipe leak ho rahi hai to sadak pe paani bhar gaya hai"');
  final result2 = extractor.extract('Paani ki pipe leak ho rahi hai to sadak pe paani bhar gaya hai');
  print('Category: ${result2['category']}');
  print('Subcategory: ${result2['subcategory']}');
  print('Severity: ${result2['severity']}');
  print('All Issues: ${result2['all_issues']}');
  print('\nAI Understanding (Hindi):');
  print(extractor.getUnderstandingExplanation(result2, 'hindi'));
  print('\n---\n');

  // Test 3: Dangerous wire
  print('TEST 3: Dangerous hanging wire');
  print('Input: "Bijli ka wire gir gaya hai to koi touch kare to shock lag sakta hai"');
  final result3 = extractor.extract('Bijli ka wire gir gaya hai to koi touch kare to shock lag sakta hai');
  print('Category: ${result3['category']}');
  print('Subcategory: ${result3['subcategory']}');
  print('Severity: ${result3['severity']}');
  print('Safety Risk: ${result3['safety_risk']}');
  print('Urgency: ${result3['urgency']}');
  print('\nAI Understanding (Hindi):');
  print(extractor.getUnderstandingExplanation(result3, 'hindi'));
  print('\n---\n');

  // Test 4: Simple query
  print('TEST 4: Simple pothole query');
  print('Input: "MG Road pe bada pothole hai"');
  final result4 = extractor.extract('MG Road pe bada pothole hai');
  print('Category: ${result4['category']}');
  print('Subcategory: ${result4['subcategory']}');
  print('Severity: ${result4['severity']}');
  print('Location: ${result4['location']}');
  print('\nAI Understanding (Hindi):');
  print(extractor.getUnderstandingExplanation(result4, 'hindi'));
  print('\n---\n');

  // Test 5: Garbage overflow
  print('TEST 5: Garbage overflow');
  print('Input: "Dustbin overflow ho gaya hai bahut ganda smell aa raha"');
  final result5 = extractor.extract('Dustbin overflow ho gaya hai bahut ganda smell aa raha');
  print('Category: ${result5['category']}');
  print('Subcategory: ${result5['subcategory']}');
  print('Severity: ${result5['severity']}');
  print('\nAI Understanding (English):');
  print(extractor.getUnderstandingExplanation(result5, 'english'));
  print('\n---\n');

  // Test 6: Multiple issues in one sentence
  print('TEST 6: Multiple related issues');
  print('Input: "Road toota hua hai aur usme paani bhi bhara hai"');
  final result6 = extractor.extract('Road toota hua hai aur usme paani bhi bhara hai');
  print('Category: ${result6['category']}');
  print('Subcategory: ${result6['subcategory']}');
  print('All Issues: ${result6['all_issues']}');
  print('\nAI Understanding (Hindi):');
  print(extractor.getUnderstandingExplanation(result6, 'hindi'));
  print('\n---\n');

  print('=== ALL TESTS COMPLETED ===');
}

/// Expected Output:
/// 
/// TEST 1: Complex cause-effect query
/// Category: road
/// Subcategory: pothole
/// Severity: critical
/// Safety Risk: true
/// Location: ghar pase
/// All Issues: [road, traffic]
/// Description: Mera ghar pase bajot baddha gadda he to ek bike ka accident huva (Primary: road, Related: traffic)
/// 
/// AI Understanding (Hindi):
/// Arre yaar! Bahut serious problem hai! Main samajh gayi - yeh ek Road/Pothole ki problem hai jisme traffic bhi involved hai. 
/// 
/// Yeh dangerous hai, HIGH PRIORITY complaint hai. Jaldi fix hona chahiye.
/// 
/// Sahi hai na?
/// 
/// ---
/// 
/// TEST 2: Water leak causing drainage issue
/// Category: water
/// Subcategory: pipe_leak
/// Severity: medium
/// All Issues: [water, drainage]
/// 
/// AI Understanding (Hindi):
/// Achha, main samajh gayi - yeh ek Water Supply ki problem hai jisme drainage bhi involved hai. 
/// 
/// Sahi hai na?
