import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'call_conversation_manager.dart';

class VoiceDebugExportService {
  static const String _fileName = 'test.json';

  static Future<String> saveSnapshot({
    required String sessionId,
    required VoiceCallStage stage,
    required VoiceComplaintDraft draft,
    required List<Map<String, String>> conversationHistory,
    required Map<String, String> apiPayload,
    required bool canSubmit,
    required List<String> missingFields,
    String event = 'update',
    String? statusText,
    String? submissionError,
    String? complaintId,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');

    final payload = <String, dynamic>{
      'saved_at': DateTime.now().toIso8601String(),
      'event': event,
      'session_id': sessionId,
      'stage': stage.toString().split('.').last,
      'status_text': statusText ?? '',
      'submission_error': submissionError ?? '',
      'complaint_id': complaintId ?? '',
      'can_submit': canSubmit,
      'missing_fields': missingFields,
      'draft': draft.toDebugJson(),
      'api_payload_preview': apiPayload,
      'conversation_history': conversationHistory,
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );

    debugPrint('[VoiceDebugExport] Saved snapshot to ${file.path}');
    return file.path;
  }
}
