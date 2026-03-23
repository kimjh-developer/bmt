import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/tracker_provider.dart';
import '../widgets/unified_map_view.dart';
import '../../models/models.dart';
import '../../utils/marker_generator.dart';

class TrackerPage extends StatefulWidget {
  const TrackerPage({super.key});

  @override
  _TrackerPageState createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  UnifiedMapController? _unifiedController;
  final ImagePicker _picker = ImagePicker();

  double _currentZoom = 14.0;
  Timer? _throttleTimer;
  Map<String, Uint8List> _markerCache = {};
  bool _hasInitiallyCentered = false;

  @override
  void initState() {
    super.initState();
    _initCustomMarkers();
  }

  Future<void> _initCustomMarkers() async {
    _markerCache['start'] = await MarkerGenerator.createTextMarker('S', backgroundColor: Colors.green, size: 80);
    _markerCache['end'] = await MarkerGenerator.createTextMarker('E', backgroundColor: Colors.red, size: 80);
    if (mounted) setState(() {});
  }

  Future<Uint8List> _getClusterIcon(int count) async {
    final key = 'cluster_$count';
    if (_markerCache.containsKey(key)) return _markerCache[key]!;
    final icon = await MarkerGenerator.createTextMarker(count.toString(), backgroundColor: Colors.blue, size: 90);
    _markerCache[key] = icon;
    if (mounted) setState(() {});
    return icon;
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // 줌 레벨에 따른 클러스터링 거리 동적 설정
  double _getClusterThreshold(double zoom) {
    if (zoom >= 14) return 0.0;     // 안 묶음
    if (zoom >= 12) return 0.02;    // 약간 묶음
    if (zoom >= 10) return 0.05;    // 많이 묶음
    if (zoom >= 8) return 0.1;
    return 0.5;
  }

  Set<UnifiedMarker> _buildFilteredMountainMarkers(TrackerProvider tracker) {
    final currentPos = tracker.currentPosition;
    if (currentPos == null) return {};

    const double limitDegree = 0.5; 
    
    var visibleMountains = tracker.allMountains
        .where((m) =>
            (m.latitude - currentPos.latitude).abs() < limitDegree &&
            (m.longitude - currentPos.longitude).abs() < limitDegree)
        .toList();

    double threshold = _getClusterThreshold(_currentZoom);

    // 단순 거리 기반 클러스터링
    List<List<Mountain>> clusters = [];
    for (var m in visibleMountains) {
      bool added = false;
      for (var cluster in clusters) {
        if (threshold > 0) {
          final center = cluster.first;
          final distSq = math.pow(center.latitude - m.latitude, 2) + math.pow(center.longitude - m.longitude, 2);
          if (distSq < threshold * threshold) {
            cluster.add(m);
            added = true;
            break;
          }
        }
      }
      if (!added) {
        clusters.add([m]);
      }
    }

    Set<UnifiedMarker> finalMarkers = {};
    for (var cluster in clusters) {
      if (cluster.length == 1 || threshold == 0.0) {
        for (var m in cluster) {
          bool reached = tracker.reachedMountainIds.contains(m.id);
          finalMarkers.add(UnifiedMarker(
            id: 'mountain_${m.id}',
            latitude: m.latitude,
            longitude: m.longitude,
            title: m.name,
            snippet: reached ? '기록 완료' : '미정복',
            color: reached ? Colors.green : Colors.red,
          ));
        }
      } else {
        // 그룹 표시
        int count = cluster.length;
        double avgLat = cluster.map((m) => m.latitude).reduce((a, b) => a + b) / count;
        double avgLng = cluster.map((m) => m.longitude).reduce((a, b) => a + b) / count;
        
        // 아이콘이 없으면 미래에 로딩하도록 _getClusterIcon 호출만 해둔다.
        final key = 'cluster_$count';
        if (!_markerCache.containsKey(key)) {
          _getClusterIcon(count); 
        }

        finalMarkers.add(UnifiedMarker(
          id: 'cluster_${avgLat}_$avgLng',
          latitude: avgLat,
          longitude: avgLng,
          iconBytes: _markerCache[key], 
          color: Colors.blue,
          title: '$count개의 산',
          onTap: () {
            _unifiedController?.moveCamera(UnifiedLatLng(avgLat, avgLng), _currentZoom + 2);
          }
        ));
      }
    }

    return finalMarkers;
  }

  void _onCameraMoveThrottled(double lat, double lng, double zoom) {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentZoom = zoom;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracker = Provider.of<TrackerProvider>(context);
    final isTracking = tracker.isTracking;

    final List<UnifiedLatLng> routePoints = tracker.locationPoints
        .map((p) => UnifiedLatLng(p.latitude, p.longitude))
        .toList();

    final UnifiedLatLng? startPos = routePoints.isNotEmpty ? routePoints.first : null;
    final UnifiedLatLng? endPos =
        (isTracking == false && routePoints.length > 1) ? routePoints.last : null;

    final mountainMarkers = _buildFilteredMountainMarkers(tracker);

    // 최초 위치 수신 시 지도 정중앙 이동
    if (!_hasInitiallyCentered && tracker.currentPosition != null && _unifiedController != null) {
      _hasInitiallyCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _unifiedController?.moveCamera(
          UnifiedLatLng(tracker.currentPosition!.latitude, tracker.currentPosition!.longitude),
          _currentZoom,
        );
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── 배경 지도 ─────────────────────────────────────────────────
          UnifiedMapView(
            initialCenter: tracker.currentPosition != null
                ? UnifiedLatLng(tracker.currentPosition!.latitude,
                    tracker.currentPosition!.longitude)
                : UnifiedLatLng(37.5665, 126.9780),
            initialZoom: 14.0,
            myLocationEnabled: true,
            onMapCreated: (controller) {
              _unifiedController = controller;
              if (tracker.currentPosition != null && !_hasInitiallyCentered) {
                _hasInitiallyCentered = true;
                controller.moveCamera(
                  UnifiedLatLng(tracker.currentPosition!.latitude, tracker.currentPosition!.longitude),
                  _currentZoom,
                );
              }
            },
            onCameraMove: _onCameraMoveThrottled,
            polylines: {
              if (routePoints.isNotEmpty)
                UnifiedPolyline(
                  id: 'route',
                  points: routePoints,
                  color: Colors.blueAccent,
                  width: 5.0,
                ),
            },
            markers: {
              ...mountainMarkers,
              if (startPos != null)
                UnifiedMarker(
                  id: 'start_pin',
                  latitude: startPos.latitude,
                  longitude: startPos.longitude,
                  title: '출발',
                  iconBytes: _markerCache['start'],
                  color: Colors.green,
                ),
              if (endPos != null)
                UnifiedMarker(
                  id: 'end_pin',
                  latitude: endPos.latitude,
                  longitude: endPos.longitude,
                  title: '도착',
                  iconBytes: _markerCache['end'],
                  color: Colors.red,
                ),
            },
          ),

          // ── 내 위치 FAB ───────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locateMe',
              onPressed: () {
                if (tracker.currentPosition != null && _unifiedController != null) {
                  _unifiedController!.moveCamera(
                    UnifiedLatLng(tracker.currentPosition!.latitude,
                        tracker.currentPosition!.longitude),
                    15.0,
                  );
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // ── 상단 정보 패널 (운동 중일 때만 세련되게 표시) ───────────────────
          if (isTracking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 80, // FAB보다 왼쪽에 위치
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('시간', _formatDuration(tracker.durationSeconds), Icons.timer),
                            _buildStatItem('거리', '${(tracker.totalDistanceMeters / 1000).toStringAsFixed(2)} km', Icons.route),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('평균속도', '${(tracker.averageSpeedMps * 3.6).toStringAsFixed(1)} km/h', Icons.speed),
                            _buildStatItem('고도', '${tracker.currentPosition?.altitude.toStringAsFixed(0) ?? 0} m', Icons.terrain),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── 하단 컨트롤 패널 ────────────────────────────────────────────
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tracker.currentWorkoutPhotos.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tracker.currentWorkoutPhotos.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ],
                            image: DecorationImage(
                              image: AssetImage(tracker.currentWorkoutPhotos[index].imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                
                // 배터리 모드 제어 (운동 중지 상태일 때만)
                if (!isTracking)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))
                      ]
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton(tracker, TrackingMode.realtime, '실시간(3초)', Icons.gps_fixed),
                        _buildModeButton(tracker, TrackingMode.batterySave, '절약(10초)', Icons.battery_saver),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTracking ? Colors.black87 : Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 6,
                        ),
                        onPressed: () {
                          if (isTracking) {
                            _stopWorkout();
                          } else {
                            tracker.startWorkout().then((_) {
                              // 위치 권한 허용 후 실제 위치 수신 시 맵을 센터로 이동
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (tracker.currentPosition != null && _unifiedController != null) {
                                  _unifiedController!.moveCamera(
                                    UnifiedLatLng(tracker.currentPosition!.latitude,
                                        tracker.currentPosition!.longitude),
                                    16.0,
                                  );
                                }
                              });
                            });
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              isTracking ? '운동 종료' : '등산 시작',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isTracking) ...[
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        heroTag: 'takePhoto',
                        onPressed: _takePhoto,
                        backgroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 28),
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

  Widget _buildModeButton(TrackerProvider tracker, TrackingMode mode, String label, IconData icon) {
    bool isSelected = tracker.trackingMode == mode;
    return GestureDetector(
      onTap: () => tracker.setTrackingMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.grey
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blueAccent.withOpacity(0.7)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _stopWorkout() async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    final workout = await tracker.stopWorkout();

    if (!mounted) return;
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

  Future<void> _takePhoto() async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    String? comment;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        final commentController = TextEditingController();
        return AlertDialog(
          title: const Text('메모 남기기'),
          content: TextField(
            controller: commentController,
            decoration: const InputDecoration(hintText: '이 순간을 기록해보세요...'),
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

    if (tracker.currentPosition != null) {
      tracker.addPhotoToCurrentWorkout(
        image.path,
        tracker.currentPosition!.latitude,
        tracker.currentPosition!.longitude,
        comment,
      );
    }
  }
}
