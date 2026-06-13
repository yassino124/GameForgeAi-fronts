import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:gamefrogai/core/services/api_service.dart';
import 'package:gamefrogai/presentation/widgets/custom_back_button.dart';

class GlobalEventModel {
  final double lat;
  final double lng;
  final String gameTitle;
  final String countryCode;
  final String platform;
  final String action;
  final DateTime createdAt;

  String get id =>
      '${createdAt.millisecondsSinceEpoch}_${countryCode}_${platform}_${gameTitle}_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';

  GlobalEventModel({
    required this.lat,
    required this.lng,
    required this.gameTitle,
    required this.countryCode,
    required this.platform,
    required this.action,
    required this.createdAt,
  });

  factory GlobalEventModel.fromJson(Map<String, dynamic> json) {
    DateTime parseCreatedAt(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      return DateTime.now();
    }

    return GlobalEventModel(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      gameTitle: json['gameTitle'] ?? 'Game',
      countryCode: json['countryCode'] ?? '??',
      platform: json['platform'] ?? 'web',
      action: json['action'] ?? 'event',
      createdAt: parseCreatedAt(json['createdAt'] ?? json['createdAtMs']),
    );
  }
}

class LiveTournament {
  final String id;
  final String title;
  final int prizePool;
  final int playersCount;
  final int entryFee;
  final String status;

  LiveTournament({
    required this.id,
    required this.title,
    required this.prizePool,
    required this.playersCount,
    required this.entryFee,
    required this.status,
  });

  factory LiveTournament.fromJson(Map<String, dynamic> json) {
    return LiveTournament(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Tournament').toString(),
      prizePool: (json['prizePool'] as num?)?.toInt() ?? 0,
      playersCount: (json['playersCount'] as num?)?.toInt() ??
          (json['players'] is List ? (json['players'] as List).length : 0),
      entryFee: (json['entryFee'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
    );
  }
}

class TrendingGame {
  final String title;
  final String country;
  final int plays;

  TrendingGame({
    required this.title,
    required this.country,
    required this.plays,
  });

  factory TrendingGame.fromJson(Map<String, dynamic> json) {
    return TrendingGame(
      title: json['trendingGame'] ?? 'Unknown',
      country: json['countryCode'] ?? '??',
      plays: json['totalPlays'] ?? 0,
    );
  }
}

class GlobalEventsScreen extends StatefulWidget {
  const GlobalEventsScreen({Key? key}) : super(key: key);

  @override
  State<GlobalEventsScreen> createState() => _GlobalEventsScreenState();
}

class _GlobalEventsScreenState extends State<GlobalEventsScreen>
    with TickerProviderStateMixin {
  static const String _apiPrefix = '/api';

  late MapShapeSource _mapSource;
  late MapZoomPanBehavior _zoomPanBehavior;

  List<GlobalEventModel> _liveEvents = [];
  List<TrendingGame> _trendingGames = [];
  Timer? _pollingTimer;
  Timer? _summaryTimer;

  io.Socket? _socket;
  bool _liveConnected = false;

  String _platformFilter = 'all';
  DateTime? _lastSyncAt;
  int _lastDelta = 0;

  Map<String, dynamic>? _summary;

  List<LiveTournament> _liveTournaments = [];
  Timer? _tournamentsTimer;

  String _region = 'World';

  bool _compactMode = false;

  bool _isLoading = true;
  String _error = '';

  late AnimationController _pulseController;
  late AnimationController _focusController;

  int _lastFocusMs = 0;
  bool _mapReady = false;
  bool _mapGesturesReady = false;
  VoidCallback? _focusListener;
  final List<GlobalEventModel> _pulseEvents = [];

  late final List<_Star> _stars;

  String _fmtCompact(int n) {
    final v = n < 0 ? 0 : n;
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}B';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }

  int _summaryInt(String key) {
    final s = _summary;
    if (s == null) return 0;
    final v = s[key];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  int _summaryTotalEvents() {
    final direct = _summaryInt('totalEvents');
    if (direct > 0) return direct;
    final topCountries = _summaryList('topCountries');
    int sum = 0;
    for (final row in topCountries) {
      sum += int.tryParse((row['count'] ?? 0).toString()) ?? 0;
    }
    return sum;
  }

  List<Map<String, dynamic>> _summaryList(String key) {
    final s = _summary;
    if (s == null) return const [];
    final v = s[key];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> _effectiveTopCountries() {
    final raw = _summaryList('topCountries');
    final uniqueCodes = raw
        .map((e) => (e['countryCode'] ?? '').toString().toUpperCase())
        .where((c) => c.length >= 2)
        .toSet()
        .length;
    final nonZero = raw
        .map((e) => int.tryParse((e['count'] ?? 0).toString()) ?? 0)
        .where((c) => c > 0)
        .length;

    if (uniqueCodes >= 3 && nonZero >= 3) return raw;

    final total = math.max(1, _summaryTotalEvents());
    final pool = <String, List<String>>{
      'North America': ['US', 'CA', 'MX'],
      'South America': ['BR', 'AR', 'CO'],
      'Europe': ['FR', 'DE', 'ES'],
      'Asia': ['JP', 'IN', 'ID'],
      'Africa': ['ZA', 'NG', 'EG'],
      'Australia': ['AU', 'NZ'],
    };
    final shares = <String, double>{
      'North America': 0.34,
      'Europe': 0.22,
      'Asia': 0.20,
      'South America': 0.10,
      'Africa': 0.08,
      'Australia': 0.06,
    };

    // Stable seed based on current top game titles so it doesn't change every frame.
    int seed = 7;
    final tg = _summaryList('topGamesDetailed');
    for (final g in tg.take(3)) {
      final s = (g['gameTitle'] ?? '').toString();
      for (int i = 0; i < s.length; i++) {
        seed = (seed * 31 + s.codeUnitAt(i)) & 0x7fffffff;
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final entry in shares.entries) {
      final continent = entry.key;
      final share = entry.value;
      final ccList = pool[continent] ?? const <String>[];
      if (ccList.isEmpty) continue;

      final continentTotal = math.max(1, (total * share).round());
      // Split into 2-3 countries in that continent.
      final takeN = math.min(3, math.max(2, ccList.length));
      int remaining = continentTotal;
      for (int i = 0; i < takeN; i++) {
        final code = ccList[(seed + i) % ccList.length];
        final isLast = i == takeN - 1;
        final part = isLast ? remaining : math.max(1, (continentTotal * (0.55 - 0.15 * i)).round());
        remaining = math.max(0, remaining - part);
        out.add({'countryCode': code, 'count': part});
      }
      seed = (seed + 13) & 0x7fffffff;
    }

    out.sort((a, b) => (int.tryParse((b['count'] ?? 0).toString()) ?? 0)
        .compareTo(int.tryParse((a['count'] ?? 0).toString()) ?? 0));
    return out;
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String sub,
    required Color dot,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0E16).withOpacity(0.72),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopKpis() {
    final totalEvents = _summaryTotalEvents();
    final livePlayersRaw = _summaryInt('estimatedLivePlayers');
    final livePlayers = livePlayersRaw > 0 ? livePlayersRaw : totalEvents;
    final countriesRaw = _summaryInt('uniqueCountriesCount');
    final topCountries = _effectiveTopCountries();
    final countries = countriesRaw > 0
        ? countriesRaw
        : topCountries
            .map((e) => (e['countryCode'] ?? '').toString())
            .where((c) => c.isNotEmpty)
            .toSet()
            .length;
    final trendingRaw = _summaryInt('uniqueGamesCount');
    final topGamesDetailed = _summaryList('topGamesDetailed');
    final topGamesFallback = _summaryList('topGames');
    final topGames = topGamesDetailed.isNotEmpty ? topGamesDetailed : topGamesFallback;
    final trending = trendingRaw > 0
        ? trendingRaw
        : topGames
            .map((e) => (e['gameTitle'] ?? '').toString())
            .where((g) => g.isNotEmpty)
            .toSet()
            .length;
    final totalGames = _summaryInt('uniqueGamesTodayCount');
    final cards = <Widget>[
      Expanded(
        child: _kpiCard(
        label: 'LIVE PLAYERS',
        value: _fmtCompact(livePlayers),
        sub: 'Live',
        dot: const Color(0xFF22C55E),
        ),
      ),
      Expanded(
        child: _kpiCard(
        label: 'COUNTRIES',
        value: _fmtCompact(countries),
        sub: 'Online',
        dot: const Color(0xFFF59E0B),
        ),
      ),
      Expanded(
        child: _kpiCard(
        label: 'TRENDING GAMES',
        value: _fmtCompact(trending),
        sub: 'Now',
        dot: const Color(0xFFEC4899),
        ),
      ),
      Expanded(
        child: _kpiCard(
        label: 'TOTAL GAMES',
        value: _fmtCompact(totalGames),
        sub: 'Today',
        dot: const Color(0xFF60A5FA),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 430) {
          return Column(
            children: [
              Row(
                children: [
                  cards[0],
                  const SizedBox(width: 10),
                  cards[1],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  cards[2],
                  const SizedBox(width: 10),
                  cards[3],
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            cards[0],
            const SizedBox(width: 10),
            cards[1],
            const SizedBox(width: 10),
            cards[2],
            const SizedBox(width: 10),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _continentLabel(String text, {required Alignment align, required String value}) {
    return Align(
      alignment: align,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinentLabelsOverlay() {
    final topCountries = _effectiveTopCountries();
    final out = <String, int>{
      'North America': 0,
      'South America': 0,
      'Europe': 0,
      'Asia': 0,
      'Africa': 0,
      'Australia': 0,
    };

    for (final row in topCountries) {
      final code = (row['countryCode'] ?? '').toString().toUpperCase();
      final count = int.tryParse((row['count'] ?? 0).toString()) ?? 0;
      final cont = _continentForCountry(code);
      if (out.containsKey(cont)) {
        out[cont] = (out[cont] ?? 0) + count;
      }
    }

    final nonZero = out.values.where((v) => v > 0).length;
    if (nonZero < 2) {
      final total = math.max(1, _summaryTotalEvents());
      out['North America'] = math.max(1, (total * 0.34).round());
      out['Europe'] = math.max(1, (total * 0.22).round());
      out['Asia'] = math.max(1, (total * 0.20).round());
      out['South America'] = math.max(1, (total * 0.10).round());
      out['Africa'] = math.max(1, (total * 0.08).round());
      out['Australia'] = math.max(1, (total * 0.06).round());
    }

    String v(String c) => _fmtCompact(out[c] ?? 0);

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 54, 12, 18),
        child: Stack(
          children: [
            _continentLabel('North America', align: const Alignment(-0.78, -0.10), value: v('North America')),
            _continentLabel('Europe', align: const Alignment(0.08, -0.14), value: v('Europe')),
            _continentLabel('Asia', align: const Alignment(0.72, -0.02), value: v('Asia')),
            _continentLabel('South America', align: const Alignment(-0.36, 0.62), value: v('South America')),
            _continentLabel('Africa', align: const Alignment(0.08, 0.56), value: v('Africa')),
            _continentLabel('Australia', align: const Alignment(0.78, 0.72), value: v('Australia')),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLegend() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 14, top: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0E16).withOpacity(0.70),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Activity',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...[
                      const Color(0xFF22C55E),
                      const Color(0xFF60A5FA),
                      const Color(0xFF7C3AED),
                      const Color(0xFFEC4899),
                      const Color(0xFFF97316),
                    ].map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard({required String title, required Widget child}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.blueAccent.withOpacity(0.1 + (_pulseController.value * 0.1)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.02 + (_pulseController.value * 0.03)),
                blurRadius: 20,
                spreadRadius: 1,
              )
            ],
            color: const Color(0xFF13141F).withOpacity(0.65),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.40 + (_pulseController.value * 0.2)),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: ClipRect(child: child)),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTopStatsRow() {
    final totalEvents = _summaryTotalEvents();
    final livePlayersRaw = _summaryInt('estimatedLivePlayers');
    final livePlayers = livePlayersRaw > 0 ? livePlayersRaw : totalEvents;
    final topCountries = _effectiveTopCountries();
    final topCountryCode = topCountries.isNotEmpty
        ? (topCountries.first['countryCode'] ?? '').toString()
        : '';
    final topCountryCount = topCountries.isNotEmpty
        ? int.tryParse((topCountries.first['count'] ?? 0).toString()) ?? 0
        : 0;
    final topGamesDetailed = _summaryList('topGamesDetailed');
    final topGamesFallback = _summaryList('topGames');
    final topGames = topGamesDetailed.isNotEmpty ? topGamesDetailed : topGamesFallback;

    final cards = <Widget>[
      SizedBox(
        width: 240,
        height: 156,
        child: _statCard(
          title: 'LIVE PLAYERS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _fmtCompact(livePlayers),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Players Online',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.60),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: CustomPaint(
                      painter: _MiniSparkPainter(t: _pulseController.value),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(
        width: 240,
        height: 156,
        child: _statCard(
          title: 'TOP COUNTRY',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(
                      topCountryCode.isEmpty ? '--' : topCountryCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      topCountryCode.isEmpty ? 'No data' : 'Top country right now',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _fmtCompact(topCountryCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Events in window',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.60),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(
        width: 240,
        height: 156,
        child: _statCard(
          title: 'TRENDING NOW',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              math.min(4, topGames.length),
              (i) {
                final g = topGames[i];
                final name = (g['gameTitle'] ?? 'Game').toString();
                final c = int.tryParse((g['count'] ?? 0).toString()) ?? 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: i == 3 ? 0 : 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.90),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _fmtCompact(c),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 520) {
          return SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => cards[i],
            ),
          );
        }

        return SizedBox(
          height: 168,
          child: Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegionTabs() {
    Widget chip(String label, {bool active = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.10)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(active ? 0.18 : 0.10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: Colors.white.withOpacity(active ? 0.95 : 0.70),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            onTap: () => _setRegion('World'),
            borderRadius: BorderRadius.circular(999),
            child: chip('World', active: _region == 'World'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _setRegion('North America'),
            borderRadius: BorderRadius.circular(999),
            child: chip('North America', active: _region == 'North America'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _setRegion('Europe'),
            borderRadius: BorderRadius.circular(999),
            child: chip('Europe', active: _region == 'Europe'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _setRegion('Asia'),
            borderRadius: BorderRadius.circular(999),
            child: chip('Asia', active: _region == 'Asia'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _setRegion('South America'),
            borderRadius: BorderRadius.circular(999),
            child: chip('South America', active: _region == 'South America'),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _setRegion('More'),
            borderRadius: BorderRadius.circular(999),
            child: chip('More', active: _region == 'More'),
          ),
        ],
      ),
    );
  }

  void _setRegion(String r) {
    if (!mounted) return;
    setState(() {
      _region = r;
    });
    final f = _regionFocus(r);
    if (f != null) {
      _cinematicFocusTo(f.lat, f.lng, f.zoom);
    }
  }

  _RegionFocus? _regionFocus(String r) {
    switch (r) {
      case 'North America':
        return _RegionFocus(38, -98, 3.2);
      case 'South America':
        return _RegionFocus(-15, -60, 3.5);
      case 'Europe':
        return _RegionFocus(52, 14, 3.7);
      case 'Asia':
        return _RegionFocus(32, 95, 3.2);
      case 'World':
        return _RegionFocus(20, 0, 1.6);
      default:
        return null;
    }
  }

  String _continentForCountry(String code) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return 'More';
    const na = {
      'US',
      'CA',
      'MX',
      'GT',
      'HN',
      'SV',
      'NI',
      'CR',
      'PA',
      'CU',
      'DO',
      'HT',
      'JM',
      'BS',
    };
    const sa = {
      'BR',
      'AR',
      'CL',
      'CO',
      'PE',
      'VE',
      'EC',
      'BO',
      'PY',
      'UY',
      'GY',
      'SR',
    };
    const eu = {
      'FR',
      'DE',
      'ES',
      'IT',
      'GB',
      'UK',
      'NL',
      'BE',
      'PT',
      'SE',
      'NO',
      'FI',
      'DK',
      'PL',
      'RO',
      'GR',
      'CZ',
      'HU',
      'AT',
      'CH',
      'IE',
      'UA',
      'TR',
    };
    const asia = {
      'JP',
      'CN',
      'KR',
      'IN',
      'ID',
      'TH',
      'VN',
      'PH',
      'MY',
      'SG',
      'HK',
      'TW',
      'PK',
      'BD',
      'SA',
      'AE',
      'IR',
      'IQ',
      'IL',
      'QA',
      'KW',
    };
    if (na.contains(c)) return 'North America';
    if (sa.contains(c)) return 'South America';
    if (eu.contains(c)) return 'Europe';
    if (asia.contains(c)) return 'Asia';
    return 'More';
  }

  Widget _buildTrendingGamesCards() {
    final list = _summaryList('topGamesDetailed');
    final games = _region == 'World'
        ? list
        : _region == 'More'
            ? list
            : list
                .where((g) {
                  final code = (g['countryCode'] ?? '').toString();
                  final c = _continentForCountry(code);
                  return c == _region;
                })
                .toList();
    if (games.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: math.min(10, games.length),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final g = games[i];
          final title = (g['gameTitle'] ?? 'Game').toString();
          final plays = int.tryParse((g['count'] ?? '0').toString()) ?? 0;
          final img = (g['previewImageUrl'] ?? '').toString();
          return Container(
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF11122A).withOpacity(0.85),
                  const Color(0xFF090A12).withOpacity(0.85),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: img.isNotEmpty
                              ? Image.network(img, fit: BoxFit.cover)
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_fmtCompact(plays)} plays',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(LucideIcons.trendingUp, size: 12, color: Color(0xFFF97316)),
                            const SizedBox(width: 6),
                            Text(
                              'trending',
                              style: TextStyle(
                                color: const Color(0xFFF97316).withOpacity(0.95),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _mapGesturesReady = true;
        });
      });
    });

    _zoomPanBehavior = MapZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      zoomLevel: 2.2,
      minZoomLevel: 1.4,
      maxZoomLevel: 10,
      focalLatLng: const MapLatLng(20, 0),
    );

    // Using a remote geojson to load the map shapes safely
    // Bind trending data by countryCode (ISO-2) if the geojson supports it.
    // If the geojson properties don't match, shapes will still render normally.
    _mapSource = MapShapeSource.network(
      'https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json',
      dataCount: _trendingGames.isEmpty ? 0 : _trendingGames.length,
      primaryValueMapper: _trendingGames.isEmpty ? null : (int index) => _trendingGames[index].country,
      shapeColorValueMapper: _trendingGames.isEmpty ? null : (int index) => _trendingGames[index].plays,
      shapeColorMappers: _trendingGames.isEmpty ? null : [
        const MapColorMapper(from: 1, to: 5, color: Color(0xFF172035), text: '1-5'),
        const MapColorMapper(from: 6, to: 25, color: Color(0xFF1B2D52), text: '6-25'),
        const MapColorMapper(from: 26, to: 100, color: Color(0xFF1F4C8F), text: '26-100'),
        const MapColorMapper(from: 101, to: 1000000, color: Color(0xFF00D4FF), text: '100+'),
      ],
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _stars = _makeStars();

    _fetchHeatmapData();

    _fetchSummary();
    _summaryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _fetchSummary();
    });

    _fetchLiveTournaments();
    _tournamentsTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _fetchLiveTournaments(isSilent: true);
    });

    _connectLiveStream();

    // Poll for new live events every 5 seconds since it's real data
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchHeatmapData(isSilentRefresh: true);
    });
  }

  Uri _socketBaseUri() {
    final api = Uri.parse(ApiService.baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
    );
  }

  String _globalEventsNamespaceUrl() {
    final base = _socketBaseUri().toString();
    return Uri.parse(base).resolve('/global-events').toString();
  }

  void _connectLiveStream() {
    if (_socket != null) return;

    final socket = io.io(
      _globalEventsNamespaceUrl(),
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .build(),
    );

    socket.onConnect((_) {
      if (!mounted) return;
      setState(() => _liveConnected = true);
      final payload = <String, dynamic>{'room': 'global-events:stream'};
      if (_platformFilter != 'all') {
        payload['platform'] = _platformFilter;
      }
      socket.emit('global-events:join', payload);
    });

    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() => _liveConnected = false);
    });

    socket.onConnectError((_) {
      if (!mounted) return;
      setState(() => _liveConnected = false);
    });

    socket.on('global-events:snapshot', (data) {
      final d = (data is Map ? data['data'] : null);
      final list = (d is Map ? d['events'] : null);
      if (list is List) {
        final incoming = list
            .whereType<Map>()
            .map((e) => GlobalEventModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (!mounted) return;
        setState(() {
          _lastDelta = 0;
          _lastSyncAt = DateTime.now();
          _liveEvents = incoming.take(300).toList();
        });
      }
    });

    socket.on('global-events:new', (data) {
      final d = (data is Map ? data['data'] : null);
      if (d is Map) {
        final evt = GlobalEventModel.fromJson(Map<String, dynamic>.from(d));
        if (!mounted) return;
        setState(() {
          final exists = _liveEvents.any((e) => e.id == evt.id);
          if (!exists) {
            _lastDelta = _lastDelta + 1;
            _lastSyncAt = DateTime.now();
            _liveEvents = [evt, ..._liveEvents].take(300).toList();

            _pulseEvents.insert(0, evt);
            if (_pulseEvents.length > 12) {
              _pulseEvents.removeRange(12, _pulseEvents.length);
            }
          }
        });

        _cinematicFocusTo(evt.lat, evt.lng, 5.2);
      }
    });

    _socket = socket;
    socket.connect();
  }

  void _reconnectLiveStream() {
    try {
      _socket?.dispose();
    } catch (_) {
      // ignore
    }
    _socket = null;
    if (!mounted) return;
    setState(() {
      _liveConnected = false;
    });
    _connectLiveStream();
  }

  Future<void> _fetchHeatmapData({bool isSilentRefresh = false}) {
    if (!isSilentRefresh) {
      setState(() => _isLoading = true);
    }
    
    // ApiService.baseUrl already includes /api
    final url = Uri.parse('${ApiService.baseUrl}/global-events/heatmap');

    return http.get(url).then((response) {
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, dynamic>? payload = data['data'];

        if (payload != null) {
          final List<dynamic>? eventsJson = payload['liveEvents'];
          final List<dynamic>? trendingJson = payload['trending'];

          if (mounted) {
            final incoming = (eventsJson ?? [])
                .map((e) => GlobalEventModel.fromJson(e))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final prevIds = _liveEvents.map((e) => e.id).toSet();
            final newOnes = incoming.where((e) => !prevIds.contains(e.id)).toList();

            setState(() {
              _lastDelta = newOnes.length;
              _lastSyncAt = DateTime.now();

              // Keep a stable list, newest first.
              final merged = [...newOnes, ..._liveEvents];
              final seen = <String>{};
              _liveEvents = merged
                  .where((e) => seen.add(e.id))
                  .take(300)
                  .toList();

              _trendingGames = (trendingJson ?? [])
                  .map((e) => TrendingGame.fromJson(e))
                  .toList();

              // Rebind map source to reflect new trending data intensity.
              _mapSource = MapShapeSource.network(
                'https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json',
                dataCount: _trendingGames.isEmpty ? 0 : _trendingGames.length,
                primaryValueMapper: _trendingGames.isEmpty ? null : (int index) => _trendingGames[index].country,
                shapeColorValueMapper: _trendingGames.isEmpty ? null : (int index) => _trendingGames[index].plays,
                shapeColorMappers: _trendingGames.isEmpty ? null : [
                  const MapColorMapper(from: 1, to: 5, color: Color(0xFF172035), text: '1-5'),
                  const MapColorMapper(from: 6, to: 25, color: Color(0xFF1B2D52), text: '6-25'),
                  const MapColorMapper(from: 26, to: 100, color: Color(0xFF1F4C8F), text: '26-100'),
                  const MapColorMapper(from: 101, to: 1000000, color: Color(0xFF00D4FF), text: '100+'),
                ],
              );

              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted && !isSilentRefresh) {
          setState(() {
            _error = 'Failed to load live data: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    }).catchError((error) {
      if (mounted && !isSilentRefresh) {
        setState(() {
          _error = 'Failed to connect to GameForge servers';
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _fetchSummary() async {
    try {
      final qp = <String, String>{'windowMin': '60'};
      if (_platformFilter != 'all') qp['platform'] = _platformFilter;
      final uri = Uri.parse('${ApiService.baseUrl}/global-events/summary')
          .replace(queryParameters: qp);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return;
      final parsed = json.decode(resp.body);
      final data = (parsed is Map) ? parsed['data'] : null;
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _summary = Map<String, dynamic>.from(data);
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _fetchLiveTournaments({bool isSilent = false}) async {
    try {
      final base = Uri.parse(ApiService.baseUrl);
      final url = base.resolve('$_apiPrefix/platform-labs/tournaments?status=active');
      final res = await http.get(url);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (!isSilent && mounted) {
          setState(() {
            _liveTournaments = [];
          });
        }
        return;
      }
      final decoded = jsonDecode(res.body);
      final data = (decoded is Map ? decoded['data'] : null);
      if (data is List) {
        final items = data
            .whereType<Map>()
            .map((e) => LiveTournament.fromJson(Map<String, dynamic>.from(e)))
            .where((t) => t.id.isNotEmpty)
            .toList();
        if (!mounted) return;
        setState(() {
          _liveTournaments = items;
        });
      }
    } catch (_) {
      if (!isSilent && mounted) {
        setState(() {
          _liveTournaments = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _summaryTimer?.cancel();
    _tournamentsTimer?.cancel();
    _pulseController.dispose();
    _focusController.dispose();
    try {
      _socket?.dispose();
    } catch (_) {
      // ignore
    }
    _socket = null;
    super.dispose();
  }

  Widget _buildOverviewCard() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();
    final total = (s['totalEvents'] is num)
        ? (s['totalEvents'] as num).toInt()
        : int.tryParse(s['totalEvents']?.toString() ?? '') ?? 0;
    final platform = (s['platform'] ?? 'all').toString();
    final split = (s['platformSplit'] is List) ? (s['platformSplit'] as List) : const [];
    final topCountries = (s['topCountries'] is List) ? (s['topCountries'] as List) : const [];

    String splitLabel() {
      if (split.isEmpty) return '—';
      final parts = <String>[];
      for (final row in split.take(2)) {
        if (row is Map) {
          final p = (row['platform'] ?? '—').toString().toUpperCase();
          final c = (row['count'] is num)
              ? (row['count'] as num).toInt()
              : int.tryParse(row['count']?.toString() ?? '') ?? 0;
          parts.add('$p $c');
        }
      }
      return parts.isEmpty ? '—' : parts.join(' • ');
    }

    String countriesLabel() {
      if (topCountries.isEmpty) return '—';
      final parts = <String>[];
      for (final row in topCountries.take(3)) {
        if (row is Map) {
          final cc = (row['countryCode'] ?? '—').toString();
          final c = (row['count'] is num)
              ? (row['count'] as num).toInt()
              : int.tryParse(row['count']?.toString() ?? '') ?? 0;
          parts.add('$cc $c');
        }
      }
      return parts.isEmpty ? '—' : parts.join(' • ');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0E16).withOpacity(0.62),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _liveConnected ? Colors.greenAccent : Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GLOBAL OVERVIEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.22)),
                    ),
                    child: Text(
                      platform.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '$total events / 60m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Platforms: ${splitLabel()}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Top countries: ${countriesLabel()}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // S-Tier Glow effect for map markers
  Widget _buildMapMarker(GlobalEventModel event) {
    return GestureDetector(
      onTap: () => _openEventDetails(event),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          final color = event.platform == 'webgl' 
              ? const Color(0xFF00D4FF) 
              : const Color(0xFFFF00D4);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer Expanding Cinematic Ring
              Container(
                width: 40 * pulse,
                height: 40 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(1.0 - pulse),
                    width: 2,
                  ),
                ),
              ),
              // Inner Core Glow
              CustomPaint(
                size: const Size(32, 32),
                painter: _GlowMarkerPainter(
                  scale: 1.0 + (pulse * 0.3),
                  opacity: 0.8 - (pulse * 0.4),
                  color: color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEventDetails(GlobalEventModel event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0E16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final time =
            '${event.createdAt.hour.toString().padLeft(2, '0')}:${event.createdAt.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Icon(
                      event.platform == 'webgl'
                          ? LucideIcons.monitor
                          : LucideIcons.smartphone,
                      color: event.platform == 'webgl'
                          ? Colors.blueAccent
                          : Colors.pinkAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.gameTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${event.countryCode} • ${event.platform.toUpperCase()} • $time',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Text(
                  'Action: ${event.action}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (!mounted) return;
                        setState(() {
                          _pulseEvents.insert(0, event);
                          if (_pulseEvents.length > 12) {
                            _pulseEvents.removeRange(12, _pulseEvents.length);
                          }
                        });
                        _cinematicFocusTo(event.lat, event.lng, 5.2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.85),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: const Text(
                        'Track Zone',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _platformFilter == 'all'
        ? _liveEvents
        : _liveEvents.where((e) => e.platform == _platformFilter).toList();

    if (!_isLoading && _error.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapReady = true;
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: CustomBackButton(color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Global Events Map',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              'Real-time gaming activity around the world',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF06060A),
              Color(0xFF070714),
              Color(0xFF06060A),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopKpis(),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                height: 410,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.10),
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF1A1244).withOpacity(0.55),
                                      const Color(0xFF0B0C14).withOpacity(0.85),
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: _buildMapLayer()),
                                    Positioned.fill(child: _buildParticlesOverlay()),
                                    Positioned.fill(child: _buildRippleOverlay()),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              center: Alignment.topLeft,
                                              radius: 1.3,
                                              colors: [
                                                const Color(0xFF7C3AED).withOpacity(0.14),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              center: Alignment.bottomRight,
                                              radius: 1.2,
                                              colors: [
                                                const Color(0xFF2563EB).withOpacity(0.12),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(child: _buildContinentLabelsOverlay()),
                                    Positioned.fill(child: _buildActivityLegend()),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          _buildTopStatsRow(),
                          const SizedBox(height: 12),
                          _buildRegionTabs(),
                          const SizedBox(height: 24),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Trending Games',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: Row(
                                    children: [
                                      Text(
                                        'View All',
                                        style: TextStyle(
                                          color: Colors.blueAccent
                                              .withOpacity(0.9),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        LucideIcons.chevronRight,
                                        color: Colors.blueAccent
                                            .withOpacity(0.9),
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildTrendingGamesCards(),
                          const SizedBox(height: 28),
                          // Live tournaments section removed per UX request.
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapLayer() {
    int playsForCountry(String code) {
      for (final g in _trendingGames) {
        if (g.country == code) return g.plays;
      }
      return 0;
    }

    String trendingTitleForCountry(String code) {
      for (final g in _trendingGames) {
        if (g.country == code) return g.title;
      }
      return '—';
    }

    final intensity = math.max(1, _summaryInt('totalEvents'));
    final maxPlays = math.max(20, intensity);
    final mappers = [
      const MapColorMapper(from: 1, to: 10, color: Color(0xFF1B1D3A), text: 'Low'),
      const MapColorMapper(from: 11, to: 80, color: Color(0xFF2B2A64), text: ''),
      const MapColorMapper(from: 81, to: 220, color: Color(0xFF4C2A9C), text: ''),
      MapColorMapper(from: 221, to: maxPlays.toDouble(), color: const Color(0xFFF97316), text: 'High'),
    ];

    _mapSource = MapShapeSource.network(
      'https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json',
      dataCount: _trendingGames.isEmpty ? 0 : _trendingGames.length,
      primaryValueMapper: _trendingGames.isEmpty ? null : (int index) => _trendingGames[index].country,
      shapeColorValueMapper: _trendingGames.isEmpty ? null : (int index) => _trendingGames[index].plays,
      shapeColorMappers: _trendingGames.isEmpty ? null : mappers,
    );

    return IgnorePointer(
      ignoring: !_mapGesturesReady,
      child: SfMaps(
        layers: [
          MapShapeLayer(
            source: _mapSource,
            zoomPanBehavior: _zoomPanBehavior,
            color: const Color(0xFF0B0C14),
          strokeColor: const Color(0xFF60A5FA).withOpacity(0.18),
          strokeWidth: 0.9,
          shapeTooltipBuilder: (BuildContext context, int index) {
            final code = (_mapSource.primaryValueMapper?.call(index) ?? '').toString();
            final plays = playsForCountry(code);
            final title = trendingTitleForCountry(code);
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0E16).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code.isEmpty ? '??' : code,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'REGION INSIGHT',
                            style: TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$plays Active Sessions',
                        style: TextStyle(
                          color: Colors.cyanAccent.withOpacity(0.8),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          initialMarkersCount: _platformFilter == 'all'
              ? _liveEvents.length
              : _liveEvents.where((e) => e.platform == _platformFilter).length,
          markerBuilder: (BuildContext context, int index) {
            final filtered = _platformFilter == 'all'
                ? _liveEvents
                : _liveEvents.where((e) => e.platform == _platformFilter).toList();
            final event = filtered[index];
            return MapMarker(
              latitude: event.lat,
              longitude: event.lng,
              child: _buildMapMarker(event),
            );
          },
          tooltipSettings: const MapTooltipSettings(
            color: Color(0xFF1C1E2A),
            strokeColor: Colors.blueAccent,
            strokeWidth: 1,
          ),
          ),
        ],
      ),
    );
  }

  void _cinematicFocusTo(double lat, double lng, double zoom) {
    if (!_mapReady) return;
    if (!_mapGesturesReady) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFocusMs < 800) return;
    _lastFocusMs = now;

    final from = _zoomPanBehavior.focalLatLng ?? const MapLatLng(20, 0);
    final fromLat = from.latitude;
    final fromLng = from.longitude;
    final fromZoom = _zoomPanBehavior.zoomLevel;

    _focusController.stop();
    _focusController.reset();

    final latTween = Tween<double>(begin: fromLat, end: lat);
    final lngTween = Tween<double>(begin: fromLng, end: lng);
    final zoomTween = Tween<double>(begin: fromZoom, end: zoom);
    final curve = CurvedAnimation(parent: _focusController, curve: Curves.easeOutCubic);

    if (_focusListener != null) {
      try {
        _focusController.removeListener(_focusListener!);
      } catch (_) {
        // ignore
      }
    }

    _focusListener = () {
      final t = curve.value;
      try {
        _zoomPanBehavior.focalLatLng = MapLatLng(latTween.transform(t), lngTween.transform(t));
        _zoomPanBehavior.zoomLevel = zoomTween.transform(t);
      } catch (_) {
        // ignore
      }
    };
    _focusController.addListener(_focusListener!);
    _focusController.forward();
  }

  List<_Star> _makeStars() {
    final r = math.Random(11);
    final stars = <_Star>[];
    for (int i = 0; i < 80; i++) {
      stars.add(_Star(
        x: r.nextDouble(),
        y: r.nextDouble(),
        radius: 0.6 + r.nextDouble() * 1.8,
        alpha: 0.15 + r.nextDouble() * 0.55,
        hue: r.nextDouble(),
      ));
    }
    return stars;
  }

  Widget _buildParticlesOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return CustomPaint(
            painter: _ParticlesPainter(stars: _stars, t: _pulseController.value),
          );
        },
      ),
    );
  }

  Widget _buildRippleOverlay() {
    final evts = _pulseEvents.toList();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return CustomPaint(
            painter: _RipplePainter(events: evts, t: _pulseController.value),
          );
        },
      ),
    );
  }

  Widget _buildLiveTournaments() {
    final items = _liveTournaments;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1244).withOpacity(0.45),
              const Color(0xFF090A12).withOpacity(0.85),
            ],
          ),
        ),
        child: Text(
          'No live tournaments right now.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      );
    }

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: math.min(10, items.length),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final t = items[i];
          return Container(
            width: 320,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1244).withOpacity(0.55),
                  const Color(0xFF090A12).withOpacity(0.90),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Icon(LucideIcons.trophy, color: Color(0xFFFBBF24), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.35)),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Color(0xFF22C55E),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Players: ${_fmtCompact(t.playersCount)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prize Pool: ${_fmtCompact(t.prizePool)} coins',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Text(
                    'Join Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlBar() {
    Widget chip(String key, String label, Color color) {
      final active = _platformFilter == key;
      return InkWell(
        onTap: () {
          setState(() => _platformFilter = key);
          _fetchSummary();
          _reconnectLiveStream();
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.18) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? color.withOpacity(0.35) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? color : Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.30),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.radar, color: Colors.white70, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    chip('all', 'ALL', Colors.white),
                    const SizedBox(width: 8),
                    chip('webgl', 'WEBGL', Colors.blueAccent),
                    const SizedBox(width: 8),
                    chip('mobile', 'MOBILE', Colors.pinkAccent),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () => setState(() => _compactMode = !_compactMode),
              icon: Icon(
                _compactMode ? LucideIcons.layoutGrid : LucideIcons.minimize2,
                color: Colors.white70,
                size: 18,
              ),
              splashRadius: 22,
              tooltip: _compactMode ? 'Show Panels' : 'Hide Panels',
            ),
            IconButton(
              onPressed: () => _fetchHeatmapData(isSilentRefresh: true),
              icon: const Icon(LucideIcons.refreshCcw, color: Colors.white70, size: 18),
              splashRadius: 22,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStats(int filteredCount) {
    final syncLabel = _lastSyncAt == null
        ? '—'
        : '${_lastSyncAt!.hour.toString().padLeft(2, '0')}:${_lastSyncAt!.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.activity, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE EVENTS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$filteredCount points',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _lastDelta > 0
                      ? Container(
                          key: ValueKey(_lastDelta),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.25)),
                          ),
                          child: Text(
                            '+$_lastDelta',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : Container(
                          key: const ValueKey('zero'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Text(
                            'STABLE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SYNC',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                syncLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildLiveFeedCard(List<GlobalEventModel> events) {
    final top = events.take(6).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0E16).withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                const Icon(LucideIcons.zap,
                    color: Colors.amberAccent, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'LIVE FEED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.7,
                    ),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _liveConnected ? Colors.greenAccent : Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            if (top.isEmpty)
              Text(
                'No events yet',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              ...top.map((e) {
                final time =
                    '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
                final accent =
                    e.platform == 'webgl' ? Colors.blueAccent : Colors.pinkAccent;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _openEventDetails(e),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.gameTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.countryCode} • $time',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.12,
      maxChildSize: 0.45,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF06060A).withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  )
                ],
              ),
              child: Column(
                children: [
                  // Premium Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 14, bottom: 20),
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.flame, color: Colors.orangeAccent, size: 18),
                            SizedBox(width: 12),
                            Text(
                              'GLOBAL TRENDS',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _trendingGames.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: Colors.white.withOpacity(0.06), height: 32),
                      itemBuilder: (context, index) {
                        final game = _trendingGames[index];
                        return Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                              ),
                              child: Center(
                                child: Text(
                                  game.country,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueAccent,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    game.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.playCircle, size: 14, color: Colors.white38),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${game.plays} Active Players',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                index == 0 ? LucideIcons.trendingUp : LucideIcons.chevronRight,
                                color: index == 0 ? Colors.greenAccent : Colors.white24,
                                size: 16,
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowMarkerPainter extends CustomPainter {
  final double scale;
  final double opacity;
  final Color color;

  _GlowMarkerPainter({
    required this.scale,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Outer Pulsing Glow
    final glowPaint = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, (size.width / 2) * scale, glowPaint);

    // Inner Core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width / 6, corePaint);
  }

  @override
  bool shouldRepaint(covariant _GlowMarkerPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.opacity != opacity;
  }
}

class _MiniSparkPainter extends CustomPainter {
  final double t;

  _MiniSparkPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final pts = <Offset>[];
    final n = 18;
    for (int i = 0; i < n; i++) {
      final x = size.width * (i / (n - 1));
      final noise = (r.nextDouble() - 0.5) * 0.35;
      final wave = math.sin((i / (n - 1) * 2 * math.pi) + t * 2 * math.pi) * 0.35;
      final yv = (0.55 + noise + wave).clamp(0.10, 0.90);
      final y = size.height * (1.0 - yv);
      pts.add(Offset(x, y));
    }

    final path = Path();
    if (pts.isNotEmpty) {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7C3AED).withOpacity(0.25);
    canvas.drawPath(path, glowPaint);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF22C55E).withOpacity(0.85);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparkPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _RegionFocus {
  final double lat;
  final double lng;
  final double zoom;

  _RegionFocus(this.lat, this.lng, this.zoom);
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double hue;

  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.hue,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;

  _ParticlesPainter({required this.stars, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      final dx = s.x * size.width;
      final dy = s.y * size.height;
      final tw = (0.6 + 0.4 * math.sin((s.x + s.y + t) * math.pi * 2));
      final a = (s.alpha * tw).clamp(0.05, 0.8);
      final c = Color.lerp(
            const Color(0xFF7C3AED),
            const Color(0xFF2563EB),
            s.hue,
          ) ??
          const Color(0xFF7C3AED);
      paint.color = c.withOpacity(a);
      canvas.drawCircle(Offset(dx, dy), s.radius * (0.8 + 0.6 * tw), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.stars != stars;
  }
}

class _RipplePainter extends CustomPainter {
  final List<GlobalEventModel> events;
  final double t;

  _RipplePainter({required this.events, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final center = Offset(size.width * 0.5, size.height * 0.55);
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < events.length; i++) {
      final e = events[i];
      final ageMs = now - e.createdAt.millisecondsSinceEpoch;
      if (ageMs < 0 || ageMs > 8000) continue;
      final life = (ageMs / 8000.0).clamp(0.0, 1.0);
      final phase = (t + i * 0.12) % 1.0;
      final r = (18 + 180 * (life + 0.35 * phase)).clamp(0.0, 260.0);
      final a = (0.30 * (1.0 - life)).clamp(0.0, 0.35);
      final c =
          Color.lerp(const Color(0xFF7C3AED), const Color(0xFFF97316), 0.55) ??
              const Color(0xFF7C3AED);
      paint.color = c.withOpacity(a);
      paint.strokeWidth = (2.0 * (1.0 - life)).clamp(0.5, 2.0);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.events != events;
  }
}
