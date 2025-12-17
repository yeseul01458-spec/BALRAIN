
class ExpertSummary {
  final String grade;     // "A", "B", ...
  final String label;     // "전문가 관점 강한 상승 흐름"
  final String emoji;     // "📈"
  final String oneLine;   // 한 줄 요약

  ExpertSummary({
    required this.grade,
    required this.label,
    required this.emoji,
    required this.oneLine,
  });

  factory ExpertSummary.fromJson(Map<String, dynamic> json) {
    return ExpertSummary(
      grade: json['grade'] as String,
      label: json['label'] as String,
      emoji: json['emoji'] as String,
      oneLine: json['one_line'] as String,
    );
  }
}

class ExpertInsights {
  final String patternView;    // 패턴 관점
  final String momentumView;   // 모멘텀 관점
  final String liquidityView;  // 유동성 관점
  final String riskView;       // 리스크 관점

  ExpertInsights({
    required this.patternView,
    required this.momentumView,
    required this.liquidityView,
    required this.riskView,
  });

  factory ExpertInsights.fromJson(Map<String, dynamic> json) {
    return ExpertInsights(
      patternView: json['pattern_view'] as String,
      momentumView: json['momentum_view'] as String,
      liquidityView: json['liquidity_view'] as String,
      riskView: json['risk_view'] as String,
    );
  }
}

class ExpertActionAdvice {
  final String shortTerm;  // 단기 / 트레이딩
  final String midTerm;    // 중기 / 스윙
  final String avoid;      // 피해야 할 행동

  ExpertActionAdvice({
    required this.shortTerm,
    required this.midTerm,
    required this.avoid,
  });

  factory ExpertActionAdvice.fromJson(Map<String, dynamic> json) {
    return ExpertActionAdvice(
      shortTerm: json['short_term'] as String,
      midTerm: json['mid_term'] as String,
      avoid: json['avoid'] as String,
    );
  }
}

class Tech2ExpertModule {
  final String moduleId;          // "tech_2_expert_view"
  final String moduleType;        // "technical"
  final String title;             // "변동성 모듈"
  final ExpertSummary summary;
  final ExpertInsights expertInsights;
  final ExpertActionAdvice actionAdvice;
  final String aiFinalComment;

  Tech2ExpertModule({
    required this.moduleId,
    required this.moduleType,
    required this.title,
    required this.summary,
    required this.expertInsights,
    required this.actionAdvice,
    required this.aiFinalComment,
  });

  factory Tech2ExpertModule.fromJson(Map<String, dynamic> json) {
    return Tech2ExpertModule(
      moduleId: json['module_id'] as String,
      moduleType: json['module_type'] as String,
      title: json['title'] as String,
      summary: ExpertSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      expertInsights: ExpertInsights.fromJson(
        json['expert_insights'] as Map<String, dynamic>,
      ),
      actionAdvice: ExpertActionAdvice.fromJson(
        json['action_advice'] as Map<String, dynamic>,
      ),
      aiFinalComment: json['ai_final_comment'] as String,
    );
  }
}
