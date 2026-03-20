import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/models.dart';

class RecordDetailPage extends StatefulWidget {
  final Workout workout;

  const RecordDetailPage({Key? key, required this.workout}) : super(key: key);

  @override
  _RecordDetailPageState createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  final MapController _mapController = MapController();
  List<LocationPoint> _points = [];
  List<Photo> _photos = [];
  List<Mountain> _mountains = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final points =
        await DatabaseHelper.instance.getLocationPoints(widget.workout.id!);
    final photos =
        await DatabaseHelper.instance.getPhotos(widget.workout.id!);
    final mountains =
        await DatabaseHelper.instance.getMountainsForWorkout(widget.workout.id!);

    setState(() {
      _points = points;
      _photos = photos;
      _mountains = mountains;
      _isLoading = false;
    });

    // 경로 전체가 화면에 꽉 차도록 카메라 fit
    if (_points.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final lats = _points.map((p) => p.latitude);
        final lngs = _points.map((p) => p.longitude);
        var bounds = LatLngBounds(
          LatLng(lats.reduce((a, b) => a < b ? a : b),
                 lngs.reduce((a, b) => a < b ? a : b)),
          LatLng(lats.reduce((a, b) => a > b ? a : b),
                 lngs.reduce((a, b) => a > b ? a : b)),
        );

        if (bounds.northWest == bounds.southEast) {
          final center = bounds.northWest;
          bounds = LatLngBounds(
            LatLng(center.latitude - 0.005, center.longitude - 0.005),
            LatLng(center.latitude + 0.005, center.longitude + 0.005),
          );
        }
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.fromLTRB(40, 100, 40, 220),
          ),
        );
      });
    }
  }

  void _showPhotoDialog(Photo photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(photo.imagePath), fit: BoxFit.cover),
            if (photo.comment != null && photo.comment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(photo.comment!,
                    style: const TextStyle(fontSize: 16)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours시간 $minutes분 $secs초';
    if (minutes > 0) return '$minutes분 $secs초';
    return '$secs초';
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> route =
        _points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    // 시작 핀 (초록 ▶)
    final LatLng? startPin = route.isNotEmpty ? route.first : null;
    // 종료 핀 (빨간 🚩) — 경로가 2개 이상일 때
    final LatLng? endPin = route.length > 1 ? route.last : null;

    // 사진 마커
    final List<Marker> photoMarkers = _photos
        .map((p) => Marker(
              width: 40.0,
              height: 40.0,
              point: LatLng(p.latitude, p.longitude),
              child: GestureDetector(
                onTap: () => _showPhotoDialog(p),
                child: const Icon(
                  Icons.photo_camera,
                  color: Colors.purple,
                  size: 30.0,
                ),
              ),
            ))
        .toList();

    // 시작/종료 핀 마커
    final List<Marker> pinMarkers = [
      if (startPin != null)
        Marker(
          width: 44,
          height: 58,
          point: startPin,
          child: _buildPinWidget(
            color: Colors.green.shade600,
            icon: Icons.play_arrow,
          ),
        ),
      if (endPin != null)
        Marker(
          width: 44,
          height: 58,
          point: endPin,
          child: _buildPinWidget(
            color: Colors.red.shade600,
            icon: Icons.flag,
          ),
        ),
    ];

    // 타이틀: "yyyy-MM-dd 날의 운동"
    final dateStr = DateFormat('yyyy-MM-dd')
        .format(DateTime.parse(widget.workout.startTime));
    final titleText = '$dateStr 날의 운동';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(titleText,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: startPin ?? const LatLng(37.5665, 126.9780),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.hiking_tracker',
                    ),
                    if (route.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route,
                            color: Colors.blueAccent,
                            strokeWidth: 5.0,
                          ),
                        ],
                      ),
                    // 사진 마커
                    MarkerLayer(markers: photoMarkers),
                    // 시작 / 종료 핀 (사진 위에 렌더)
                    MarkerLayer(markers: pinMarkers),
                  ],
                ),

                // 범례 칩 (우측 상단)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 56,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildLegendChip(
                        color: Colors.green.shade600,
                        icon: Icons.play_arrow,
                        label: '출발',
                      ),
                      const SizedBox(height: 6),
                      _buildLegendChip(
                        color: Colors.red.shade600,
                        icon: Icons.flag,
                        label: '도착',
                      ),
                    ],
                  ),
                ),

                // 지표 패널
                Positioned(
                  bottom: 32,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20.0, horizontal: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, -4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMiniMetric(context, Icons.timer, '시간',
                            _formatDuration(widget.workout.durationSeconds)),
                        _buildDivider(),
                        _buildMiniMetric(
                            context,
                            Icons.route,
                            '거리',
                            '${(widget.workout.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
                        _buildDivider(),
                        _buildMiniMetric(
                            context,
                            Icons.speed,
                            '평균 속도',
                            '${(widget.workout.averageSpeedMps * 3.6).toStringAsFixed(1)} km/h'),
                        _buildDivider(),
                        _buildMiniMetric(
                            context,
                            Icons.landscape,
                            '고도',
                            '${widget.workout.maxAltitudeMeters.toStringAsFixed(0)} m'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── 핀 위젯 ──────────────────────────────────────────────────────────────
  Widget _buildPinWidget({required Color color, required IconData icon}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        CustomPaint(
          size: const Size(12, 10),
          painter: _PinTailPainter(color: color),
        ),
      ],
    );
  }

  // ── 범례 칩 ──────────────────────────────────────────────────────────────
  Widget _buildLegendChip(
      {required Color color,
      required IconData icon,
      required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 40, color: Colors.grey.shade300);

  Widget _buildMiniMetric(
      BuildContext context, IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── 핀 꼬리 CustomPainter ────────────────────────────────────────────────────
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
