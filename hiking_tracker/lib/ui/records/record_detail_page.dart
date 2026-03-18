import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
    final points = await DatabaseHelper.instance.getLocationPoints(widget.workout.id!);
    final photos = await DatabaseHelper.instance.getPhotos(widget.workout.id!);
    final mountains = await DatabaseHelper.instance.getMountainsForWorkout(widget.workout.id!);
    setState(() {
      _points = points;
      _photos = photos;
      _mountains = mountains;
      _isLoading = false;
    });

    if (_points.isNotEmpty) {
      // Small delay to ensure Map is ready to move
      Future.delayed(const Duration(milliseconds: 300), () {
        _mapController.move(LatLng(_points.first.latitude, _points.first.longitude), 14.0);
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
                child: Text(photo.comment!, style: const TextStyle(fontSize: 16)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            )
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '$hours시간 $minutes분 $secs초';
    } else if (minutes > 0) {
      return '$minutes분 $secs초';
    } else {
      return '$secs초';
    }
  }

  @override
  Widget build(BuildContext context) {
    List<LatLng> route = _points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    List<Marker> photoMarkers = _photos.map((p) => Marker(
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
    )).toList();

    final titleText = _mountains.isNotEmpty 
        ? _mountains.map((m) => m.name).join(', ') 
        : '운동 상세';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
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
                  initialCenter: route.isNotEmpty ? route.last : const LatLng(37.5665, 126.9780),
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
                  MarkerLayer(markers: photoMarkers),
                ],
              ),
              Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Container(
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
                      _buildMiniMetric(context, Icons.timer, '시간', _formatDuration(widget.workout.durationSeconds)),
                      _buildDivider(),
                      _buildMiniMetric(context, Icons.route, '거리', '${(widget.workout.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
                      _buildDivider(),
                      _buildMiniMetric(context, Icons.speed, '평균 속도', '${(widget.workout.averageSpeedMps * 3.6).toStringAsFixed(1)} km/h'),
                      _buildDivider(),
                      _buildMiniMetric(context, Icons.landscape, '고도', '${widget.workout.maxAltitudeMeters.toStringAsFixed(0)} m'),
                    ],
                  ),
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

  Widget _buildMiniMetric(BuildContext context, IconData icon, String label, String value) {
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
}
