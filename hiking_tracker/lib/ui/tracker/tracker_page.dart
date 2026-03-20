import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/tracker_provider.dart';
import '../../models/models.dart';

class TrackerPage extends StatefulWidget {
  @override
  _TrackerPageState createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tracker = Provider.of<TrackerProvider>(context);
    final isTracking = tracker.isTracking;

    List<LatLng> route = tracker.locationPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // 시작 / 종료 핀 포인트
    final LatLng? startPin = route.isNotEmpty ? route.first : null;
    final LatLng? endPin =
        (isTracking == false && route.length > 1) ? route.last : null;

    // Mountain markers
    List<Marker> mountainMarkers = tracker.allMountains.map((m) {
      bool reached = tracker.reachedMountainIds.contains(m.id);
      return Marker(
        width: 32.0,
        height: 32.0,
        point: LatLng(m.latitude, m.longitude),
        child: Icon(
          Icons.landscape,
          color: reached ? Colors.green.shade700 : Colors.red.shade600,
          size: 22.0,
        ),
      );
    }).toList();

    // 시작 / 종료 핀 마커
    List<Marker> pinMarkers = [
      if (startPin != null)
        Marker(
          width: 44,
          height: 58,
          point: startPin,
          child: _buildPinWidget(
            color: Colors.green.shade600,
            icon: Icons.play_arrow,
            label: 'S',
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
            label: 'E',
          ),
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          // ── 배경 지도 ─────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: tracker.currentPosition != null
                  ? LatLng(tracker.currentPosition!.latitude,
                      tracker.currentPosition!.longitude)
                  : const LatLng(37.5665, 126.9780),
              initialZoom: 14.0,
              maxZoom: 22.0,
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
              if (mountainMarkers.isNotEmpty)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 80,
                    size: const Size(44, 44),
                    markers: mountainMarkers,
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade700.withOpacity(0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade900.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            markers.length > 999
                                ? '999+'
                                : '${markers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // 현재 위치 마커
              if (tracker.currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 24.0,
                      height: 24.0,
                      point: LatLng(
                        tracker.currentPosition!.latitude,
                        tracker.currentPosition!.longitude,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              // 시작 / 종료 핀
              if (pinMarkers.isNotEmpty)
                MarkerLayer(markers: pinMarkers),
            ],
          ),

          // ── 내 위치 FAB ───────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locateMe',
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade700,
              elevation: 4,
              onPressed: () {
                if (tracker.currentPosition != null) {
                  _mapController.move(
                    LatLng(tracker.currentPosition!.latitude,
                        tracker.currentPosition!.longitude),
                    _mapController.camera.zoom,
                  );
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── 하단 패널 ─────────────────────────────────────────────────
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 배터리 모드 선택 (운동 중에는 숨김)
                if (!isTracking) _buildModeSelector(tracker),
                if (!isTracking) const SizedBox(height: 12),

                // 지표 대시보드
                Container(
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
                      _buildMetricWidget(context, Icons.timer, '시간',
                          _formatDuration(tracker.durationSeconds)),
                      _buildDivider(),
                      _buildMetricWidget(
                          context,
                          Icons.route,
                          '거리',
                          '${(tracker.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
                      _buildDivider(),
                      _buildMetricWidget(
                          context,
                          Icons.speed,
                          '평균 속도',
                          '${(tracker.averageSpeedMps * 3.6).toStringAsFixed(1)} km/h'),
                      _buildDivider(),
                      _buildMetricWidget(
                          context,
                          Icons.landscape,
                          '고도',
                          '${tracker.maxAltitudeMeters.toStringAsFixed(0)} m'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 액션 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isTracking) {
                            _stopWorkout(context);
                          } else {
                            tracker.startWorkout();
                          }
                        },
                        icon: Icon(isTracking ? Icons.stop : Icons.play_arrow),
                        label: Text(isTracking ? '운동 종료' : '운동 시작'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTracking
                              ? Colors.redAccent
                              : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 6,
                        ),
                      ),
                    ),
                    if (isTracking) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _takePhoto(context),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('사진 촬영'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            elevation: 6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 핀 위젯 ─────────────────────────────────────────────────────────────
  Widget _buildPinWidget({
    required Color color,
    required IconData icon,
    required String label,
  }) {
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

  // ── 배터리 모드 선택 위젯 ────────────────────────────────────────────────
  Widget _buildModeSelector(TrackerProvider tracker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_charging_full,
                  size: 18, color: Colors.green.shade700),
              const SizedBox(width: 6),
              Text(
                'GPS 트래킹 모드',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  tracker: tracker,
                  mode: TrackingMode.realtime,
                  icon: Icons.bolt,
                  label: '실시간 보기',
                  subLabel: 'GPS 3초 갱신',
                  iconColor: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeOption(
                  tracker: tracker,
                  mode: TrackingMode.batterySave,
                  icon: Icons.battery_saver,
                  label: '배터리 절약',
                  subLabel: '이동 감지 갱신',
                  iconColor: Colors.green.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required TrackerProvider tracker,
    required TrackingMode mode,
    required IconData icon,
    required String label,
    required String subLabel,
    required Color iconColor,
  }) {
    final isSelected = tracker.trackingMode == mode;
    return GestureDetector(
      onTap: () => tracker.setTrackingMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? iconColor.withOpacity(0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? iconColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? iconColor : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? iconColor : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subLabel,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 공통 위젯 ────────────────────────────────────────────────────────────
  Widget _buildDivider() =>
      Container(width: 1, height: 40, color: Colors.grey.shade300);

  Widget _buildMetricWidget(
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

  // ── 운동 종료 ────────────────────────────────────────────────────────────
  void _stopWorkout(BuildContext context) async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    final workout = await tracker.stopWorkout();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('운동 완료'),
        content: Text(
            '운동 시간: ${_formatDuration(workout.durationSeconds)}\n이동 거리: ${(workout.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // ── 사진 촬영 ────────────────────────────────────────────────────────────
  void _takePhoto(BuildContext context) async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    if (tracker.currentPosition == null) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    String? comment;
    await showDialog(
      context: context,
      builder: (context) {
        final commentController = TextEditingController();
        return AlertDialog(
          title: const Text('메모 남기기'),
          content: TextField(
            controller: commentController,
            decoration:
                const InputDecoration(hintText: '이 순간을 기록해보세요...'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                comment = null;
                Navigator.pop(context);
              },
              child: const Text('건너뛰기'),
            ),
            TextButton(
              onPressed: () {
                comment = commentController.text;
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    tracker.addPhotoToCurrentWorkout(
      image.path,
      tracker.currentPosition!.latitude,
      tracker.currentPosition!.longitude,
      comment,
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
  bool shouldRepaint(_PinTailPainter oldDelegate) =>
      oldDelegate.color != color;
}
