import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiLiquidityService {
  static final String _geminiKey =
  const String.fromEnvironment('GEMINI_API_KEY');

  /// 3모듈(유동성·거래) 전용 AI 분석 함수
  static Future<String> analyzeLiquidity({
    required String liqSummary,
  }) async {
    if (_geminiKey.isEmpty) {
      if (kDebugMode) {
        throw Exception(
          'GEMINI_API_KEY가 설정되지 않았습니다.\n'
              'flutter run --dart-define=GEMINI_API_KEY=... 로 실행해 주세요.',
        );
      } else {
        throw Exception('AI 서버 설정이 아직 완료되지 않았어요.');
      }
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-2.5-pro:generateContent?key=$_geminiKey',
    );

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 3모듈, '유동성·거래 모듈' 전담 AI다.

- 아래에 주어지는 요약(liq_summary)을 보고,
  이 종목이 실제로 매매하기 편한 종목인지, 한 번에 크게 들어가면 위험한 종목인지,
  유동성·거래대금·최근 활발함 관점에서 해석해라.
- 주식 초보도 이해할 수 있도록, 비유를 섞되 과도하게 유치하진 않게 설명한다.
- '일 단위 스캘핑/단타' 보다는
  '적당히 사고 팔 수 있는지, 들어갔다가 나올 때 미끄러지지 않는지' 관점에 집중해라.
- 반드시 한국어만 사용한다.
- 최대 5문단 이내, 각 문단은 2~3문장으로 짧게 끊어서 써라.
- JSON 없이, 순수 텍스트로만 답한다.
"""
            },
            {
              "text": "아래는 이 종목의 유동성·거래 요약이다:\n$liqSummary"
            }
          ],
        }
      ],
      "generationConfig": {
        "temperature": 0.2,
        "topP": 0.9,
        "maxOutputTokens": 5000,
      }
    };

    final res = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw Exception('Gemini HTTP ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;

    if (candidates == null ||
        candidates.isEmpty ||
        candidates[0]['content'] == null ||
        candidates[0]['content']['parts'] == null ||
        (candidates[0]['content']['parts'] as List).isEmpty) {
      throw Exception('Gemini 응답이 비어 있습니다.');
    }

    final text =
        candidates[0]['content']['parts'][0]['text'] as String? ?? '';

    if (text.trim().isEmpty) {
      throw Exception('Gemini 텍스트 응답이 없습니다.');
    }

    return text.trim();
  }
}