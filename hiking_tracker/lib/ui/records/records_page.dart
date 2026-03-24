import 'dart:io';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/models.dart';
import 'record_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<Workout> _workouts = [];
  Map<int, List<Mountain>> _workoutMountains = {};
  Map<int, List<Photo>> _workoutPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    try {
      final workouts = await DatabaseHelper.instance.getAllWorkouts();
      // Reverse so newest is at the top
      workouts.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      final Map<int, List<Mountain>> mountainsMap = {};
      final Map<int, List<Photo>> photosMap = {};

      for (var w in workouts) {
        if (w.id != null) {
          try {
            mountainsMap[w.id!] =
                await DatabaseHelper.instance.getMountainsForWorkout(w.id!);
          } catch (_) {
            mountainsMap[w.id!] = [];
          }

          try {
            photosMap[w.id!] = await DatabaseHelper.instance.getPhotos(w.id!);
          } catch (_) {
            photosMap[w.id!] = [];
          }
        }
      }

      setState(() {
        _workouts = workouts;
        _workoutMountains = mountainsMap;
        _workoutPhotos = photosMap;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _workouts = [];
          _workoutMountains = {};
          _workoutPhotos = {};
        });
      }
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    final dt = DateTime.parse(isoString);
    return DateFormat('yyyy. MM. dd  HH:mm').format(dt);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '$hours시간 $minutes분';
    if (minutes > 0) return '$minutes분 $secs초';
    return '$secs초';
  }

  String _formatPinTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      appBar: AppBar(
        title: Text('운동 기록', style: GoogleFonts.notoSansKr(fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC))),
        backgroundColor: const Color(0xFF0A0E14),
        elevation: 0,
        centerTitle: false,
      ),
      body: _workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run_rounded, size: 80, color: const Color(0xFF44484F)),
                  const SizedBox(height: 16),
                  Text(
                    '아직 저장된 기록이 없습니다.',
                    style: GoogleFonts.notoSansKr(fontSize: 18, color: const Color(0xFFA8ABB3), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '새로운 도전을 시작해보세요!',
                    style: GoogleFonts.notoSansKr(fontSize: 14, color: const Color(0xFF72757D)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                final mountains = _workoutMountains[workout.id] ?? [];
                final photos = _workoutPhotos[workout.id] ?? [];

                final titleText = mountains.isNotEmpty
                    ? mountains.map((m) => m.name).join(', ')
                    : _formatDate(workout.startTime);

                String displayImagePath = '';
                bool isLocalFile = true;
                if (photos.isNotEmpty) {
                  displayImagePath = photos.first.imagePath;
                } else {
                  int fallbackIndex = ((workout.id ?? 0) % 3) + 1;
                  displayImagePath = 'assets/images/mountain_default_$fallbackIndex.png';
                  isLocalFile = false;
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecordDetailPage(workout: workout),
                      ),
                    ).then((_) => _loadWorkouts());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2028),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF44484F).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Image Area
                        SizedBox(
                          height: 160,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              isLocalFile
                                  ? Image.file(
                                      File(displayImagePath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildFallbackImage(),
                                    )
                                  : Image.asset(
                                      displayImagePath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildFallbackImage(),
                                    ),
                              // Optional dark gradient overlay at the bottom of the image for contrast
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        const Color(0xFF1B2028),
                                        const Color(0xFF1B2028).withOpacity(0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Bottom Metric Area
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFF1F3FC)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(workout.startTime),
                                style: GoogleFonts.notoSansKr(fontSize: 13, color: const Color(0xFFA8ABB3)),
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatColumn(Icons.route_outlined, '거리', '${(workout.totalDistanceMeters / 1000).toStringAsFixed(2)} km'),
                                  _buildStatColumn(Icons.timer_outlined, '시간', _formatDuration(workout.durationSeconds)),
                                  _buildStatColumn(Icons.landscape_outlined, '최고 고도', '${workout.maxAltitudeMeters.toStringAsFixed(0)} m'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: const Color(0xFF0F141A),
      child: const Center(
        child: Icon(Icons.broken_image, color: Color(0xFF44484F)),
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6DDDFF)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.notoSansKr(fontSize: 12, color: const Color(0xFFA8ABB3))),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.spaceGrotesk(color: const Color(0xFFF1F3FC), fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
