/// 3모듈: 유동성·거래 구조 진단 스펙 정의 파일
///
/// 이 파일은 "AI에게 어떤 역할을 시키고, 어떤 기준으로, 어떤 출력 형식을 만들지"
/// 를 정리한 **설계(Spec)** 파일이다.
/// 실제 API 호출은 AiLiquidityService.dart가 담당한다.

enum LiquidityModuleGrade {
  a,  // 유동성 우위 — 들어갔다 나오기 편한 장
  b,  // 중립 — 좋아 보이지만 흔들림 존재
  c,  // 유동성 열위 — 청산 리스크 높음
}

extension LiquidityModuleGradeExtension on LiquidityModuleGrade {
  String get label {
    switch (this) {
      case LiquidityModuleGrade.a:
        return 'A등급 – 유동성 우위';
      case LiquidityModuleGrade.b:
        return 'B등급 – 중립';
      case LiquidityModuleGrade.c:
        return 'C등급 – 유동성 열위';
    }
  }
}

/// 모듈 3: 유동성·거래 구조 진단
class LiquidityModuleSpec {
  /// 내부 ID
  static const String id = 'liquidity';

  /// 사용자에게 보이는 이름
  static const String title = '유동성·거래 구조 진단';

  /// 모듈 분류
  static const String group = '기술';

  /// 짧은 설명
  static const String shortDescription =
      '거래대금·스프레드·호가창을 바탕으로 매매하기 좋은 장인지 해석하는 모듈';

  /// Gemini 2.5용 프롬프트 템플릿
  static const String promptTemplate = '''
### 역할
너는 글로벌 매크로 헤지펀드에서 활동하는 Market Microstructure 전문가다.
주식의 유동성 구조가 "들어갔다 나오기 쉬운 장인지"를 기술적 지표만으로 판단하라.

### 입력 데이터
{LIQ_SUMMARY}

### 평가 축
1) 표면 유동성 (거래대금·체결량)
2) 심층 유동성 (스프레드·호가창 뎁스)
3) 수급 안정성 (단층·휩쏘 발생 여부)

### 출력 형식
1. 기술 코멘트:
   - 3~5문장
   - 현재 유동성 수준·스프레드 안정성·호가창 구조·체결 리스크 설명

2. 트레이딩 전략:
   - 액션: "매수 관점" / "부분 청산 관점" / "관망·보류 관점" 중 하나
   - 근거: 숫자 기반으로 2~3문장 설명
   - 계획: 진입/청산 적합 가격대 또는 리스크 기준 한 줄

3. 등급:
   - A등급 / B등급 / C등급 중 하나

주의:
- 모든 판단은 기술적 가능성에 기반하며 확정적 예측이나 투자 권유가 아니다.
''';
}
