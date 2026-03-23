import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../database/database_helper.dart';
import '../widgets/unified_map_view.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../utils/marker_generator.dart';
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
  Map<String, Uint8List> _markerCache = {};

  @override
  void initState() {
    super.initState();
    _initCustomMarkers();
    _loadData();
  }

  Future<void> _initCustomMarkers() async {
    _markerCache['start'] = await MarkerGenerator.createTextMarker('S', backgroundColor: Colors.green, size: 80);
    _markerCache['end'] = await MarkerGenerator.createTextMarker('E', backgroundColor: Colors.red, size: 80);
    if (mounted) setState(() {});
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

    // Load actual image markers
    for (var p in photos) {
      final key = 'photo_${p.id}';
      _markerCache[key] = await MarkerGenerator.createImageMarker(p.imagePath, size: 120);
    }
    if (mounted) setState(() {});
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
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  void _openPhotoGallery(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('${initialIndex + 1} / ${_photos.length}'),
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
                        File(photo.imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey, size: 100),
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
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        photo.comment!,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
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

  @override
  Widget build(BuildContext context) {
    final List<UnifiedLatLng> routePoints = _points.map((p) => UnifiedLatLng(p.latitude, p.longitude)).toList();
    final UnifiedLatLng? initialCenter = routePoints.isNotEmpty ? routePoints.first : null;
    final UnifiedLatLng? endPinPos = routePoints.length > 1 ? routePoints.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 상세'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_photos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.photo_library, color: Colors.blueAccent),
              onPressed: () => _openPhotoGallery(0),
              tooltip: '사진 모아보기',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── 지도 영역 ─────────────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: initialCenter == null
                      ? const Center(child: Text('위치 데이터가 없습니다.'))
                      : UnifiedMapView(
                          initialCenter: initialCenter,
                          initialZoom: 15.0,
                          markers: {
                            UnifiedMarker(
                              id: 'start',
                              latitude: initialCenter.latitude,
                              longitude: initialCenter.longitude,
                              title: '출발',
                              iconBytes: _markerCache['start'],
                              color: Colors.green,
                              zIndex: 1,
                            ),
                            if (endPinPos != null)
                              UnifiedMarker(
                                id: 'end',
                                latitude: endPinPos.latitude,
                                longitude: endPinPos.longitude,
                                title: '도착',
                                iconBytes: _markerCache['end'],
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
                                iconBytes: _markerCache['photo_${p.id}'],
                                color: Colors.orange,
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
                                color: Colors.blueAccent,
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
                ),
                // ── 상세 정보 영역 ──────────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDateTime(widget.workout.startTime),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '기록 완료',
                                style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 3,
                            childAspectRatio: 1.5,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildInfoItem('시간', _formatDuration(widget.workout.durationSeconds), Icons.timer),
                              _buildInfoItem('거리', '${(widget.workout.totalDistanceMeters / 1000).toStringAsFixed(2)}km', Icons.route),
                              _buildInfoItem('평균속도', '${(widget.workout.averageSpeedMps * 3.6).toStringAsFixed(1)}km/h', Icons.speed),
                              _buildInfoItem('누적 고도', '${_cumulativeAltitude.toStringAsFixed(0)}m', Icons.trending_up),
                              _buildInfoItem('최고 고도', '${widget.workout.maxAltitudeMeters.toStringAsFixed(0)}m', Icons.terrain),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}
