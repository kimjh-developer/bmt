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
  bool _centeredOnUser = false; // track if we moved map to user initially

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

    // Move map to user's location on first position fix
    if (!_centeredOnUser && tracker.currentPosition != null) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(tracker.currentPosition!.latitude, tracker.currentPosition!.longitude),
          14.0,
        );
      });
    }

    // During tracking, keep map centered on user as they move
    if (isTracking && tracker.currentPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(tracker.currentPosition!.latitude, tracker.currentPosition!.longitude),
          14.0,
        );
      });
    }

    List<LatLng> route = tracker.locationPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Build mountain markers for clustering
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

    return Scaffold(
      body: Stack(
        children: [
          // Background Map View (Full screen including top and bottom nav)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: tracker.currentPosition != null
                  ? LatLng(tracker.currentPosition!.latitude, tracker.currentPosition!.longitude)
                  : const LatLng(37.5665, 126.9780),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                            markers.length > 999 ? '999+' : '${markers.length}',
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
            ],
          ),
          
          // Bottom Floating Panel containing metrics and action buttons
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Metrics Dashboard
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMetricWidget(context, Icons.timer, '시간', _formatDuration(tracker.durationSeconds)),
                      _buildDivider(),
                      _buildMetricWidget(context, Icons.route, '거리', '${(tracker.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
                      _buildDivider(),
                      _buildMetricWidget(context, Icons.speed, '평균 속도', '${(tracker.averageSpeedMps * 3.6).toStringAsFixed(1)} km/h'),
                      _buildDivider(),
                      _buildMetricWidget(context, Icons.landscape, '고도', '${tracker.maxAltitudeMeters.toStringAsFixed(0)} m'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
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
                      backgroundColor: isTracking ? Colors.redAccent : Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 6,
                    ),
                  ),
                ),
                if (isTracking) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _takePhoto(context);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('사진 촬영'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildMetricWidget(BuildContext context, IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _stopWorkout(BuildContext context) async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    final workout = await tracker.stopWorkout();
    
    // Show summary dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('운동 완료'),
        content: Text('운동 시간: ${_formatDuration(workout.durationSeconds)}\n이동 거리: ${(workout.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _takePhoto(BuildContext context) async {
    final tracker = Provider.of<TrackerProvider>(context, listen: false);
    if (tracker.currentPosition == null) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return; // User canceled

    // Optional comment dialog
    String? comment;
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
               onPressed: () { comment = null; Navigator.pop(context); },
               child: const Text('건너뛰기'),
             ),
             TextButton(
               onPressed: () { comment = commentController.text; Navigator.pop(context); },
               child: const Text('저장'),
             ),
          ],
        );
      }
    );

    // Save temporary photo state
    tracker.addPhotoToCurrentWorkout(
      image.path, 
      tracker.currentPosition!.latitude, 
      tracker.currentPosition!.longitude, 
      comment
    );
  }
}
