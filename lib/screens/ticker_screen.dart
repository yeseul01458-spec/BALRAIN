// lib/screens/ticker_screen.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/stock_models.dart';
import '../theme/app_colors.dart';
import '../widgets/candle_chart.dart';
import '../services/ai_trend_service.dart'; // (유지) 현재 파일에서는 직접 사용 안 해도 됨
import '../modules/trend_module_spec.dart';

import '../services/ai_liquidity_service.dart'; // (유지) 현재 파일에서는 직접 사용 안 해도 됨
import '../modules/liquidity_module_spec.dart';

import '../services/ai_orderflow_service.dart'; // (유지) 현재 파일에서는 직접 사용 안 해도 됨
import '../modules/orderflow_module_spec.dart'; // (유지) 현재 파일에서는 직접 사용 안 해도 됨

import '../services/ai_action_guide_service.dart'; // (유지) 현재 파일에서는 직접 사용 안 해도 됨
import '../models/action_guide_model.dart';
import '../widgets/action_guide_card.dart';

import '../models/tech1_trend_model.dart';
import '../models/tech3_liquidity_model.dart';
import '../models/tech4_range_level_model.dart';
import '../models/tech5_orderflow_model.dart';
import '../theme/app_colors.dart';

/* ================================ TICKER / CHART ================================ */

enum ChartMode { daily, intraday }
enum ModuleCategory { tech, fund, external, psych }

class TickerScreen extends StatefulWidget {
  final String symbol;
  final String? description;
  const TickerScreen({super.key, required this.symbol, this.description});

  @override
  State<TickerScreen> createState() => _TickerScreenState();
}

class _TickerScreenState extends State<TickerScreen> {
  // ✅ withOpacity deprecate 회피용
  Color _a(Color c, double opacity) {
    final v = (opacity * 255).round().clamp(0, 255);
    return c.withAlpha(v);
  }

  TextStyle _t({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = kInk,
    double? height,
  }) {
    return GoogleFonts.notoSansKr(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  bool get _hasAnyTechJson =>
      _tech1Json != null ||
          _tech2Json != null ||
          _tech3Json != null ||
          _tech4Json != null ||
          _tech5Json != null;

  // ===== Action Guide =====
  ActionGuide? _actionGuide;
  bool _actionGuideLoading = false;
  String? _actionGuideError;

  // 모듈 원본 JSON 저장(추후 액션가이드에 넘기기 위함)
  Map<String, dynamic>? _tech1Json;
  Map<String, dynamic>? _tech2Json;
  Map<String, dynamic>? _tech3Json;
  Map<String, dynamic>? _tech4Json;
  Map<String, dynamic>? _tech5Json;

  // 중복 호출 방지(같은 조합이면 다시 안 돌림)
  String? _actionGuideLastKey;

  // “하나라도 JSON 있으면 ActionGuide 돌릴 자격” 체크


  String _buildActionGuideKey() {
    // 심볼 + 어떤 모듈 결과가 있는지로 키 구성 (중복 호출 방지)
    final flags = [
      _tech1Json != null ? '1' : '0',
      _tech2Json != null ? '1' : '0',
      _tech3Json != null ? '1' : '0',
      _tech4Json != null ? '1' : '0',
      _tech5Json != null ? '1' : '0',
    ].join();
    return '${widget.symbol}::$flags';
  }

  Future<void> _maybeRunActionGuide({bool force = false}) async {
    if (!_hasAnyTechJson) return;
    if (_actionGuideLoading) return;

    final key = _buildActionGuideKey();
    if (!force && _actionGuideLastKey == key && _actionGuide != null) return;

    setState(() {
      _actionGuideLoading = true;
      _actionGuideError = null;
      _actionGuideLastKey = key;
    });

    try {
      // ✅ 서비스에 넘길 payload 구성
      final payload = <String, dynamic>{
        "symbol": widget.symbol,
        "description": widget.description ?? "",
        "tech_1": _tech1Json,
        "tech_2": _tech2Json,
        "tech_3": _tech3Json,
        "tech_4": _tech4Json,
        "tech_5": _tech5Json,
      };

      final guide = await AiActionGuideService.generateActionGuide(payload: payload);

      if (!mounted) return;
      setState(() {
        _actionGuide = guide;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionGuideError = 'AI 종합 생성 실패: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _actionGuideLoading = false;
        });
      }
    }
  }

  static const _apiBase = 'https://finnhub.io/api/v1';
  static final _token = const String.fromEnvironment('FINNHUB_TOKEN');
  static final _geminiKey = const String.fromEnvironment('GEMINI_API_KEY');

  late Future<List<Candle>> _dailyFuture;
  late Future<List<Candle>> _intradayFuture;
  ChartMode _mode = ChartMode.daily;

  ModuleCategory _selectedCategory = ModuleCategory.tech;
  int _selectedModuleIndex = 0;

  final Map<ModuleCategory, List<String>> _moduleNames = {
    ModuleCategory.tech: [
      '1모듈 · 추세·모멘텀',
      '2모듈 · 변동성',
      '3모듈 · 유동성·거래',
      '4모듈 · 레인지·레벨',
      '5모듈 · 호가·체결 흐름',
    ],
    ModuleCategory.fund: ['1모듈 · 펀더멘털·밸류에이션 (준비중)'],
    ModuleCategory.external: ['1모듈 · 거시·섹터·수급 (준비중)'],
    ModuleCategory.psych: ['1모듈 · 심리·행동 (준비중)'],
  };

  // ===== 1모듈(추세·모멘텀) =====
  Tech1TrendModule? _tech1Module;
  bool _trendLoading = false;
  String? _trendError;

  // ===== 2모듈(변동성) =====
  Tech2ExpertModule? _tech2Module;
  bool _tech2Loading = false;
  String? _tech2Error;

  // ===== 3모듈(유동성·거래) =====
  Tech3LiquidityModule? _tech3Module;
  bool _liquidityLoading = false;
  String? _liquidityError;

  // ===== 4모듈(레인지·레벨) =====
  Tech4RangeLevelModule? _tech4Module;
  bool _tech4Loading = false;
  String? _tech4Error;

  // ===== 5모듈(호가·체결 흐름) =====
  Tech5OrderflowModule? _tech5Module;
  bool _tech5Loading = false;
  String? _tech5Error;

  @override
  void initState() {
    super.initState();

    _dailyFuture = _fetchDailyCandlesAny(widget.symbol, days: 400);
    _intradayFuture = _fetchIntradayAny(widget.symbol);

    // ✅ 일봉 준비되면 1모듈 자동 실행
    _dailyFuture.then((candles) {
      if (!mounted || candles.isEmpty) return;
      _runTech1ModuleWithDaily();
    }).catchError((_) {});
  }


  /* ================================ PRICE DATA FETCH ================================ */

  Future<List<Candle>> _fetchDailyCandlesFinnhub(String symbol, {int days = 400}) async {
    if (_token.isEmpty) {
      throw Exception(
        kDebugMode ? 'API 키가 없습니다.(FINNHUB_TOKEN 미설정)' : '시세 서버 설정이 아직 완료되지 않았어요.',
      );
    }
    final now = DateTime.now().toUtc();
    final from = now.subtract(Duration(days: days + 10));
    int toUnix(DateTime d) => (d.millisecondsSinceEpoch / 1000).floor();
    final uri = Uri.parse(
      '$_apiBase/stock/candle?symbol=$symbol&resolution=D&from=${toUnix(from)}&to=${toUnix(now)}&token=$_token',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final j = jsonDecode(res.body);
    if (j is! Map || j['s'] != 'ok') {
      throw Exception('Finnhub 응답 오류: ${j is Map ? j['s'] : 'unknown'}');
    }
    final t = (j['t'] as List).cast<int>();
    final o = (j['o'] as List).cast<num>();
    final h = (j['h'] as List).cast<num>();
    final l = (j['l'] as List).cast<num>();
    final c = (j['c'] as List).cast<num>();
    final v = (j['v'] as List).cast<num>();
    return List.generate(
      t.length,
          (i) => Candle(
        DateTime.fromMillisecondsSinceEpoch(t[i] * 1000, isUtc: true).toLocal(),
        o[i].toDouble(),
        h[i].toDouble(),
        l[i].toDouble(),
        c[i].toDouble(),
        v[i].toDouble(),
      ),
    );
    // ignore: dead_code
  }

  Future<List<Candle>> _fetchDailyCandlesYahoo(String symbol, {int days = 400}) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(Duration(days: days + 10));
    int toUnix(DateTime d) => (d.millisecondsSinceEpoch / 1000).floor();
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?period1=${toUnix(from)}&period2=${toUnix(now)}&interval=1d',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Yahoo HTTP ${res.statusCode}');
    final j = jsonDecode(res.body);
    final result = (j['chart']?['result'] as List?)?.first;
    if (result == null) throw Exception('Yahoo no data');

    final timestamps = (result['timestamp'] as List?)?.cast<int>() ?? [];
    final q = result['indicators']?['quote']?[0] as Map?;
    if (timestamps.isEmpty || q == null) throw Exception('Yahoo malformed');

    final opens = (q['open'] as List?)?.cast<num?>() ?? [];
    final highs = (q['high'] as List?)?.cast<num?>() ?? [];
    final lows = (q['low'] as List?)?.cast<num?>() ?? [];
    final closes = (q['close'] as List?)?.cast<num?>() ?? [];
    final vols = (q['volume'] as List?)?.cast<num?>() ?? [];

    final out = <Candle>[];
    for (int i = 0; i < timestamps.length; i++) {
      if (i >= opens.length || opens[i] == null) continue;
      out.add(
        Candle(
          DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000, isUtc: true).toLocal(),
          opens[i]!.toDouble(),
          (i < highs.length && highs[i] != null) ? highs[i]!.toDouble() : opens[i]!.toDouble(),
          (i < lows.length && lows[i] != null) ? lows[i]!.toDouble() : opens[i]!.toDouble(),
          (i < closes.length && closes[i] != null) ? closes[i]!.toDouble() : opens[i]!.toDouble(),
          (i < vols.length && vols[i] != null) ? vols[i]!.toDouble() : 0.0,
        ),
      );
    }
    return out;
  }

  Future<List<Candle>> _tryYahooDailyWithKorea(String symbol, {int days = 400}) async {
    if (RegExp(r'^\d{6}$').hasMatch(symbol)) {
      try {
        return await _fetchDailyCandlesYahoo('$symbol.KS', days: days);
      } catch (_) {
        return await _fetchDailyCandlesYahoo('$symbol.KQ', days: days);
      }
    }
    return _fetchDailyCandlesYahoo(symbol, days: days);
  }

  Future<List<Candle>> _fetchDailyCandlesAny(String symbol, {int days = 400}) async {
    try {
      final r = await _fetchDailyCandlesFinnhub(symbol, days: days);
      if (r.isNotEmpty) return r;
      return await _tryYahooDailyWithKorea(symbol, days: days);
    } catch (_) {
      return await _tryYahooDailyWithKorea(symbol, days: days);
    }
  }

  Future<List<Candle>> _fetchIntradayYahoo(String symbol) async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=5d&interval=5m',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Yahoo HTTP ${res.statusCode}');
    final j = jsonDecode(res.body);
    final result = (j['chart']?['result'] as List?)?.first;
    if (result == null) throw Exception('Yahoo no data (intraday)');

    final timestamps = (result['timestamp'] as List?)?.cast<int>() ?? [];
    final q = result['indicators']?['quote']?[0] as Map?;
    if (timestamps.isEmpty || q == null) throw Exception('Yahoo malformed (intraday)');

    final opens = (q['open'] as List?)?.cast<num?>() ?? [];
    final highs = (q['high'] as List?)?.cast<num?>() ?? [];
    final lows = (q['low'] as List?)?.cast<num?>() ?? [];
    final closes = (q['close'] as List?)?.cast<num?>() ?? [];
    final vols = (q['volume'] as List?)?.cast<num?>() ?? [];

    final out = <Candle>[];
    for (int i = 0; i < timestamps.length; i++) {
      if (i >= opens.length || opens[i] == null) continue;
      out.add(
        Candle(
          DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000, isUtc: true).toLocal(),
          opens[i]!.toDouble(),
          (i < highs.length && highs[i] != null) ? highs[i]!.toDouble() : opens[i]!.toDouble(),
          (i < lows.length && lows[i] != null) ? lows[i]!.toDouble() : opens[i]!.toDouble(),
          (i < closes.length && closes[i] != null) ? closes[i]!.toDouble() : opens[i]!.toDouble(),
          (i < vols.length && vols[i] != null) ? vols[i]!.toDouble() : 0.0,
        ),
      );
    }
    return out;
  }

  Future<List<Candle>> _fetchIntradayAny(String symbol) async {
    if (RegExp(r'^\d{6}$').hasMatch(symbol)) {
      try {
        return await _fetchIntradayYahoo('$symbol.KS');
      } catch (_) {
        return await _fetchIntradayYahoo('$symbol.KQ');
      }
    }
    return _fetchIntradayYahoo(symbol);
  }

  /* ================================ MODULE RUNNERS ================================ */

  Future<void> _runTech1ModuleWithDaily() async {
    if (_geminiKey.isEmpty) {
      setState(() {
        _trendError = kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=...'
            : 'AI 서버 설정이 아직 완료되지 않았어요.';
      });
      return;
    }

    setState(() {
      _trendLoading = true;
      _trendError = null;
    });

    try {
      final candles = await _dailyFuture;
      if (!mounted || candles.isEmpty) return;

      final priceSummary = _buildPriceSummary(candles);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
      );

      final body = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 1모듈, '추세·모멘텀 모듈' 전담 AI다.

- 아래 price_summary를 보고 "방향(상/하/횡보)", "힘(모멘텀)", "현재 위치(고점권/저점권/중앙)", "리스크(눌림/되돌림 가능성)"를 해석해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고 조건부로 말한다.
- 아래 JSON 스키마 그대로 출력하고 JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_1_trend_momentum",
  "module_type": "technical",
  "title": "기술 1모듈 · 추세·모멘텀",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "추세·모멘텀 관점 한 줄 제목",
    "emoji": "📈, 🧭, 💤, ⚠️ 등 한 글자 이모지",
    "one_line": "현재 방향과 힘을 한 줄로 요약"
  },
  "expert_insights": {
    "multi_tf_view": "단기/중기 관점에서 방향 일치/불일치 해석(간단히)",
    "momentum_view": "상승/하락 힘, 속도, 과열·침체 여부",
    "position_view": "52주/최근 구간 대비 현재 위치 해석",
    "risk_view": "눌림/되돌림/추격 위험 시나리오"
  },
  "action_advice": {
    "short_term": "단기/트레이딩 관점 행동 가이드",
    "mid_term": "스윙/중기 관점 전략",
    "avoid": "지금 피해야 할 매매 방식"
  },
  "ai_final_comment": "전체 추세·모멘텀을 정리한 총평 한 단락"
}
"""
              },
              {"text": "아래는 price_summary입니다:\n$priceSummary"}
            ]
          }
        ],
        "generationConfig": {"responseMimeType": "application/json"}
      };

      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final text = (candidates != null &&
          candidates.isNotEmpty &&
          candidates[0]['content']?['parts'] != null &&
          (candidates[0]['content']['parts'] as List).isNotEmpty)
          ? (candidates[0]['content']['parts'][0]['text'] as String? ?? '')
          : '';
      if (text.isEmpty) throw Exception('Gemini 응답이 비어 있습니다.');

      final moduleJson = jsonDecode(text) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _tech1Json = moduleJson;
        _tech1Module = Tech1TrendModule.fromJson(moduleJson);
      });
      _maybeRunActionGuide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _trendError = '1모듈 AI 분석 실패: $e');
    } finally {
      if (mounted) setState(() => _trendLoading = false);
    }
  }

  Future<void> _runTech2ModuleWithDaily() async {
    try {
      final candles = await _dailyFuture;
      if (!mounted || candles.isEmpty) return;
      final summary = _buildPriceSummary(candles);
      await _runTech2Module(summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _tech2Error = '2모듈용 일봉 데이터 준비 실패: $e');
    }
  }

  Future<void> _runTech2Module(String priceSummary) async {
    if (_geminiKey.isEmpty) {
      setState(() {
        _tech2Error = kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=... 로 실행해 주세요.'
            : 'AI 서버 설정이 아직 완료되지 않았어요.';
      });
      return;
    }

    setState(() {
      _tech2Loading = true;
      _tech2Error = null;
    });

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
      );

      final body = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 2모듈, '변동성·리스크 모듈' 전담 AI다.

- 아래에 주어지는 일봉·수익률·변동성 요약(price_summary)을 보고,
  이 종목의 변동성, 리스크, 단기 흔들림 정도를 해석해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고, "이럴 가능성이 높다", "다만 ~라면 조심" 같은 톤을 유지한다.
- 아래 JSON 스키마 **그대로**를 출력하고, JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_2_volatility",
  "module_type": "technical",
  "title": "기술 2모듈 · 변동성",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "변동성·리스크 관점 한 줄 제목",
    "emoji": "📈, ⚠️, 📉 등 한 글자 이모지",
    "one_line": "현재 변동성/리스크 상태를 한 줄로 요약"
  },
  "expert_insights": {
    "pattern_view": "추세, 눌림, 박스, 고점/저점 재시험 등 패턴·위치 관점 설명",
    "momentum_view": "상승/하락 힘, 속도, 과열·침체 여부에 대한 해석",
    "liquidity_view": "거래대금, 매수·매도세, 유동성 관점에서의 해석",
    "risk_view": "손실 가능성, 흔들림 폭, 손절/손익비 관점에서의 리스크 평가"
  },
  "action_advice": {
    "short_term": "단기/트레이딩 관점에서의 구체적 행동 가이드",
    "mid_term": "스윙/중기 관점에서의 전략",
    "avoid": "지금 피해야 할 진입·추매·손절 방식 등"
  },
  "ai_final_comment": "전체 변동성·리스크를 한 번 정리해 주는 총평 한 단락"
}
"""
              },
              {"text": "아래는 이 종목의 일봉·수익률·변동성 요약입니다:\n$priceSummary"}
            ],
          }
        ],
        "generationConfig": {"responseMimeType": "application/json"}
      };

      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null ||
          candidates.isEmpty ||
          candidates[0]['content'] == null ||
          candidates[0]['content']['parts'] == null ||
          (candidates[0]['content']['parts'] as List).isEmpty) {
        throw Exception('Gemini 응답이 비어 있습니다.');
      }

      final text = candidates[0]['content']['parts'][0]['text'] as String? ?? '';
      if (text.isEmpty) throw Exception('Gemini 텍스트 응답이 없습니다.');

      final moduleJson = jsonDecode(text) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _tech2Json = moduleJson;
        _tech2Module = Tech2ExpertModule.fromJson(moduleJson);
      });
      _maybeRunActionGuide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _tech2Error = '2모듈 AI 분석 실패: $e');
    } finally {
      if (mounted) setState(() => _tech2Loading = false);
    }
  }

  String _buildPriceSummary(List<Candle> candles) {
    if (candles.isEmpty) return 'NO_DATA';

    final sorted = [...candles]..sort((a, b) => a.t.compareTo(b.t));
    final last = sorted.last;

    final int window = math.min(252, sorted.length);
    final recentFor52w = sorted.sublist(sorted.length - window);
    final hi52w = recentFor52w.map((c) => c.h).reduce(math.max);
    final lo52w = recentFor52w.map((c) => c.l).reduce(math.min);

    double pos52 = 0;
    if (hi52w > lo52w) {
      pos52 = (((last.c - lo52w) / (hi52w - lo52w)) * 100.0).clamp(0.0, 100.0);
    }

    double pctChange(int days) {
      if (sorted.length < days + 1) return 0;
      final prev = sorted[sorted.length - 1 - days].c;
      if (prev == 0) return 0;
      return (last.c - prev) / prev * 100.0;
    }

    final ret5 = pctChange(5);
    final ret20 = pctChange(20);
    final ret60 = pctChange(60);

    final recent20 = sorted.length >= 21 ? sorted.sublist(sorted.length - 21) : sorted;
    int upDays = 0;
    int downDays = 0;
    for (int i = 1; i < recent20.length; i++) {
      final prev = recent20[i - 1].c;
      final curr = recent20[i].c;
      if (curr > prev) upDays++;
      if (curr < prev) downDays++;
    }

    double vol20 = 0;
    if (recent20.length >= 2) {
      final rets = <double>[];
      for (int i = 1; i < recent20.length; i++) {
        final p0 = recent20[i - 1].c;
        final p1 = recent20[i].c;
        if (p0 > 0) rets.add((p1 - p0) / p0 * 100.0);
      }
      if (rets.isNotEmpty) {
        final avg = rets.reduce((a, b) => a + b) / rets.length;
        final sq =
            rets.map((r) => (r - avg) * (r - avg)).reduce((a, b) => a + b) / rets.length;
        vol20 = math.sqrt(sq);
      }
    }

    final df = DateFormat('yyyy-MM-dd');
    final startDate = df.format(sorted.first.t);
    final endDate = df.format(sorted.last.t);

    final buf = StringBuffer();
    buf.writeln('PERIOD:${startDate}~${endDate}');
    buf.writeln('N_DAYS:${sorted.length}');
    buf.writeln('POS_52W:${pos52.toStringAsFixed(2)}');
    buf.writeln('RET_5D:${ret5.toStringAsFixed(2)}');
    buf.writeln('RET_20D:${ret20.toStringAsFixed(2)}');
    buf.writeln('RET_60D:${ret60.toStringAsFixed(2)}');
    buf.writeln('UP_20D:$upDays');
    buf.writeln('DOWN_20D:$downDays');
    buf.writeln('VOL_20D:${vol20.toStringAsFixed(2)}');
    buf.writeln('LOW_52W:${lo52w.toStringAsFixed(2)}');
    buf.writeln('HIGH_52W:${hi52w.toStringAsFixed(2)}');
    buf.writeln('CLOSE:${last.c.toStringAsFixed(2)}');
    return buf.toString();
  }

  Future<void> _runTech3ModuleWithDaily() async {
    if (_geminiKey.isEmpty) {
      setState(() {
        _liquidityError = kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=...'
            : 'AI 서버 설정이 아직 완료되지 않았어요.';
      });
      return;
    }

    setState(() {
      _liquidityLoading = true;
      _liquidityError = null;
    });

    try {
      final candles = await _dailyFuture;
      if (!mounted || candles.isEmpty) return;

      final liqSummary = _buildLiquiditySummary(widget.symbol, candles);

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
      );

      final body = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 3모듈, '유동성·거래 모듈' 전담 AI다.

- 아래 liq_summary를 보고 "들락날락 난이도", "거래대금/거래량의 안정성", "급증/급감 리스크"를 해석해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고 조건부로 말한다.
- 아래 JSON 스키마 그대로 출력하고 JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_3_liquidity_trade",
  "module_type": "technical",
  "title": "기술 3모듈 · 유동성·거래",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "유동성·거래 관점 한 줄 제목",
    "emoji": "💧, 🧊, ⚠️, 🔥 등 한 글자 이모지",
    "one_line": "들락날락 난이도를 한 줄로 요약"
  },
  "expert_insights": {
    "volume_view": "거래량이 안정적인지/변덕스러운지 해석",
    "trade_value_view": "거래대금(상대 수준) 관점 코멘트",
    "slippage_view": "슬리피지/체결 난이도 가능성",
    "risk_view": "급등락·휩쏘·매물대 충돌 리스크"
  },
  "action_advice": {
    "short_term": "단기 매매 시 주문/분할/체결 팁",
    "mid_term": "중기 접근 시 거래대금 체크 포인트",
    "avoid": "피해야 할 진입 방식(한 방, 추격 등)"
  },
  "ai_final_comment": "전체 유동성·거래를 정리한 총평 한 단락"
}
"""
              },
              {"text": "아래는 liq_summary입니다:\n$liqSummary"}
            ]
          }
        ],
        "generationConfig": {"responseMimeType": "application/json"}
      };

      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final text = (candidates != null &&
          candidates.isNotEmpty &&
          candidates[0]['content']?['parts'] != null &&
          (candidates[0]['content']['parts'] as List).isNotEmpty)
          ? (candidates[0]['content']['parts'][0]['text'] as String? ?? '')
          : '';
      if (text.isEmpty) throw Exception('Gemini 응답이 비어 있습니다.');

      final moduleJson = jsonDecode(text) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _tech3Json = moduleJson;
        _tech3Module = Tech3LiquidityModule.fromJson(moduleJson);
      });
      _maybeRunActionGuide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _liquidityError = '3모듈 AI 분석 실패: $e');
    } finally {
      if (mounted) setState(() => _liquidityLoading = false);
    }
  }

  String _buildLiquiditySummary(String symbol, List<Candle> candles) {
    if (candles.isEmpty) return 'NO_DATA';

    final sorted = [...candles]..sort((a, b) => a.t.compareTo(b.t));
    final last = sorted.last;
    final n = sorted.length;

    final recent20 = n >= 20 ? sorted.sublist(n - 20) : sorted;
    final recent3 = n >= 3 ? sorted.sublist(n - 3) : sorted;

    double avgVol(List<Candle> cs) =>
        cs.isEmpty ? 0 : cs.map((c) => c.v).reduce((a, b) => a + b) / cs.length;

    final vol20 = avgVol(recent20);
    final vol3 = avgVol(recent3);
    final volToday = last.v;
    final volRatio3D = vol20 == 0 ? 0 : vol3 / vol20;

    double avgTrdVal20 = 0;
    if (recent20.isNotEmpty) {
      final vals = recent20.map((c) => c.c * c.v).toList();
      avgTrdVal20 = vals.reduce((a, b) => a + b) / vals.length;
    }

    final buf = StringBuffer();
    buf.writeln('SYMBOL:$symbol');
    buf.writeln('N_DAYS:$n');
    buf.writeln('VOL_20D:${vol20.toStringAsFixed(0)}');
    buf.writeln('VOL_TODAY:${volToday.toStringAsFixed(0)}');
    buf.writeln('VOL_RATIO_3D:${volRatio3D.toStringAsFixed(2)}');
    buf.writeln('TRDVAL_20D_AVG:${avgTrdVal20.toStringAsFixed(0)}');
    return buf.toString();
  }

  Future<void> _runTech4ModuleWithDaily() async {
    if (_geminiKey.isEmpty) {
      setState(() {
        _tech4Error = kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=... 로 실행해 주세요.'
            : 'AI 서버 설정이 아직 완료되지 않았어요.';
      });
      return;
    }

    setState(() {
      _tech4Loading = true;
      _tech4Error = null;
    });

    try {
      final candles = await _dailyFuture;
      if (!mounted || candles.isEmpty) return;

      final summary = _buildRangeLevelSummary(widget.symbol, candles);

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
      );

      final body = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 4모듈, '레인지·레벨(지지/저항) 모듈' 전담 AI다.

- 아래에 주어지는 range_level_summary를 보고,
  이 종목의 "현재 위치(박스/돌파/이탈)", "중요 레벨", "진입/손절/목표의 구조"를 설명해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고, 조건부(만약/다만/가능성)를 유지한다.
- 아래 JSON 스키마 **그대로**를 출력하고, JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_4_range_level",
  "module_type": "technical",
  "title": "기술 4모듈 · 레인지·레벨",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "레인지·레벨 관점 한 줄 제목",
    "emoji": "🧱, 🎯, ⚠️ 등 한 글자 이모지",
    "one_line": "현재 위치/레벨 구조를 한 줄로 요약"
  },
  "key_levels": {
    "support_1": "가장 중요한 지지 레벨(숫자+짧은 설명)",
    "support_2": "보조 지지 레벨(숫자+짧은 설명)",
    "resistance_1": "가장 중요한 저항 레벨(숫자+짧은 설명)",
    "resistance_2": "보조 저항 레벨(숫자+짧은 설명)"
  },
  "market_structure": {
    "range_view": "박스/추세/돌파/이탈 여부와 현재 구간 설명",
    "level_story": "왜 이 레벨들이 중요해 보이는지(심리/가격행동 관점)",
    "trap_risk": "가짜 돌파/휩쏘 위험 시나리오"
  },
  "action_advice": {
    "entry_plan": "진입 전략(돌파/눌림/박스 하단 등) 중 현실적인 접근 1~2개",
    "stop_plan": "손절/리스크 관리(어디 깨지면 구조가 무너지는지)",
    "target_plan": "목표/분할익절(어디를 뚫으면 다음 구간이 열리는지)",
    "avoid": "지금 피해야 할 매매(추격/물타기/손절 지연 등)"
  },
  "ai_final_comment": "전체 레인지·레벨을 한 번 정리해 주는 총평 한 단락"
}
"""
              },
              {"text": "아래는 range_level_summary입니다:\n$summary"}
            ]
          }
        ],
        "generationConfig": {"responseMimeType": "application/json"}
      };

      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;

      if (candidates == null ||
          candidates.isEmpty ||
          candidates[0]['content'] == null ||
          candidates[0]['content']['parts'] == null ||
          (candidates[0]['content']['parts'] as List).isEmpty) {
        throw Exception('Gemini 응답이 비어 있습니다.');
      }

      final text = candidates[0]['content']['parts'][0]['text'] as String? ?? '';
      if (text.isEmpty) throw Exception('Gemini 텍스트 응답이 없습니다.');

      final moduleJson = jsonDecode(text) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _tech4Json = moduleJson;
        _tech4Module = Tech4RangeLevelModule.fromJson(moduleJson);
      });
      _maybeRunActionGuide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _tech4Error = '4모듈 AI 분석 실패: $e');
    } finally {
      if (mounted) setState(() => _tech4Loading = false);
    }
  }

  String _buildRangeLevelSummary(String symbol, List<Candle> candles) {
    if (candles.isEmpty) return 'NO_DATA';

    final sorted = [...candles]..sort((a, b) => a.t.compareTo(b.t));
    final last = sorted.last;

    double maxHigh(List<Candle> cs) => cs.map((c) => c.h).reduce(math.max);
    double minLow(List<Candle> cs) => cs.map((c) => c.l).reduce(math.min);

    final w252 = sorted.sublist(math.max(0, sorted.length - math.min(252, sorted.length)));
    final w60 = sorted.sublist(math.max(0, sorted.length - math.min(60, sorted.length)));
    final w20 = sorted.sublist(math.max(0, sorted.length - math.min(20, sorted.length)));

    final hi52 = maxHigh(w252);
    final lo52 = minLow(w252);
    final hi60 = maxHigh(w60);
    final lo60 = minLow(w60);
    final hi20 = maxHigh(w20);
    final lo20 = minLow(w20);

    double atr14 = 0;
    if (sorted.length >= 15) {
      final last15 = sorted.sublist(sorted.length - 15);
      final trs = <double>[];
      for (int i = 1; i < last15.length; i++) {
        final prevClose = last15[i - 1].c;
        final high = last15[i].h;
        final low = last15[i].l;
        final tr = math.max(high - low, math.max((high - prevClose).abs(), (low - prevClose).abs()));
        trs.add(tr);
      }
      if (trs.isNotEmpty) atr14 = trs.reduce((a, b) => a + b) / trs.length;
    }

    final prev = sorted.length >= 2 ? sorted[sorted.length - 2] : last;
    final pivot = (prev.h + prev.l + prev.c) / 3.0;
    final r1 = 2 * pivot - prev.l;
    final s1 = 2 * pivot - prev.h;

    double pos(double lo, double hi) {
      if (hi <= lo) return 0;
      return (((last.c - lo) / (hi - lo)) * 100.0).clamp(0.0, 100.0);
    }

    final pos52 = pos(lo52, hi52);
    final pos60 = pos(lo60, hi60);
    final pos20 = pos(lo20, hi20);

    final df = DateFormat('yyyy-MM-dd');
    final startDate = df.format(sorted.first.t);
    final endDate = df.format(sorted.last.t);

    final buf = StringBuffer();
    buf.writeln('SYMBOL:$symbol');
    buf.writeln('PERIOD:${startDate}~${endDate}');
    buf.writeln('CLOSE:${last.c.toStringAsFixed(2)}');
    buf.writeln('RANGE_52W_LOW:${lo52.toStringAsFixed(2)}');
    buf.writeln('RANGE_52W_HIGH:${hi52.toStringAsFixed(2)}');
    buf.writeln('POS_52W:${pos52.toStringAsFixed(2)}');
    buf.writeln('RANGE_60D_LOW:${lo60.toStringAsFixed(2)}');
    buf.writeln('RANGE_60D_HIGH:${hi60.toStringAsFixed(2)}');
    buf.writeln('POS_60D:${pos60.toStringAsFixed(2)}');
    buf.writeln('RANGE_20D_LOW:${lo20.toStringAsFixed(2)}');
    buf.writeln('RANGE_20D_HIGH:${hi20.toStringAsFixed(2)}');
    buf.writeln('POS_20D:${pos20.toStringAsFixed(2)}');
    buf.writeln('PIVOT:${pivot.toStringAsFixed(2)}');
    buf.writeln('R1:${r1.toStringAsFixed(2)}');
    buf.writeln('S1:${s1.toStringAsFixed(2)}');
    buf.writeln('ATR_14:${atr14.toStringAsFixed(2)}');
    return buf.toString();
  }

  Future<void> _runTech5ModuleWithIntraday() async {
    if (_geminiKey.isEmpty) {
      setState(() {
        _tech5Error = kDebugMode
            ? 'GEMINI_API_KEY가 설정되지 않았습니다.\nflutter run --dart-define=GEMINI_API_KEY=...'
            : 'AI 서버 설정이 아직 완료되지 않았어요.';
      });
      return;
    }

    setState(() {
      _tech5Loading = true;
      _tech5Error = null;
    });

    try {
      final candles = await _intradayFuture;
      if (!mounted || candles.isEmpty) return;

      final summary = _buildOrderflowSummary(widget.symbol, candles);

      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=$_geminiKey',
      );

      final body = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text": """
너는 '밸레인(BALRAIN)' 앱의 기술 5모듈, '호가·체결 흐름(오더플로우) 모듈' 전담 AI다.

- 아래 orderflow_summary(5분봉 기반 요약)를 보고,
  "체결 강도/공격성", "상단/하단 압력", "휩쏘(함정) 가능성", "짧은 구간의 유동성 리스크"를 해석해라.
- 반드시 한국어만 사용한다.
- 과도한 단정은 피하고 조건부로 말한다.
- 아래 JSON 스키마 그대로 출력하고 JSON 이외 문장은 절대 쓰지 마라.

{
  "module_id": "tech_5_orderflow",
  "module_type": "technical",
  "title": "기술 5모듈 · 호가·체결 흐름",
  "summary": {
    "grade": "A | B | C | D 중 하나",
    "label": "호가·체결 흐름 관점 한 줄 제목",
    "emoji": "⚡, 🧲, 🧊, ⚠️ 등 한 글자 이모지",
    "one_line": "지금 체결 흐름을 한 줄로 요약"
  },
  "expert_insights": {
    "spread_pressure_view": "스프레드/압력(상단/하단) 관점 코멘트",
    "trade_intensity_view": "체결 강도·공격성(매수/매도 주도) 해석",
    "liquidity_risk_view": "짧은 구간 유동성 리스크/슬리피지 가능성",
    "trap_view": "휩쏘/가짜 움직임/함정 가능성 시나리오"
  },
  "action_advice": {
    "short_term": "단기 매매 시 주문/분할/추격 방지 팁",
    "mid_term": "중기 관점에서 지금 흐름을 어떻게 참고할지",
    "avoid": "피해야 할 행동(추격, 한방, 손절 지연 등)"
  },
  "ai_final_comment": "전체 호가·체결 흐름을 정리한 총평 한 단락"
}
"""
              },
              {"text": "아래는 orderflow_summary입니다:\n$summary"}
            ]
          }
        ],
        "generationConfig": {"responseMimeType": "application/json"}
      };

      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}: ${res.body}');

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final text = (candidates != null &&
          candidates.isNotEmpty &&
          candidates[0]['content']?['parts'] != null &&
          (candidates[0]['content']['parts'] as List).isNotEmpty)
          ? (candidates[0]['content']['parts'][0]['text'] as String? ?? '')
          : '';
      if (text.isEmpty) throw Exception('Gemini 응답이 비어 있습니다.');

      final moduleJson = jsonDecode(text) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _tech5Json = moduleJson;
        _tech5Module = Tech5OrderflowModule.fromJson(moduleJson);
      });
      _maybeRunActionGuide();
    } catch (e) {
      if (!mounted) return;
      setState(() => _tech5Error = '5모듈 AI 분석 실패: $e');
    } finally {
      if (mounted) setState(() => _tech5Loading = false);
    }
  }

  String _buildOrderflowSummary(String symbol, List<Candle> candles) {
    if (candles.isEmpty) return 'NO_DATA';

    final sorted = [...candles]..sort((a, b) => a.t.compareTo(b.t));
    final last = sorted.last;

    final int lookback = math.min(60, sorted.length);
    final recent = sorted.sublist(sorted.length - lookback);

    double sumVol = 0;
    double sumPV = 0;
    double upVol = 0;
    double downVol = 0;
    double rangeSum = 0;
    int upBars = 0;
    int downBars = 0;

    for (final c in recent) {
      sumVol += c.v;
      sumPV += c.c * c.v;
      final body = c.c - c.o;
      if (body >= 0) {
        upBars++;
        upVol += c.v;
      } else {
        downBars++;
        downVol += c.v;
      }
      rangeSum += (c.h - c.l).abs();
    }

    final vwap = sumVol == 0 ? last.c : (sumPV / sumVol);
    final avgRange = recent.isEmpty ? 0 : rangeSum / recent.length;

    final int k = math.min(12, recent.length);
    final lastK = recent.sublist(recent.length - k);
    final prev = recent.sublist(0, recent.length - k);
    double avgVolLastK = 0;
    if (lastK.isNotEmpty) {
      avgVolLastK = lastK.map((e) => e.v).reduce((a, b) => a + b) / lastK.length;
    }
    double avgVolPrev = 0;
    if (prev.isNotEmpty) {
      avgVolPrev = prev.map((e) => e.v).reduce((a, b) => a + b) / prev.length;
    }
    final volSpike = avgVolPrev == 0 ? 0 : (avgVolLastK / avgVolPrev);

    final upVolRatio = (upVol + downVol) == 0 ? 0 : (upVol / (upVol + downVol));
    final df = DateFormat('yyyy-MM-dd HH:mm');

    final buf = StringBuffer();
    buf.writeln('SYMBOL:$symbol');
    buf.writeln('PERIOD:${df.format(recent.first.t)}~${df.format(recent.last.t)}');
    buf.writeln('N_BARS:${recent.length}');
    buf.writeln('LAST_CLOSE:${last.c.toStringAsFixed(2)}');
    buf.writeln('VWAP_APPROX:${vwap.toStringAsFixed(2)}');
    buf.writeln('AVG_RANGE:${avgRange.toStringAsFixed(4)}');
    buf.writeln('UP_BARS:$upBars');
    buf.writeln('DOWN_BARS:$downBars');
    buf.writeln('UPVOL_RATIO:${(upVolRatio * 100).toStringAsFixed(1)}');
    buf.writeln('VOL_SPIKE_1H:${volSpike.toStringAsFixed(2)}');
    buf.writeln('VOL_LAST:${last.v.toStringAsFixed(0)}');
    return buf.toString();
  }

  /* ================================ STATUS LABELS ================================ */

  String _trendStatusLabel() {
    if (_trendLoading) return '분석 중';
    if (_trendError != null) return '분석 실패';
    if (_tech1Module != null) return '분석 완료';
    return '대기 중';
  }

  Color _trendStatusColor() {
    if (_trendLoading) return _a(kBrand, 0.95);
    if (_trendError != null) return const Color(0xFFDC2626);
    if (_tech1Module != null) return const Color(0xFF16A34A);
    return kMuted;
  }

  String _tech2StatusLabel() {
    if (_tech2Loading) return '분석 중';
    if (_tech2Error != null) return '분석 실패';
    if (_tech2Module != null) return '분석 완료';
    return '대기 중';
  }

  Color _tech2StatusColor() {
    if (_tech2Loading) return _a(kBrand, 0.95);
    if (_tech2Error != null) return const Color(0xFFDC2626);
    if (_tech2Module != null) return const Color(0xFF16A34A);
    return kMuted;
  }

  String _tech3StatusLabel() {
    if (_liquidityLoading) return '분석 중';
    if (_liquidityError != null) return '분석 실패';
    if (_tech3Module != null) return '분석 완료';
    return '대기 중';
  }

  Color _tech3StatusColor() {
    if (_liquidityLoading) return _a(kBrand, 0.95);
    if (_liquidityError != null) return const Color(0xFFDC2626);
    if (_tech3Module != null) return const Color(0xFF16A34A);
    return kMuted;
  }

  String _tech4StatusLabel() {
    if (_tech4Loading) return '분석 중';
    if (_tech4Error != null) return '분석 실패';
    if (_tech4Module != null) return '분석 완료';
    return '대기 중';
  }

  Color _tech4StatusColor() {
    if (_tech4Loading) return _a(kBrand, 0.95);
    if (_tech4Error != null) return const Color(0xFFDC2626);
    if (_tech4Module != null) return const Color(0xFF16A34A);
    return kMuted;
  }

  String _tech5StatusLabel() {
    if (_tech5Loading) return '분석 중';
    if (_tech5Error != null) return '분석 실패';
    if (_tech5Module != null) return '분석 완료';
    return '대기 중';
  }

  Color _tech5StatusColor() {
    if (_tech5Loading) return _a(kBrand, 0.95);
    if (_tech5Error != null) return const Color(0xFFDC2626);
    if (_tech5Module != null) return const Color(0xFF16A34A);
    return kMuted;
  }

  /* ================================ UI ================================ */

  Widget _buildChartModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kStroke),
      ),
      padding: const EdgeInsets.all(2),
      child: SegmentedButton<ChartMode>(
        segments: const [
          ButtonSegment(value: ChartMode.daily, label: Text('개요')),
          ButtonSegment(value: ChartMode.intraday, label: Text('세밀')),
        ],
        selected: <ChartMode>{_mode},
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          textStyle: WidgetStatePropertyAll(_t(size: 12, weight: FontWeight.w700).copyWith(fontFamily: GoogleFonts.inter().fontFamily)),
        ),
        onSelectionChanged: (s) => setState(() => _mode = s.first),
      ),
    );
  }

  String _categoryLabel(ModuleCategory cat) {
    switch (cat) {
      case ModuleCategory.tech:
        return '기술';
      case ModuleCategory.fund:
        return '펀더';
      case ModuleCategory.external:
        return '외부환경';
      case ModuleCategory.psych:
        return '심리';
    }
  }

  Widget _buildCategoryTabs() {
    Widget buildTab(ModuleCategory cat) {
      final selected = cat == _selectedCategory;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedCategory = cat;
              _selectedModuleIndex = 0;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? _a(kBrand, 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              _categoryLabel(cat),
              style: _t(
                size: 13,
                weight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? kBrand : kMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kStroke),
      ),
      child: Row(
        children: [
          buildTab(ModuleCategory.tech),
          const SizedBox(width: 4),
          buildTab(ModuleCategory.fund),
          const SizedBox(width: 4),
          buildTab(ModuleCategory.external),
          const SizedBox(width: 4),
          buildTab(ModuleCategory.psych),
        ],
      ),
    );
  }

  Widget _buildModuleChips() {
    final modules = _moduleNames[_selectedCategory] ?? const <String>[];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < modules.length; i++) ...[
            if (i == 0) const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() => _selectedModuleIndex = i);

                if (_selectedCategory == ModuleCategory.tech) {
                  if (i == 0 && _tech1Module == null && !_trendLoading) _runTech1ModuleWithDaily();
                  if (i == 1 && _tech2Module == null && !_tech2Loading) _runTech2ModuleWithDaily();
                  if (i == 2 && _tech3Module == null && !_liquidityLoading) _runTech3ModuleWithDaily();
                  if (i == 3 && _tech4Module == null && !_tech4Loading) _runTech4ModuleWithDaily();
                  if (i == 4 && _tech5Module == null && !_tech5Loading) _runTech5ModuleWithIntraday();
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedModuleIndex == i ? _a(kBrand, 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _selectedModuleIndex == i ? _a(kBrand, 0.45) : kStroke,
                  ),
                ),
                child: Text(
                  modules[i],
                  style: _t(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _selectedModuleIndex == i ? kBrand : kMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTechCategoryHint() {
    if (_selectedCategory != ModuleCategory.tech) return const SizedBox.shrink();
    return Text(
      '기술 1모듈은 "어디로 얼마나 힘 있게 가는지", 2모듈은 "그 길의 롤러코스터 강도(리스크)",\n'
          '3모듈은 "들락날락하기 쉬운 장인지(유동성)", 4모듈은 "막히는 곳/버티는 곳(레벨)", 5모듈은 "단기 체결 흐름"을 봐요.',
      style: _t(size: 10.2, color: _a(kMuted, 0.85), height: 1.35),
    );
  }

  Card _baseCard({required Widget child}) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _a(kBrand, 0.08), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: child,
      ),
    );
  }

  Widget _statusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: _t(size: 10, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  /* ====================== MODULE CARDS ====================== */

  Widget _buildTrendModuleCard() {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: _a(kBrand, 0.12), borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.timeline_rounded, size: 16, color: kBrand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '기술 1모듈 · ${TrendModuleSpec.title}',
                  style: _t(size: 13, weight: FontWeight.w900, color: kInk),
                ),
              ),
              _statusPill(label: _trendStatusLabel(), color: _trendStatusColor()),
            ],
          ),
          const SizedBox(height: 6),
          Text(TrendModuleSpec.shortDescription, style: _t(size: 11, color: kMuted, height: 1.35)),
          const SizedBox(height: 10),
          if (_trendLoading)
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('AI가 가격 추세·모멘텀을 분석 중입니다...', style: _t(size: 12)),
              ],
            )
          else if (_trendError != null)
            Text(_trendError!, style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4))
          else if (_tech1Module != null)
              _buildTech1Body(_tech1Module!)
            else
              Text('아직 분석이 시작되지 않았습니다. 일봉 데이터 로딩 후 자동으로 분석합니다.', style: _t(size: 12, color: kMuted)),
        ],
      ),
    );
  }

  Widget _buildTech2ModuleCard() {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: _a(kBrand, 0.12), borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.person_search_rounded, size: 16, color: kBrand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('기술 2모듈 · 변동성', style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
              ),
              _statusPill(label: _tech2StatusLabel(), color: _tech2StatusColor()),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '실전 트레이더가 차트를 보고 말해주는 것처럼, 리스크/흔들림/대응을 읽어주는 전문가 뷰입니다.',
            style: _t(size: 11, color: kMuted, height: 1.35),
          ),
          const SizedBox(height: 10),
          if (_tech2Loading)
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('AI가 전문가 관점으로 이 종목을 해석 중입니다...', style: _t(size: 12)),
              ],
            )
          else if (_tech2Error != null)
            Text(_tech2Error!, style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4))
          else if (_tech2Module != null)
              _buildTech2Body(_tech2Module!)
            else
              Text('아직 분석이 실행되지 않았습니다.\n상단 칩에서 2모듈을 선택하면 실행됩니다.', style: _t(size: 12, color: kMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTech3ModuleCard() {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: _a(kBrand, 0.12), borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.swap_vert_rounded, size: 16, color: kBrand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('기술 3모듈 · ${LiquidityModuleSpec.title}', style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
              ),
              _statusPill(label: _tech3StatusLabel(), color: _tech3StatusColor()),
            ],
          ),
          const SizedBox(height: 6),
          Text(LiquidityModuleSpec.shortDescription, style: _t(size: 11, color: kMuted, height: 1.35)),
          const SizedBox(height: 10),
          if (_liquidityLoading)
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('AI가 유동성·거래 관점에서 해석 중입니다...', style: _t(size: 12)),
              ],
            )
          else if (_liquidityError != null)
            Text(_liquidityError!, style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4))
          else if (_tech3Module != null)
              _buildTech3Body(_tech3Module!)
            else
              Text('아직 분석이 실행되지 않았습니다.\n상단 칩에서 3모듈을 선택하면 실행됩니다.', style: _t(size: 12, color: kMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTech4ModuleCard() {
    final theme = Theme.of(context);
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: _a(kBrand, 0.12), borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.layers_rounded, size: 16, color: kBrand),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('기술 4모듈 · 레인지·레벨', style: _t(size: 13, weight: FontWeight.w900, color: kInk))),
              _statusPill(label: _tech4StatusLabel(), color: _tech4StatusColor()),
            ],
          ),
          const SizedBox(height: 6),
          Text('지지/저항, 박스권, 돌파/이탈 같은 “가격의 길목(레벨)”을 잡아주는 모듈입니다.', style: _t(size: 11, color: kMuted, height: 1.35)),
          const SizedBox(height: 10),
          if (_tech4Loading)
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('AI가 레인지·레벨 구조를 정리 중입니다...', style: _t(size: 12)),
              ],
            )
          else if (_tech4Error != null)
            Text(_tech4Error!, style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4))
          else if (_tech4Module != null)
              _buildTech4Body(_tech4Module!, theme)
            else
              Text('아직 분석이 실행되지 않았습니다.\n상단 칩에서 4모듈을 선택하면 실행됩니다.', style: _t(size: 12, color: kMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTech5ModuleCard() {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: _a(kBrand, 0.12), borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.bolt_rounded, size: 16, color: kBrand),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('기술 5모듈 · 호가·체결 흐름', style: _t(size: 13, weight: FontWeight.w900, color: kInk))),
              _statusPill(label: _tech5StatusLabel(), color: _tech5StatusColor()),
            ],
          ),
          const SizedBox(height: 6),
          Text('5분봉 흐름 기반으로 “체결 난이도/휩쏘 위험” 같은 단기 진입 난이도를 읽어줘요.', style: _t(size: 11, color: kMuted, height: 1.35)),
          const SizedBox(height: 10),
          if (_tech5Loading)
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('AI가 호가·체결 흐름을 분석 중입니다...', style: _t(size: 12)),
              ],
            )
          else if (_tech5Error != null)
            Text(_tech5Error!, style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4))
          else if (_tech5Module != null)
              _buildTech5Body(_tech5Module!)
            else
              Text('아직 분석이 실행되지 않았습니다.\n상단 칩에서 5모듈을 선택하면 실행됩니다.', style: _t(size: 12, color: kMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildCurrentModuleContent() {
    if (_selectedCategory == ModuleCategory.tech) {
      if (_selectedModuleIndex == 0) return _buildTrendModuleCard();
      if (_selectedModuleIndex == 1) return _buildTech2ModuleCard();
      if (_selectedModuleIndex == 2) return _buildTech3ModuleCard();
      if (_selectedModuleIndex == 3) return _buildTech4ModuleCard();
      if (_selectedModuleIndex == 4) return _buildTech5ModuleCard();
    }

    if (_selectedCategory == ModuleCategory.fund) {
      return _buildPlaceholderModuleCard(
        title: '펀더 1모듈 · 재무·밸류에이션 분석 (준비중)',
        description:
        '재무제표, 밸류에이션 배수, 성장성 등을 바탕으로\n현재 가격이 고평가/저평가인지 진단하는 모듈 자리입니다.\n\n향후에는 PER, PBR, FCF, 마진 구조 등을 요약해서\n한글로 읽기 쉬운 코멘트를 제공할 예정이에요.',
      );
    }

    if (_selectedCategory == ModuleCategory.external) {
      return _buildPlaceholderModuleCard(
        title: '외부환경 1모듈 · 거시·섹터·수급 (준비중)',
        description:
        '금리, 환율, 섹터 흐름, 기관·외국인 수급 등\n종목 밖 환경을 체크하는 모듈 자리입니다.\n\n완성되면 “시장이 도와주는 구간인지”를\n짧은 문장으로 알려주는 역할을 하게 될 거예요.',
      );
    }

    if (_selectedCategory == ModuleCategory.psych) {
      return _buildPlaceholderModuleCard(
        title: '심리 1모듈 · 심리·행동 (준비중)',
        description:
        '뉴스·커뮤니티, 변동성, 거래대금 등을 바탕으로\n투자자 심리가 과열/공포인지 파악하는 모듈 자리입니다.\n\n완성 시에는 “몰려다니는 매매인지, 차분한 구간인지”를\n직관적으로 설명해 줄 계획입니다.',
      );
    }

    return _buildPlaceholderModuleCard(title: '모듈 (준비중)', description: '해당 모듈은 아직 준비 중입니다.');
  }

  Widget _buildAiSummaryCard() {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _a(kBrand, 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 15, color: kBrand),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('AI 결론 카드', style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
              ),
              if (_actionGuideLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),

          // ✅ 아직 모듈이 하나도 없으면 안내
          if (!_hasAnyTechJson) ...[
            Text(
              '기술 모듈 결과를 바탕으로 “지금은 들어가도 되는지/관망인지/피해야 하는지”를 결론으로 정리해줘요.\n\n'
                  '상단에서 기술 모듈을 실행하면 자동으로 결론 카드가 생성됩니다.',
              style: _t(size: 11, color: kMuted, height: 1.45),
            ),
          ]
          // ✅ 에러
          else if (_actionGuideError != null) ...[
            Text(
              _actionGuideError!,
              style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _maybeRunActionGuide(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('다시 생성', style: _t(size: 12, weight: FontWeight.w800, color: kInk)),
              ),
            ),
          ]
          // ✅ 로딩인데 아직 가이드가 없으면 “스켈레톤 느낌” 텍스트
          else if (_actionGuideLoading && _actionGuide == null) ...[
              Text('모듈 결과를 종합해서 결론을 만드는 중이에요...', style: _t(size: 12, color: kMuted)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _a(kBrand, 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _a(kBrand, 0.10)),
                ),
                child: Text('AI 결론 카드 생성 중…', style: _t(size: 11.2, color: kMuted)),
              ),
            ]
            // ✅ 최종: 결론 카드 렌더
            else if (_actionGuide != null) ...[
                ActionGuideCard(guide: _actionGuide!),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _maybeRunActionGuide(force: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('결론 다시 만들기', style: _t(size: 12, weight: FontWeight.w800, color: kBrand)),
                  ),
                ),
              ]
              // ✅ 안전망: json은 있는데 가이드가 없다 -> 수동 생성 버튼
              else ...[
                  Text('결론 카드가 아직 생성되지 않았어요.', style: _t(size: 12, color: kMuted)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _maybeRunActionGuide(force: true),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text('결론 생성', style: _t(size: 12, weight: FontWeight.w800, color: kInk)),
                  ),
                ],
        ],
      ),
    );
  }


  Widget _buildPlaceholderModuleCard({required String title, required String description}) {
    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 8),
          Text(description, style: _t(size: 11.5, color: kMuted, height: 1.45)),
        ],
      ),
    );
  }

  /* ====================== BODY BUILDERS ====================== */

  Widget _buildTech1Body(Tech1TrendModule data) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.summary.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.summary.label, style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 3),
                  Text(data.summary.oneLine, style: _t(size: 11, color: kMuted, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.06), borderRadius: BorderRadius.circular(999)),
              child: Text('등급 ${data.summary.grade}', style: _t(size: 10, weight: FontWeight.w900, color: theme.colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('전문가 인사이트', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _insightItem(title: '멀티 타임프레임', body: data.expertInsights.multiTfView, icon: Icons.layers_rounded),
        _insightItem(title: '모멘텀', body: data.expertInsights.momentumView, icon: Icons.speed_rounded),
        _insightItem(title: '현재 위치', body: data.expertInsights.positionView, icon: Icons.my_location_rounded),
        _insightItem(title: '리스크', body: data.expertInsights.riskView, icon: Icons.warning_amber_rounded),
        const SizedBox(height: 10),
        Text('행동 전략 가이드', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _adviceItem(label: '단기 / 트레이딩', body: data.actionAdvice.shortTerm, icon: Icons.flash_on_rounded),
        _adviceItem(label: '중기 / 스윙', body: data.actionAdvice.midTerm, icon: Icons.trending_up_rounded),
        _adviceItem(label: '피해야 할 행동', body: data.actionAdvice.avoid, icon: Icons.block_rounded),
        const SizedBox(height: 10),
        Text('AI 전문가 총평', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.04), borderRadius: BorderRadius.circular(12)),
          child: Text(data.aiFinalComment, style: _t(size: 11.2, color: kInk, height: 1.45)),
        ),
      ],
    );
  }

  Widget _buildTech3Body(Tech3LiquidityModule data) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.summary.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.summary.label, style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 3),
                  Text(data.summary.oneLine, style: _t(size: 11, color: kMuted, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.06), borderRadius: BorderRadius.circular(999)),
              child: Text('등급 ${data.summary.grade}', style: _t(size: 10, weight: FontWeight.w900, color: theme.colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('전문가 인사이트', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _insightItem(title: '거래량 관점', body: data.expertInsights.volumeView, icon: Icons.bar_chart_rounded),
        _insightItem(title: '거래대금 관점', body: data.expertInsights.tradeValueView, icon: Icons.attach_money_rounded),
        _insightItem(title: '체결/슬리피지', body: data.expertInsights.slippageView, icon: Icons.swap_horiz_rounded),
        _insightItem(title: '리스크', body: data.expertInsights.riskView, icon: Icons.warning_amber_rounded),
        const SizedBox(height: 10),
        Text('행동 전략 가이드', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _adviceItem(label: '단기 / 트레이딩', body: data.actionAdvice.shortTerm, icon: Icons.flash_on_rounded),
        _adviceItem(label: '중기 / 스윙', body: data.actionAdvice.midTerm, icon: Icons.trending_up_rounded),
        _adviceItem(label: '피해야 할 행동', body: data.actionAdvice.avoid, icon: Icons.block_rounded),
        const SizedBox(height: 10),
        Text('AI 전문가 총평', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.04), borderRadius: BorderRadius.circular(12)),
          child: Text(data.aiFinalComment, style: _t(size: 11.2, color: kInk, height: 1.45)),
        ),
      ],
    );
  }

  Widget _buildTech4Body(Tech4RangeLevelModule data, ThemeData theme) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const SizedBox(height: 8),
    Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(data.summary.emoji, style: const TextStyle(fontSize: 24)),
    const SizedBox(width: 6),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(data.summary.label, style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
    const SizedBox(height: 3),
    Text(data.summary.oneLine, style: _t(size: 11, color: kMuted, height: 1.35)),
    ],
    ),
    ),
    const SizedBox(width: 4),
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.06), borderRadius: BorderRadius.circular(999)),
      child: Text(
        '등급 ${data.summary.grade}',
        style: _t(size: 10, weight: FontWeight.w900, color: theme.colorScheme.primary),
      ),
    ),
    ],
    ),

          const SizedBox(height: 12),

          // ✅ 핵심 레벨
          Text('핵심 레벨', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 6),
          _levelsGrid(
            theme: theme,
            s1: data.keyLevels.support1,
            s2: data.keyLevels.support2,
            r1: data.keyLevels.resistance1,
            r2: data.keyLevels.resistance2,
          ),

          const SizedBox(height: 12),

          // ✅ 구조 해석
          Text('시장 구조', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 6),
          _insightItem(title: '레인지/추세', body: data.marketStructure.rangeView, icon: Icons.view_week_rounded),
          _insightItem(title: '레벨 스토리', body: data.marketStructure.levelStory, icon: Icons.menu_book_rounded),
          _insightItem(title: '함정/휩쏘', body: data.marketStructure.trapRisk, icon: Icons.crisis_alert_rounded),

          const SizedBox(height: 10),

          // ✅ 액션
          Text('행동 전략 가이드', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 6),
          _adviceItem(label: '진입 플랜', body: data.actionAdvice.entryPlan, icon: Icons.login_rounded),
          _adviceItem(label: '손절/리스크', body: data.actionAdvice.stopPlan, icon: Icons.shield_rounded),
          _adviceItem(label: '목표/익절', body: data.actionAdvice.targetPlan, icon: Icons.flag_rounded),
          _adviceItem(label: '피해야 할 행동', body: data.actionAdvice.avoid, icon: Icons.block_rounded),

          const SizedBox(height: 10),

          // ✅ 총평
          Text('AI 전문가 총평', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.04), borderRadius: BorderRadius.circular(12)),
            child: Text(data.aiFinalComment, style: _t(size: 11.2, color: kInk, height: 1.45)),
          ),
        ],
    );
  }

  Widget _buildTech2Body(Tech2ExpertModule data) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.summary.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.summary.label, style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 3),
                  Text(data.summary.oneLine, style: _t(size: 11, color: kMuted, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.06), borderRadius: BorderRadius.circular(999)),
              child: Text('등급 ${data.summary.grade}', style: _t(size: 10, weight: FontWeight.w900, color: theme.colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('전문가 인사이트', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _insightItem(title: '패턴/위치', body: data.expertInsights.patternView, icon: Icons.insights_rounded),
        _insightItem(title: '모멘텀', body: data.expertInsights.momentumView, icon: Icons.speed_rounded),
        _insightItem(title: '유동성', body: data.expertInsights.liquidityView, icon: Icons.water_drop_rounded),
        _insightItem(title: '리스크', body: data.expertInsights.riskView, icon: Icons.warning_amber_rounded),
        const SizedBox(height: 10),
        Text('행동 전략 가이드', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _adviceItem(label: '단기 / 트레이딩', body: data.actionAdvice.shortTerm, icon: Icons.flash_on_rounded),
        _adviceItem(label: '중기 / 스윙', body: data.actionAdvice.midTerm, icon: Icons.trending_up_rounded),
        _adviceItem(label: '피해야 할 행동', body: data.actionAdvice.avoid, icon: Icons.block_rounded),
        const SizedBox(height: 10),
        Text('AI 전문가 총평', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.04), borderRadius: BorderRadius.circular(12)),
          child: Text(data.aiFinalComment, style: _t(size: 11.2, color: kInk, height: 1.45)),
        ),
      ],
    );
  }

  Widget _buildTech5Body(Tech5OrderflowModule data) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.summary.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.summary.label, style: _t(size: 13, weight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 3),
                  Text(data.summary.oneLine, style: _t(size: 11, color: kMuted, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.06), borderRadius: BorderRadius.circular(999)),
              child: Text('등급 ${data.summary.grade}', style: _t(size: 10, weight: FontWeight.w900, color: theme.colorScheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('전문가 인사이트', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _insightItem(title: '스프레드/압력', body: data.expertInsights.spreadPressureView, icon: Icons.compare_arrows_rounded),
        _insightItem(title: '체결 강도', body: data.expertInsights.tradeIntensityView, icon: Icons.bolt_rounded),
        _insightItem(title: '유동성 리스크', body: data.expertInsights.liquidityRiskView, icon: Icons.warning_rounded),
        _insightItem(title: '휩쏘/함정', body: data.expertInsights.trapView, icon: Icons.crisis_alert_rounded),
        const SizedBox(height: 10),
        Text('행동 전략 가이드', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 6),
        _adviceItem(label: '단기 / 트레이딩', body: data.actionAdvice.shortTerm, icon: Icons.flash_on_rounded),
        _adviceItem(label: '중기 참고', body: data.actionAdvice.midTerm, icon: Icons.trending_up_rounded),
        _adviceItem(label: '피해야 할 행동', body: data.actionAdvice.avoid, icon: Icons.block_rounded),
        const SizedBox(height: 10),
        Text('AI 전문가 총평', style: _t(size: 12, weight: FontWeight.w900, color: kInk)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _a(theme.colorScheme.primary, 0.04), borderRadius: BorderRadius.circular(12)),
          child: Text(data.aiFinalComment, style: _t(size: 11.2, color: kInk, height: 1.45)),
        ),
      ],
    );
  }

  Widget _insightItem({required String title, required String body, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _a(kStroke, 1)),
        color: Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: _a(kBrand, 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 15, color: kBrand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(size: 11.5, weight: FontWeight.w900, color: kInk)),
                const SizedBox(height: 4),
                Text(body, style: _t(size: 11.2, color: kMuted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adviceItem({required String label, required String body, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _a(kBrand, 0.04),
        border: Border.all(color: _a(kBrand, 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: _a(kBrand, 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 15, color: kBrand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _t(size: 11.5, weight: FontWeight.w900, color: kInk)),
                const SizedBox(height: 4),
                Text(body, style: _t(size: 11.2, color: kInk, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelsGrid({
    required ThemeData theme,
    required String s1,
    required String s2,
    required String r1,
    required String r2,
  }) {
    Widget tile(String title, String value, {required bool isSupport}) {
      final bg = isSupport ? _a(const Color(0xFF16A34A), 0.06) : _a(const Color(0xFFDC2626), 0.06);
      final stroke = isSupport ? _a(const Color(0xFF16A34A), 0.20) : _a(const Color(0xFFDC2626), 0.20);
      final dot = isSupport ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: stroke),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _t(size: 10.6, weight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 4),
                  Text(value, style: _t(size: 11.2, weight: FontWeight.w800, color: kInk, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tile('지지 1', s1, isSupport: true)),
            const SizedBox(width: 8),
            Expanded(child: tile('저항 1', r1, isSupport: false)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: tile('지지 2', s2, isSupport: true)),
            const SizedBox(width: 8),
            Expanded(child: tile('저항 2', r2, isSupport: false)),
          ],
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    final future = (_mode == ChartMode.daily) ? _dailyFuture : _intradayFuture;

    return _baseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.symbol,
                  style: _t(size: 16, weight: FontWeight.w900, color: kInk),
                ),
              ),
              _buildChartModeSelector(),
            ],
          ),
          if ((widget.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.description!, style: _t(size: 11, color: kMuted)),
          ],
          const SizedBox(height: 10),
          FutureBuilder<List<Candle>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox(
                  height: 220,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text('차트 데이터 불러오는 중...', style: _t(size: 12, color: kMuted)),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  height: 220,
                  alignment: Alignment.center,
                  child: Text(
                    '차트 로딩 실패: ${snapshot.error}',
                    style: _t(size: 12, color: const Color(0xFFDC2626), height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final candles = snapshot.data ?? const <Candle>[];
              if (candles.isEmpty) {
                return Container(
                  height: 220,
                  alignment: Alignment.center,
                  child: Text('표시할 데이터가 없어요.', style: _t(size: 12, color: kMuted)),
                );
              }

              return SizedBox(
                height: 240,
                child: CandleChart(candles: candles)
                ,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text('BALRAIN', style: _t(size: 15, weight: FontWeight.w900, color: kInk)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: [
            _buildChartCard(),
            const SizedBox(height: 10),

            _buildCategoryTabs(),
            const SizedBox(height: 10),
            _buildModuleChips(),
            const SizedBox(height: 8),
            _buildTechCategoryHint(),

            const SizedBox(height: 12),
            _buildCurrentModuleContent(),

            const SizedBox(height: 10),
            _buildAiSummaryCard(),

            const SizedBox(height: 30),
            Center(
              child: Text(
                '베타 기능 · AI 코멘트는 참고용입니다.',
                style: _t(size: 10.5, color: _a(kMuted, 0.85)),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
