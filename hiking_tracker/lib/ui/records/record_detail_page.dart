import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../database/database_helper.dart';
import '../widgets/unified_map_view.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class RecordDetailPage extends StatefulWidget {
  final Workout workout;

  const RecordDetailPage({super.key, required this.workout});

  @override
  _RecordDetailPageState createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  UnifiedMapController? _unifiedController;
  List<LocationPoint> _points = [];
  List<Photo> _photos = [];
  bool _isLoading = true;
  double _cumulativeAltitude = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final points = await DatabaseHelper.instance.getLocationPoints(widget.workout.id!);
    final photos = await DatabaseHelper.instance.getPhotos(widget.workout.id!);
    
    double cumulative = 0.0;
    for (int i = 1; i < points.length; i++) {
      cumulative += (points[i].altitude - points[i - 1].altitude).abs();
    }

    if (mounted) {
      setState(() {
        _points = points;
        _photos = photos;
        _cumulativeAltitude = cumulative;
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours시간 $minutes분 $secs초';
    return '$minutes분 $secs초';
  }

  String _formatDateTime(String isoString) {
    final dt = DateTime.parse(isoString);
    return DateFormat('yyyy. MM. dd  HH:mm').format(dt);
  }

  void _openPhotoGallery(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                
                double altitude = 0.0;
                if (_points.isNotEmpty) {
                  try {
                    final photoTime = DateTime.parse(photo.timestamp);
                    LocationPoint closest = _points.first;
                    int minDiff = (DateTime.parse(closest.timestamp).difference(photoTime)).abs().inMilliseconds;
                    for (final p in _points) {
                      final diff = (DateTime.parse(p.timestamp).difference(photoTime)).abs().inMilliseconds;
                      if (diff < minDiff) {
                        minDiff = diff;
                        closest = p;
                      }
                    }
                    altitude = closest.altitude;
                  } catch (_) {}
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      child: Image.file(
                        File(photo.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Color(0xFF44484F), size: 80),
                              SizedBox(height: 16),
                              Text('사진 파일을 찾을 수 없습니다.', style: TextStyle(color: Color(0xFFA8ABB3))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Gradient Overlay for text readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 450,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF0A0E14),
                              const Color(0xFF0A0E14).withOpacity(0.8),
                              const Color(0xFF0A0E14).withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Information Panel
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (photo.comment != null && photo.comment!.isNotEmpty) ...[
                              Text('그날의 기록', style: GoogleFonts.notoSansKr(color: const Color(0xFF6DDDFF), fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                photo.comment!,
                                style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 18, height: 1.4),
                              ),
                              const SizedBox(height: 24),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('고도', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('${altitude.toStringAsFixed(0)} m', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFF1F3FC), fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('위치 (위도, 경도)', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('${photo.latitude.toStringAsFixed(4)}, ${photo.longitude.toStringAsFixed(4)}', style: GoogleFonts.spaceGrotesk(color: const Color(0xFFF1F3FC), fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('촬영 일시', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(_formatDateTime(photo.timestamp), style: GoogleFonts.spaceGrotesk(color: const Color(0xFFF1F3FC), fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B2028),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: const Color(0xFF44484F).withOpacity(0.5)),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  '지도에서 보기',
                                  style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // View Counter
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2028).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '사진 상세',
                    style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            // Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final List<UnifiedLatLng> routePoints = _points.map((p) => UnifiedLatLng(p.latitude, p.longitude)).toList();
    final UnifiedLatLng? initialCenter = routePoints.isNotEmpty ? routePoints.first : null;
    final UnifiedLatLng? endPinPos = routePoints.length > 1 ? routePoints.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        title: Text('기록 상세', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
        backgroundColor: const Color(0xFF0A0E14),
        foregroundColor: const Color(0xFFF1F3FC),
        elevation: 0,
        actions: [
          if (_photos.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2028),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF6DDDFF), size: 20),
                onPressed: () => _openPhotoGallery(0),
                tooltip: '사진 모아보기',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6DDDFF)))
          : Column(
              children: [
                // ── 지도 영역 (Dark Theme) ─────────────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: initialCenter == null
                      ? Center(child: Text('위치 데이터가 없습니다.', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3))))
                      : Stack(
                          children: [
                            UnifiedMapView(
                              initialCenter: initialCenter,
                              initialZoom: 15.0,
                              markers: {
                                UnifiedMarker(
                                  id: 'start',
                                  latitude: initialCenter.latitude,
                                  longitude: initialCenter.longitude,
                                  title: '출발',
                                  color: Colors.green,
                                  zIndex: 1,
                                ),
                                if (endPinPos != null)
                                  UnifiedMarker(
                                    id: 'end',
                                    latitude: endPinPos.latitude,
                                    longitude: endPinPos.longitude,
                                    title: '도착',
                                    color: Colors.red,
                                    zIndex: 1,
                                  ),
                                // Photo markers mapped to generic blue pin native markers
                                ..._photos.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  Photo p = entry.value;
                                  return UnifiedMarker(
                                    id: 'photo_${p.id}',
                                    latitude: p.latitude,
                                    longitude: p.longitude,
                                    title: '사진 ${idx + 1}',
                                    color: Colors.blueAccent,
                                    zIndex: 10,
                                    onTap: () => _openPhotoGallery(idx),
                                  );
                                }),
                              },
                              polylines: {
                                if (routePoints.isNotEmpty)
                                  UnifiedPolyline(
                                    id: 'route',
                                    points: routePoints,
                                    color: const Color(0xFF6DDDFF),
                                    width: 5.0,
                                  ),
                              },
                              onMapCreated: (controller) {
                                _unifiedController = controller;
                                if (routePoints.isNotEmpty) {
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    _unifiedController?.fitBounds(routePoints);
                                  });
                                }
                              },
                            ),
                            // Map Overlay Gradient at bottom for seamless transition
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF0A0E14).withOpacity(0.0),
                                      const Color(0xFF0A0E14),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                
                // ── 하단 정보 패널 ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A0E14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDateTime(widget.workout.startTime),
                            style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC), letterSpacing: -0.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6DDDFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF6DDDFF).withOpacity(0.3)),
                            ),
                            child: Text(
                              '기록 완료',
                              style: GoogleFonts.notoSansKr(color: const Color(0xFF6DDDFF), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem('시간', _formatDuration(widget.workout.durationSeconds), Icons.timer),
                          _buildInfoItem('거리', '${(widget.workout.totalDistanceMeters / 1000).toStringAsFixed(2)}', Icons.route, 'km'),
                          _buildInfoItem('평균속도', '${(widget.workout.averageSpeedMps * 3.6).toStringAsFixed(1)}', Icons.speed, 'km/h'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildInfoItem('누적 고도', '${_cumulativeAltitude.toStringAsFixed(0)}', Icons.trending_up, 'm'),
                          const SizedBox(width: 48),
                          _buildInfoItem('최고 고도', '${widget.workout.maxAltitudeMeters.toStringAsFixed(0)}', Icons.terrain, 'm'),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, [String unit = '']) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6DDDFF)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC), letterSpacing: 0.5)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(unit, style: GoogleFonts.notoSansKr(fontSize: 14, color: const Color(0xFFA8ABB3), fontWeight: FontWeight.w500)),
            ]
          ],
        ),
      ],
    );
  }
}
