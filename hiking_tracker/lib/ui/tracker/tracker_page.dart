import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/tracker_provider.dart';
import '../widgets/unified_map_view.dart';
import '../../models/models.dart';
import '../../utils/marker_generator.dart';
import '../../utils/file_utils.dart';
import 'workout_summary_page.dart';
import 'dart:io';

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
    // We only need custom markers for clusters now.
    // Start and End pins use native OS defaults.
  }

  Future<Uint8List> _getClusterIcon(int count) async {
    final key = 'cluster_$count';
    if (_markerCache.containsKey(key)) return _markerCache[key]!;
    final icon = await MarkerGenerator.createTextMarker(count.toString(), backgroundColor: const Color(0xFF6DDDFF), size: 90);
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

  double _getClusterThreshold(double zoom) {
    if (zoom >= 14) return 0.0;     
    if (zoom >= 12) return 0.02;    
    if (zoom >= 10) return 0.05;    
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
            color: reached ? const Color(0xFFC3FFCD) : const Color(0xFFFF716C),
          ));
        }
      } else {
        int count = cluster.length;
        double avgLat = cluster.map((m) => m.latitude).reduce((a, b) => a + b) / count;
        double avgLng = cluster.map((m) => m.longitude).reduce((a, b) => a + b) / count;
        
        final key = 'cluster_$count';
        if (!_markerCache.containsKey(key)) {
          _getClusterIcon(count); 
        }

        finalMarkers.add(UnifiedMarker(
          id: 'cluster_${avgLat}_$avgLng',
          latitude: avgLat,
          longitude: avgLng,
          iconBytes: _markerCache[key], 
          color: const Color(0xFF6DDDFF),
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
      backgroundColor: const Color(0xFF0A0E14),
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
                  color: const Color(0xFF6DDDFF), // Primary Accent
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
                  // native OS marker behavior as requested
                  color: Colors.green, // Hue on Android, default red on iOS
                ),
              if (endPos != null)
                UnifiedMarker(
                  id: 'end_pin',
                  latitude: endPos.latitude,
                  longitude: endPos.longitude,
                  title: '도착',
                  // native OS marker behavior as requested
                  color: Colors.red,
                ),
            },
          ),

          // ── 내 위치 FAB ───────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                backgroundColor: const Color(0xFF1B2028).withOpacity(0.8),
                elevation: 0,
                child: const Icon(Icons.my_location, color: Color(0xFF6DDDFF)),
              ),
            ),
          ),

          // ── 상단 정보 패널 (Glassmorphism Tactical UI) ───────────────────
          if (isTracking)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 80, 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2028).withOpacity(0.65), 
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('시간', _formatDuration(tracker.durationSeconds), Icons.timer),
                            _buildStatItem('거리', '${(tracker.totalDistanceMeters / 1000).toStringAsFixed(2)}', Icons.route, 'km'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('평균속도', '${(tracker.averageSpeedMps * 3.6).toStringAsFixed(1)}', Icons.speed, 'km/h'),
                            _buildStatItem('고도', '${tracker.currentPosition?.altitude.toStringAsFixed(0) ?? 0}', Icons.terrain, 'm'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── 하단 컨트롤 패널 (Tactical Buttons) ────────────────────────────
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF44484F).withOpacity(0.3), width: 1),
                            image: DecorationImage(
                              image: FileImage(File(FileUtils.getFullImagePath(tracker.currentWorkoutPhotos[index].imagePath))),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                if (!isTracking) ...[
                  // 모드 선택 토글
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2028).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF44484F).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildModeToggle('정밀 모드', TrackingMode.realtime, tracker)),
                        Expanded(child: _buildModeToggle('배터리 절약', TrackingMode.batterySave, tracker)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                     if (!isTracking)   //운동 시작 버튼 (Electric Blue)
                      Expanded(
                        child: Container(
                           decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6DDDFF), Color(0xFF00C3EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF6DDDFF).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                            ]
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: const Color(0xFF002C37), // on-primary-fixed
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            onPressed: () {
                              tracker.startWorkout();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded, size: 28),
                                const SizedBox(width: 8),
                                Text('운동 시작', style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else // 운동 종료 연질 레드 버튼
                       Expanded(
                        child: Container(
                           decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: const Color(0xFF1B2028).withOpacity(0.85),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: const Color(0xFFFF716C), // error token
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                onPressed: () {
                                  _stopWorkout();
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.stop_rounded, size: 28),
                                    const SizedBox(width: 8),
                                    Text('운동 종료', style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    if (isTracking) ...[
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: FloatingActionButton(
                          heroTag: 'takePhoto',
                          onPressed: _takePhoto,
                          backgroundColor: const Color(0xFF1B2028).withOpacity(0.9),
                          elevation: 0,
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6DDDFF), size: 26),
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

  Widget _buildModeToggle(String title, TrackingMode mode, TrackerProvider tracker) {
    final isSelected = tracker.trackingMode == mode;
    return GestureDetector(
      onTap: () => tracker.setTrackingMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6DDDFF).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF6DDDFF) : const Color(0xFFA8ABB3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [String unit = '']) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6DDDFF)),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.notoSansKr(fontSize: 12, color: const Color(0xFFA8ABB3))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC), letterSpacing: 0.5)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: GoogleFonts.notoSansKr(fontSize: 13, color: const Color(0xFFA8ABB3), fontWeight: FontWeight.w500)),
                ]
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _stopWorkout() async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    final workout = await tracker.stopWorkout();

    if (!context.mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryPage(workout: workout),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    String? comment;
    if (!context.mounted) return;
    await showDialog(
      barrierColor: Colors.black.withOpacity(0.5),
      context: context,
      builder: (context) {
        final commentController = TextEditingController();
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1B2028).withOpacity(0.9),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFF44484F).withOpacity(0.3)),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('메모 남기기', style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('기록은 기억보다 오래갑니다.', style: GoogleFonts.notoSansKr(color: const Color(0xFF6DDDFF), fontSize: 14)),
              ],
            ),
            content: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F141A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF44484F).withOpacity(0.5)),
              ),
              child: TextField(
                controller: commentController,
                maxLines: 4,
                style: GoogleFonts.notoSansKr(color: const Color(0xFFF1F3FC), fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  hintText: '이 순간을 기록해보세요...',
                  hintStyle: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.only(right: 20, bottom: 20, top: 10),
            actions: [
              TextButton(
                onPressed: () {
                  comment = null;
                  Navigator.pop(context);
                },
                child: Text('건너뛰기', style: GoogleFonts.notoSansKr(color: const Color(0xFFA8ABB3), fontSize: 15)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  comment = commentController.text;
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6DDDFF),
                  foregroundColor: const Color(0xFF002C37),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('저장', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        );
      },
    );

    if (tracker.currentPosition != null) {
      final savedFileName = await FileUtils.saveImageToDocuments(image.path);
      tracker.addPhotoToCurrentWorkout(
        savedFileName,
        tracker.currentPosition!.latitude,
        tracker.currentPosition!.longitude,
        comment,
      );
    }
  }
}
