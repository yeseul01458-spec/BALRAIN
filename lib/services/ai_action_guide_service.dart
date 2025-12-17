
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/action_guide_model.dart';

class AiActionGuideService {
  static final _geminiKey = const String.fromEnvironment('GEMINI_API_KEY');

  static Future<ActionGuide> generateActionGuide({
    required Map<String, dynamic> payload,
  }) async {
    if (_geminiKey.isEmpty) {
      throw Exception(
        kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=...'
            : 'AI 서버 설정이 아직 완료되지 않았어요.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
    );

    // ✅ 모델(ActionGuide.fromJson)이 기대하는 스키마로 고정
    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": """
너는 '밸레인(BALRAIN)' 앱의 'AI 결론 카드(Action Guide)' 전담 AI다.

- 입력으로 tech_1~tech_5 모듈 결과(JSON)가 일부/전부 들어온다.
- 목표는 사용자가 "지금 뭐 해야 하는지"를 한 장 카드로 끝내주는 것이다.
- 반드시 한국어만 사용한다.
- 단정 금지(조건부/가능성 톤 유지).
- 아래 JSON 스키마 그대로만 출력하고 JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "action_guide",
  "title": "AI 결론",
  "action": "enter | wait | avoid 중 하나",
  "badge": "green | yellow | red 중 하나",
  "headline": "한 줄 결론(짧고 강하게)",
  "why": ["근거 1", "근거 2", "근거 3"],
  "dont": ["피해야 할 행동 1", "피해야 할 행동 2"],
  "if_then": [
    {"if": "조건(예: 00원 지지 확인)", "then": "행동(예: 분할 진입)"},
    {"if": "조건", "then": "행동"}
  ],
  "risk_controls": ["리스크 관리 1", "리스크 관리 2"],
  "confidence": 0.0~1.0 사이 숫자,
  "disclaimer": "참고/주의 문장 1~2줄"
}
"""
            },
            {"text": "아래는 입력 payload 입니다:\n${jsonEncode(payload)}"}
          ]
        }
      ],
      "generationConfig": {"responseMimeType": "application/json"}
    };

    final res = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;

    final text = (candidates != null &&
        candidates.isNotEmpty &&
        candidates[0]['content']?['parts'] != null &&
        (candidates[0]['content']['parts'] as List).isNotEmpty)
        ? (candidates[0]['content']['parts'][0]['text'] as String? ?? '')
        : '';

    if (text.isEmpty) throw Exception('Gemini 응답이 비어 있습니다.');

    final j = jsonDecode(text) as Map<String, dynamic>;
    return ActionGuide.fromJson(j);
  }
}
