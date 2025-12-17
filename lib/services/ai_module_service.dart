
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 밸레인 AI 모듈 요청 서비스
/// - "GEMINI_API_KEY" 를 사용하는 Google Gemini API를 호출해서
///   '기술 2 - 변동성 모듈' JSON을 받아온다.
class AiModuleService {
  final String apiKey;

  AiModuleService({required this.apiKey});

  /// 기술 2 - 변동성 모듈 (정식 이름)
  ///
  /// [symbol]  예: "NVDA", "005930.KS"
  /// [timeframe] 예: "1d", "1h"
  Future<Map<String, dynamic>> fetchTech2VolatilityModule({
    required String symbol,
    required String timeframe,
  }) async {
    // Gemini 2.5 Flash 엔드포인트 (v1beta)
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
          '?key=$apiKey',
    );

    /// 요청 바디
    /// - responseMimeType 을 application/json 으로 설정해서
    ///   모델이 "순수 JSON"만 반환하도록 강하게 유도
    final requestBody = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 2 모듈, 즉 '변동성 모듈' 전담 AI다.

▼ 너의 역할
- 한 종목의 변동성과 리스크 프로파일을 직관적으로 정리해 주는 것.
- 사용자는 캔들 차트와 네 해석을 같이 보면서
  “지금 이 종목이 얼마나 흔들리는 구간인지”를 감으로 이해하려고 한다.
- 반드시 한국어로만 답변한다.

▼ 변동성 모듈이 참고해야 할 관점 (개념 기준)
- ATR(14) : 최근 14일 평균 변동폭이 큰지/작은지
- 20일 역사적 변동성(HV20) : 일간 수익률 기준 변동성 수준
- 볼린저 밴드 폭(Bollinger Band Width) : 가격이 밴드 안에서 얼마나 요동치는지
- 최근 급등/급락 캔들의 빈도
- 갭 상승/하락 발생 여부
- 변동성이 상승 중인지, 안정화되는 중인지의 추세

(실제 수치가 정확하지 않아도 되지만,
"저/중/고" 수준과 그에 대한 해석을 설득력 있게 써라.)

▼ 출력 형식
- 반드시 아래 JSON 스키마를 그대로 지키고,
  JSON 이외의 텍스트(설명, 인사말 등)는 절대 출력하지 마라.

{
  "module_id": "tech_2_volatility",
  "module_type": "technical",
  "title": "변동성·리스크 모듈",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "level": "매우 낮음 | 낮음 | 보통 | 높음 | 매우 높음 중 하나",
    "emoji": "⚡ 같은 이모지 하나",
    "one_line": "지금 변동성 상태를 한 줄로 설명"
  },
  "volatility_view": {
    "atr_comment": "ATR(14) 관점에서 변동폭을 해석 (예: '최근 2주간 일간 변동폭이 평소보다 다소 커진 상태입니다')",
    "hv20_comment": "20일 역사적 변동성 관점에서의 해석",
    "bandwidth_comment": "볼린저 밴드 폭과 밴드 터치 여부를 해석",
    "regime_comment": "지금이 조용한 구간인지, 요동치는 구간인지, 변동성이 커지는 추세인지 등"
  },
  "risk_profile": {
    "drawdown_risk": "단기간에 얼마나 크게 밀릴 수 있는지에 대한 설명",
    "spike_risk": "장중 급등/급락 같은 스파이크 리스크 설명",
    "gap_risk": "갭 상승/갭 하락 가능성 및 과거 패턴에 대한 언급",
    "who_should_be_careful": "어떤 투자자가 특히 조심해야 하는지 (단타/스윙/장기 등)"
  },
  "action_advice": {
    "for_traders": "단기/트레이더 관점에서 포지션 사이즈, 진입/청산 타이밍, 손절 여유 폭 등에 대한 가이드",
    "for_investors": "중장기 투자자 관점에서 변동성을 어떻게 받아들여야 할지에 대한 가이드",
    "avoid": "지금 피해야 할 행동 (예: 과도한 레버리지, 갭 직후 추격매수 등)"
  },
  "ai_final_comment": "변동성과 리스크 관점에서 전문가가 마지막으로 남기는 총평 한 단락"
}

- 모든 문장은 실제 트레이더/리스크 매니저가 말하는 것처럼 자연스럽고 구체적으로 써라.
- 과도한 확신은 피하고, '가능성'과 '조건'을 함께 언급해라.
- 가격 방향(상승/하락)을 단정하지 말고, '이런 상황에서는 변동성이 이렇게 작동할 수 있다'는 식으로 서술하라.
"""
            },
            {
              // 심볼 / 타임프레임 정보는 JSON 문자열로 한 번 더 넘겨줌
              "text": jsonEncode({
                "symbol": symbol,
                "timeframe": timeframe,
              }),
            }
          ],
        },
      ],
      "generationConfig": {
        "responseMimeType": "application/json",
      },
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API Error: ${response.statusCode} / ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답에 candidates 가 없습니다: ${response.body}');
    }

    // Gemini 응답 구조:
    // candidates[0].content.parts[0].text 가 우리가 요청한 JSON 문자열
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini 응답에 parts 가 없습니다: ${response.body}');
    }

    final text = (parts.first as Map<String, dynamic>)['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini 응답 text 가 비어 있습니다: ${response.body}');
    }

    // text 자체가 JSON 문자열이라고 가정 (responseMimeType: application/json 덕분에)
    final Map<String, dynamic> moduleJson =
    jsonDecode(text) as Map<String, dynamic>;

    return moduleJson;
  }

  /// 과거에 내가 '전문가 빙의 모듈' 이름으로 썼을 수도 있으니까
  /// 혹시나 그 함수를 이미 참조하고 있다면 깨지지 않도록
  /// 그대로 래핑해서 변동성 모듈을 호출하게 만든다.
  Future<Map<String, dynamic>> fetchTech2ExpertModule({
    required String symbol,
    required String timeframe,
  }) {
    return fetchTech2VolatilityModule(symbol: symbol, timeframe: timeframe);
  }
}