import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../database/database_helper.dart';
import '../widgets/unified_map_view.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/file_utils.dart';

class WorkoutSummaryPage extends StatefulWidget {
  final Workout workout;

  const WorkoutSummaryPage({super.key, required this.workout});

  @override
  _WorkoutSummaryPageState createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage> {
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

  @override
  Widget build(BuildContext context) {
    final List<UnifiedLatLng> routePoints = _points.map((p) => UnifiedLatLng(p.latitude, p.longitude)).toList();
    final UnifiedLatLng? initialCenter = routePoints.isNotEmpty ? routePoints.first : null;
    final UnifiedLatLng? endPinPos = routePoints.length > 1 ? routePoints.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        title: Text('운동 요약', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
        backgroundColor: const Color(0xFF0A0E14),
        foregroundColor: const Color(0xFFF1F3FC),
        elevation: 0,
        automaticallyImplyLeading: false, // Remove default back button
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6DDDFF)))
          : Column(
              children: [
                // Map Area
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
                            // Gradient at bottom of map
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
                
                // Info Panel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                          _buildInfoItem('거리', (widget.workout.totalDistanceMeters / 1000).toStringAsFixed(2), Icons.route, 'km'),
                          _buildInfoItem('평균속도', (widget.workout.averageSpeedMps * 3.6).toStringAsFixed(1), Icons.speed, 'km/h'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildInfoItem('누적 고도', _cumulativeAltitude.toStringAsFixed(0), Icons.trending_up, 'm'),
                          const SizedBox(width: 48),
                          _buildInfoItem('최고 고도', widget.workout.maxAltitudeMeters.toStringAsFixed(0), Icons.terrain, 'm'),
                        ],
                      ),
                      const SizedBox(height: 32),

                      if (_photos.isNotEmpty) ...[
                        Text(
                          '사진 기록',
                          style: GoogleFonts.notoSansKr(
                            color: const Color(0xFFF1F3FC),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final photo = _photos[index];
                              return GestureDetector(
                                onTap: () => _openPhotoGallery(index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(FileUtils.getFullImagePath(photo.imagePath)),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 100,
                                      height: 100,
                                      color: const Color(0xFF1B2028),
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // Bottom Back Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20262F), // surface-container-variant
                            foregroundColor: const Color(0xFFF1F3FC),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            '뒤로가기',
                            style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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

  void _openPhotoGallery(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('${initialIndex + 1} / ${_photos.length}', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        ),
        body: PageView.builder(
          controller: PageController(initialPage: initialIndex),
          itemCount: _photos.length,
          itemBuilder: (context, index) {
            final photo = _photos[index];
            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    child: Center(
                      child: Image.file(
                        File(FileUtils.getFullImagePath(photo.imagePath)),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey, size: 80),
                              SizedBox(height: 16),
                              Text('사진 파일을 찾을 수 없습니다.', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (photo.comment != null && photo.comment!.isNotEmpty)
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2028).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF44484F).withOpacity(0.3)),
                      ),
                      child: Text(
                        photo.comment!,
                        style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ));
  }
}
