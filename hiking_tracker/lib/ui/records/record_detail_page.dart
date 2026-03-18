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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final points = await DatabaseHelper.instance.getLocationPoints(widget.workout.id!);
    final photos = await DatabaseHelper.instance.getPhotos(widget.workout.id!);
    setState(() {
      _points = points;
      _photos = photos;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('운동 상세'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetricColumn('거리', '${(widget.workout.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
                    _buildMetricColumn('평균 속도', '${(widget.workout.averageSpeedMps * 3.6).toStringAsFixed(1)} km/h'),
                  ],
                ),
              ),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(37.5665, 126.9780),
                    initialZoom: 13.0,
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
                            color: Colors.red,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: photoMarkers),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
