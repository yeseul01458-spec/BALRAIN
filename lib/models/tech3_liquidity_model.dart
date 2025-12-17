class Tech3LiquidityModule {
  final Summary summary;
  final ExpertInsights expertInsights;
  final ActionAdvice actionAdvice;
  final String aiFinalComment;

  Tech3LiquidityModule({
    required this.summary,
    required this.expertInsights,
    required this.actionAdvice,
    required this.aiFinalComment,
  });

  factory Tech3LiquidityModule.fromJson(Map<String, dynamic> json) {
    return Tech3LiquidityModule(
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
      emoji: json['emoji'] ?? '💧',
      oneLine: json['one_line'] ?? '',
    );
  }
}

class ExpertInsights {
  final String volumeView;
  final String tradeValueView;
  final String slippageView;
  final String riskView;

  ExpertInsights({
    required this.volumeView,
    required this.tradeValueView,
    required this.slippageView,
    required this.riskView,
  });

  factory ExpertInsights.fromJson(Map<String, dynamic> json) {
    return ExpertInsights(
      volumeView: json['volume_view'] ?? '',
      tradeValueView: json['trade_value_view'] ?? '',
      slippageView: json['slippage_view'] ?? '',
      riskView: json['risk_view'] ?? '',
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
