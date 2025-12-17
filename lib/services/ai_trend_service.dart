
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 기술 1모듈(추세·모멘텀) 전용 AI 서비스
class AiTrendService {
  AiTrendService._();

  // flutter run 시에 --dart-define=GEMINI_API_KEY=... 로 넘기는 값
  static final String _geminiKey =
  const String.fromEnvironment('GEMINI_API_KEY');

  /// priceSummary(일봉 요약 텍스트)를 받아서
  /// "추세·모멘텀 리포트" 한 덩어리 텍스트로 돌려준다.
  static Future<String> analyzeTrend({
    required String priceSummary,
  }) async {
    if (_geminiKey.isEmpty) {
      throw Exception(
        kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\n'
            'flutter run --dart-define=GEMINI_API_KEY=... 로 실행해 주세요.'
            : 'AI 서버 설정이 아직 완료되지 않았어요.',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-2.5-flash:generateContent?key=$_geminiKey',
    );

    // 전문 트레이더 리포트 느낌으로, 섹션 구조까지 정리
    const prompt = '''
너는 '밸레인(BALRAIN)' 앱의 기술 1모듈, '추세·모멘텀 분석 모듈' 전담 AI다.

- price_summary를 기반으로 이 종목의 추세와 모멘텀을 전문적으로 분석해라.
- 주식 초보도 읽으면 이해되지만, 내용은 실전 트레이더 리포트 수준으로 깊이 있게 설명해라.
- 과도한 확신(무조건 오른다/무조건 떨어진다)은 피하고, 항상 "시나리오 + 조건" 형태로 말해라.
- 아래 섹션 제목을 그대로 사용해서 리포트 형태로 한국어로만 작성해라.
- 최대한의 이익과 수익을 위한 관점해서 조언해라
[섹션 구조]

1. 📌 한 줄 요약
   - 현재 추세·모멘텀을 한 줄로 정리 (예: "우상향 추세 속 단기 과열 구간" 등)

2. ⏱ 멀티 타임프레임 뷰
   - 단기(5~20일): 단기 흐름, 단기 매매 관점
   - 중기(1~3개월): 스윙/포지션 관점
   - 장기(6~12개월): 큰 추세·사이클 관점

3. 🔍 패턴·위치 인사이트
   - 추세선, 박스권, 돌파/이탈, 눌림, 고점/저점 재시험 등
   - 52주 고저 대비 현재 위치를 "위/아래 공간" 관점으로 설명

4. ⚡ 모멘텀·힘 인사이트
   - 상승/하락 힘, 속도, 피로도
   - 과열/침체 여부, 힘이 살아나는지/꺼지는지

5. 🎯 트레이드 플랜
   - 보유자 전략: 어디까지는 홀딩, 어디부터는 경계해야 하는지
   - 신규 진입 전략: 어떤 구간/패턴에서만 진입을 고려할지
   - 분할 매수/매도 전략: 비중을 어떻게 나눌지
   - 시나리오 무효 기준: 어떤 가격대/상황이면 이 분석이 깨졌다고 봐야 하는지

6. 🧾 AI 총평
   - 위 내용을 하나의 스토리로 정리한 3~5문장 정도의 요약

주의:
- 너무 장황하게 쓰지 말고, 각 소항목은 2~4문장 안에서 정리해라.
- 단기 트레이딩과 중기 투자자가 각각 어떤 마음가짐과 계획을 세워야 하는지
  "행동" 관점에서 분명하게 적어라.
''';

    final body = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text":
              '$prompt\n\n아래는 이 종목의 일봉·수익률 요약 데이터다.\n\n$priceSummary'
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.4,
        "topP": 0.8,
        "topK": 40,
        "maxOutputTokens": 5000
      }
    };

    final res = await http
        .post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
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