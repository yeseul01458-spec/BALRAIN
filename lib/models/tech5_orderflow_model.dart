class Tech5OrderflowModule {
  final Summary summary;
  final ExpertInsights expertInsights;
  final ActionAdvice actionAdvice;
  final String aiFinalComment;

  Tech5OrderflowModule({
    required this.summary,
    required this.expertInsights,
    required this.actionAdvice,
    required this.aiFinalComment,
  });

  factory Tech5OrderflowModule.fromJson(Map<String, dynamic> json) {
    return Tech5OrderflowModule(
      summary: Summary.fromJson(json['summary'] ?? {}),
      expertInsights: ExpertInsights.fromJson(json['expert_insights'] ?? {}),
      actionAdvice: ActionAdvice.fromJson(json['action_advice'] ?? {}),
      aiFinalComment: json['ai_final_comment'] ?? '',
    );
  }
}

class Summary {
  final String grade;
  final String label;
  final String emoji;
  final String oneLine;

  Summary({
    required this.grade,
    required this.label,
    required this.emoji,
    required this.oneLine,
  });

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      grade: json['grade'] ?? '',
      label: json['label'] ?? '',
      emoji: json['emoji'] ?? '⚡',
      oneLine: json['one_line'] ?? '',
    );
  }
}

class ExpertInsights {
  final String spreadPressureView;
  final String tradeIntensityView;
  final String liquidityRiskView;
  final String trapView;

  ExpertInsights({
    required this.spreadPressureView,
    required this.tradeIntensityView,
    required this.liquidityRiskView,
    required this.trapView,
  });

  factory ExpertInsights.fromJson(Map<String, dynamic> json) {
    return ExpertInsights(
      spreadPressureView: json['spread_pressure_view'] ?? '',
      tradeIntensityView: json['trade_intensity_view'] ?? '',
      liquidityRiskView: json['liquidity_risk_view'] ?? '',
      trapView: json['trap_view'] ?? '',
    );
  }
}

class ActionAdvice {
  final String shortTerm;
  final String midTerm;
  final String avoid;

  ActionAdvice({
    required this.shortTerm,
    required this.midTerm,
    required this.avoid,
  });

  factory ActionAdvice.fromJson(Map<String, dynamic> json) {
    return ActionAdvice(
      shortTerm: json['short_term'] ?? '',
      midTerm: json['mid_term'] ?? '',
      avoid: json['avoid'] ?? '',
    );
  }
}
