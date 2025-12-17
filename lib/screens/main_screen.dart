import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stock_models.dart';
import '../theme/app_colors.dart';
import '../widgets/stock_tile.dart';
import '../screens/ticker_screen.dart';

import '../models/news_item.dart';
import '../services/news_service.dart';

/* ===== 오늘의 하이라이트용 타입 ===== */
enum HighlightSource { ai, news }

class _HL {
  final String sym, name, reason;
  final HighlightSource src;
  final double? last, pct;
  final List<double> spark;

  // (뉴스용 추가 필드 - 여기서는 뉴스라인 UI에서 직접 NewsItem 사용하니 최소만 유지)
  final String? url;
  final DateTime? publishedAt;
  final String? source;

  const _HL(
      this.sym,
      this.name,
      this.reason,
      this.src, {
        this.last,
        this.pct,
        this.spark = const [],
        this.url,
        this.publishedAt,
        this.source,
      });
}

/* ===== Finnhub Quote (실시간 가격/등락) ===== */
class _Quote {
  final double? last; // c
  final double? dp; // dp (%)
  const _Quote({this.last, this.dp});

  factory _Quote.fromJson(Map<String, dynamic> j) {
    double? d(dynamic v) => v is num ? v.toDouble() : null;
    return _Quote(
      last: d(j['c']),
      dp: d(j['dp']),
    );
  }
}

/* ================================ MAIN HOME ================================ */

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<SearchResult> _results = [];

  static const _apiBase = 'https://finnhub.io/api/v1';
  static final _token = const String.fromEnvironment('FINNHUB_TOKEN');

  // ✅ 오늘의 하이라이트 뉴스 Future (모델 NewsItem 사용)
  late Future<NewsItem?> _highlightNewsFuture;

  // ✅ 종목별 quote 캐시
  final Map<String, Future<_Quote?>> _quoteFutureCache = {};

  // ✅ (고급) 뉴스 문자열 -> 티커 확정 캐시
  final Map<String, Future<String?>> _resolveSymbolCache = {};

  @override
  void initState() {
    super.initState();
    _highlightNewsFuture = NewsService.fetchHighlight();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _error = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (q.trim().isEmpty) {
        setState(() => _results = []);
      } else {
        _searchSymbols(q.trim());
      }
    });
  }

  Future<void> _searchSymbols(String q) async {
    if (_token.isEmpty) {
      setState(() {
        _error = kDebugMode
            ? 'API 키가 없습니다. flutter run --dart-define=FINNHUB_TOKEN=... 으로 실행하세요.'
            : '시세 서버 설정이 아직 완료되지 않았어요. 잠시 후 다시 시도해 주세요.';
        _results = [];
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_apiBase/search?q=${Uri.encodeComponent(q)}&token=$_token');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['result'] as List<dynamic>? ?? [])
          .map((e) => SearchResult.fromJson(e))
          .where((e) => e.symbol.isNotEmpty)
          .toList();

      // 한국/KOSPI, 미국/나스닥 우선 정렬
      list.sort((a, b) {
        int exScore(SearchResult r) {
          final ex = r.exchange.toUpperCase();
          if (ex.contains('KOREA') || ex.contains('KOSPI') || ex == 'KS') return 0;
          if (ex.contains('NASDAQ') || ex == 'US') return 1;
          return 2;
        }

        final aScore = exScore(a);
        final bScore = exScore(b);
        if (aScore != bScore) return aScore - bScore;

        final qLower = q.toLowerCase();
        int matchScore(SearchResult r) {
          int s = 0;
          if (r.symbol.toLowerCase().startsWith(qLower)) s -= 2;
          if (r.description.toLowerCase().contains(qLower)) s -= 1;
          return s;
        }

        return matchScore(a) - matchScore(b);
      });

      setState(() {
        _results = list.take(20).toList();
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '검색 실패: $e';
        _results = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goDetailSymbol(String symbol, {String? description}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TickerScreen(symbol: symbol, description: description),
      ),
    );
  }

  void _goDetail(SearchResult r) {
    String sym = r.symbol;
    final ex = (r.exchange).toUpperCase();
    if (RegExp(r'^\d{6}$').hasMatch(sym)) {
      if (ex == 'KQ' || ex.contains('KOSDAQ')) {
        sym = '$sym.KQ';
      } else {
        sym = '$sym.KS';
      }
    }
    _goDetailSymbol(sym, description: r.description);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /* ================================ NEWS -> SYMBOL (중요) ================================ */

  Future<String?> _resolveSymbolFromQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    if (_token.isEmpty) return null;

    return _resolveSymbolCache.putIfAbsent(q, () async {
      try {
        final uri = Uri.parse('$_apiBase/search?q=${Uri.encodeComponent(q)}&token=$_token');
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return null;

        final j = jsonDecode(res.body);
        if (j is! Map<String, dynamic>) return null;

        final results = (j['result'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((e) => SearchResult.fromJson(e))
            .toList();
        if (results.isEmpty) return null;

        int score(SearchResult r) {
          final sym = r.symbol.toUpperCase();
          final desc = r.description.toUpperCase();
          final ex = r.exchange.toUpperCase();
          final qq = q.toUpperCase();

          int s = 0;
          if (sym == qq) s += 100;
          if (desc == qq) s += 80;
          if (desc.contains(qq)) s += 25;

          // US 우선(원하면 여기서 KS/KQ 우선으로 바꿀 수 있음)
          if (ex.contains('NASDAQ') || ex.contains('NYSE') || ex == 'US') s += 20;

          if (sym.length >= 10) s -= 15;
          return s;
        }

        results.sort((a, b) => score(b).compareTo(score(a)));
        final picked = results.first.symbol.trim();
        return picked.isEmpty ? null : picked;
      } catch (_) {
        return null;
      }
    });
  }

  Future<String?> _resolveSymbolFromNewsItem(NewsItem item) async {
    final candidates = <String>{};

    // 1) related 우선 (여기에 CEO/회사명도 섞일 수 있음)
    for (final r in item.related) {
      final x = r.trim();
      if (x.isNotEmpty) candidates.add(x);
    }

    // 2) headline에서 후보 몇 개 뽑기 (너무 공격적이면 오탐 나서 6개만)
    final headline = item.headline.trim();
    if (headline.isNotEmpty) {
      final words = headline
          .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3)
          .take(6);
      candidates.addAll(words);
    }

    // 3) candidates를 /search에 넣어서 티커 확정
    for (final c in candidates) {
      final sym = await _resolveSymbolFromQuery(c);
      if (sym == null || sym.isEmpty) continue;

      // 너무 이상한 것 필터(원하면 강화)
      if (sym.length > 12) continue;

      return sym;
    }

    return null;
  }

  Future<_Quote?> _fetchQuote(String symbol) async {
    if (_token.isEmpty) return null;
    final sym = symbol.trim();
    if (sym.isEmpty) return null;

    try {
      final uri = Uri.parse('$_apiBase/quote?symbol=${Uri.encodeComponent(sym)}&token=$_token');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body);
      if (j is! Map<String, dynamic>) return null;
      return _Quote.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  Future<_Quote?> _quoteFutureOf(String symbol) {
    final key = symbol.trim();
    return _quoteFutureCache.putIfAbsent(key, () => _fetchQuote(key));
  }

  /* ---------- Header / Search ---------- */

  Widget _brandHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BALRAIN',
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              color: kBrand,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rational Market Insight',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.notoSansKr(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '종목명/티커 검색 (예: 삼성전자, 005930, NVDA)',
          hintStyle: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
          ),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: kBrand,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: kInk,
            ),
          ),
        ],
      ),
    );
  }

  /* ---------- 네이버 순위 느낌 뉴스 라인 ---------- */

  Widget _newsRankRow(NewsItem item) {
    return InkWell(
      onTap: () => _openUrl(item.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.trending_up_rounded, size: 18, color: kBrand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _thinDivider() => Container(
    height: 1,
    margin: const EdgeInsets.only(left: 32),
    color: const Color(0xFFE5E7EB),
  );

  /* ---------- Highlights ---------- */

  Widget _highlightsBlock() {
    Widget badge(HighlightSource src, {String? labelOverride}) {
      final label = labelOverride ?? (src == HighlightSource.ai ? 'AI 신호' : '뉴스 신호');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: src == HighlightSource.ai ? kBrand : Colors.grey[700],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
        ],
      );
    }

    CustomPainter spark(List<double> p, Color color) => _SparkPainter(p, color);

    Widget heroCard(_HL it) {
      final up = (it.pct ?? 0) >= 0;
      final delta = it.pct == null ? '--' : '${it.pct! >= 0 ? '+' : ''}${it.pct!.toStringAsFixed(2)}%';
      final isNews = it.src == HighlightSource.news && (it.url ?? '').isNotEmpty;

      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (isNews) {
            _openUrl(it.url!);
          } else {
            _goDetailSymbol(it.sym, description: it.name);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBrand.withOpacity(0.06)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        badge(
                          it.src,
                          labelOverride: (it.src == HighlightSource.ai && it.reason.startsWith('뉴스 기반'))
                              ? 'AI 신호 · 뉴스 기반'
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          it.sym,
                          style: GoogleFonts.robotoMono(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: kBrand,
                          ),
                        ),
                        const Spacer(),
                        if (isNews)
                          const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      it.name,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      it.reason,
                      maxLines: isNews ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13,
                        color: kMuted,
                        height: 1.3,
                      ),
                    ),
                    if (isNews && it.publishedAt != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${it.source ?? ''} · ${DateFormat('M/d HH:mm').format(it.publishedAt!)}',
                        style: GoogleFonts.notoSansKr(fontSize: 11, color: kMuted),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            it.last == null ? '--' : NumberFormat('#,##0.##').format(it.last),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (up ? kUp : kDown).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              delta,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: up ? kUp : kDown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (it.spark.length >= 2) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  height: 70,
                  child: CustomPaint(painter: spark(it.spark, up ? kUp : kDown)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // fallback hero (뉴스/티커 못잡을 때)
    const fallbackHero = _HL(
      'HOT',
      'Hot Topic',
      '오늘 뉴스에서 관련 종목을 찾지 못했어요.',
      HighlightSource.ai,
      last: null,
      pct: null,
      spark: [],
    );

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2FF), Color(0xFFE0ECFF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀 칩
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '오늘의 하이라이트',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kBrand,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '핫 뉴스 → 관련 종목(티커) 확정 → 바로 분석 화면으로 연결돼요.',
              style: GoogleFonts.notoSansKr(fontSize: 11, color: kMuted, height: 1.4),
            ),
            const SizedBox(height: 14),

            // ✅ 1) 뉴스 (네이버 순위 느낌)
            FutureBuilder<NewsItem?>(
              future: _highlightNewsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kBrand.withOpacity(0.06)),
                    ),
                    child: const LinearProgressIndicator(minHeight: 3),
                  );
                }

                final item = snap.data;
                if (item == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kBrand.withOpacity(0.06)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '오늘의 핫 뉴스 정보를 불러오지 못했어요.',
                      style: GoogleFonts.notoSansKr(fontSize: 13, color: kMuted),
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kBrand.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      _newsRankRow(item),
                      _thinDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 8, 12, 12),
                        child: Row(
                          children: [
                            Text(
                              '${item.source} · ${DateFormat('M/d HH:mm').format(item.datetime)}',
                              style: GoogleFonts.notoSansKr(fontSize: 11, color: kMuted),
                            ),
                            const Spacer(),
                            Text(
                              '원문',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: kBrand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // ✅ 2) 뉴스가 말하는 종목을 "AI 신호 카드" 1개로 생성 (샘플 카드 제거)
            FutureBuilder<NewsItem?>(
              future: _highlightNewsFuture,
              builder: (context, newsSnap) {
                final item = newsSnap.data;

                if (item == null) {
                  return heroCard(fallbackHero);
                }

                // 뉴스에서 회사명/CEO/키워드 섞여도 search로 티커 확정
                return FutureBuilder<String?>(
                  future: _resolveSymbolFromNewsItem(item),
                  builder: (context, symSnap) {
                    if (symSnap.connectionState == ConnectionState.waiting) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kBrand.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '뉴스 관련 종목 찾는 중…',
                              style: GoogleFonts.notoSansKr(fontSize: 13, color: kMuted),
                            ),
                          ],
                        ),
                      );
                    }

                    final sym = (symSnap.data ?? '').trim();
                    if (sym.isEmpty) {
                      return heroCard(fallbackHero);
                    }

                    return FutureBuilder<_Quote?>(
                      future: _quoteFutureOf(sym),
                      builder: (context, qSnap) {
                        final q = qSnap.data;
                        final hl = _HL(
                          sym,
                          sym,
                          '뉴스 기반 종목: ${item.headline}',
                          HighlightSource.ai,
                          last: q?.last,
                          pct: q?.dp,
                          spark: const [],
                        );
                        return heroCard(hl);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ---------- US/KR Lists (StockTile 사용) ---------- */

  Widget _usTechList() {
    const items = <List<String>>[
      ['MSFT', 'Microsoft', 'AI 클라우드 리더'],
      ['META', 'Meta', '광고·SNS 플랫폼'],
      ['GOOGL', 'Alphabet', '검색·유튜브 플랫폼'],
      ['AMZN', 'Amazon', '이커머스·클라우드'],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            StockTile(
              rank: i + 1,
              name: items[i][1],
              symbol: items[i][0],
              subtitle: items[i][2],
              onTap: () => _goDetailSymbol(items[i][0], description: items[i][1]),
              showDivider: i != items.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _krList() {
    const items = <List<String>>[
      ['000660.KS', 'SK하이닉스', '메모리 반도체 리더'],
      ['035420.KS', 'NAVER', '국내 인터넷 플랫폼'],
      ['373220.KS', 'LG에너지솔루션', '2차전지 셀 제조'],
      ['005380.KS', '현대차', '글로벌 완성차'],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            StockTile(
              rank: i + 1,
              name: items[i][1],
              symbol: items[i][0],
              subtitle: items[i][2],
              onTap: () => _goDetailSymbol(items[i][0], description: items[i][1]),
              showDivider: i != items.length - 1,
            ),
        ],
      ),
    );
  }

  /* ---------- Build ---------- */

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _brandHeader()),
            SliverToBoxAdapter(child: _searchBar()),

            if (_loading)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 3),
              ),

            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ),

            if (_results.isNotEmpty)
              SliverList.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return ListTile(
                    title: Text(
                      r.symbol,
                      style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      r.description.isEmpty ? r.exchange : '${r.description} • ${r.exchange}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSansKr(color: Colors.grey[700]),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _goDetail(r),
                  );
                },
              )
            else if (hasQuery)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    '"${_controller.text.trim()}" 에 대한 검색 결과가 없어요.\n티커(예: NVDA)나 다른 키워드로 다시 시도해 보세요.',
                    style: GoogleFonts.notoSansKr(fontSize: 13, color: kMuted),
                  ),
                ),
              )
            else ...[
                SliverToBoxAdapter(child: _highlightsBlock()),
                const SliverToBoxAdapter(child: SectionDivider(top: 20, bottom: 4)),
                SliverToBoxAdapter(child: _sectionTitle('미국 Tech Top Picks')),
                SliverToBoxAdapter(child: _usTechList()),
                const SliverToBoxAdapter(child: SectionDivider()),
                SliverToBoxAdapter(child: _sectionTitle('한국 대표주')),
                SliverToBoxAdapter(child: _krList()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
          ],
        ),
      ),
    );
  }
}

/* ======================= Sparkline Painter ======================= */

class _SparkPainter extends CustomPainter {
  final List<double> p;
  final Color color;
  _SparkPainter(this.p, this.color);

  @override
  void paint(Canvas c, Size s) {
    if (p.length < 2) return;
    final mn = p.reduce(math.min), mx = p.reduce(math.max);
    final dx = s.width / (p.length - 1);
    final path = Path();
    for (var i = 0; i < p.length; i++) {
      final t = (p[i] - mn) / ((mx - mn) == 0 ? 1 : (mx - mn));
      final y = s.height - t * s.height, x = i * dx;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.p != p || o.color != color;
}
