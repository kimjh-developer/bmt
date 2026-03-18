import 'package:flutter/material.dart';
import '../../database/database_helper.dart';
import '../../models/models.dart';
import 'record_detail_page.dart';
import 'package:intl/intl.dart';

class RecordsPage extends StatefulWidget {
  @override
  _RecordsPageState createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  List<Workout> _workouts = [];
  Map<int, List<Mountain>> _workoutMountains = {};

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    try {
      final workouts = await DatabaseHelper.instance.getAllWorkouts();
      final Map<int, List<Mountain>> mountainsMap = {};
      for (var w in workouts) {
        if (w.id != null) {
          try {
            mountainsMap[w.id!] = await DatabaseHelper.instance.getMountainsForWorkout(w.id!);
          } catch (e) {
            print('Error fetching mountains for workout ${w.id}: $e');
            mountainsMap[w.id!] = [];
          }
        }
      }
      setState(() {
        _workouts = workouts;
        _workoutMountains = mountainsMap;
      });
    } catch (e) {
      print('Error loading workouts: $e');
      setState(() {
        _workouts = [];
        _workoutMountains = {};
      });
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    final dt = DateTime.parse(isoString);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('운동 기록'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '아직 저장된 운동 기록이 없습니다.',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오늘 가벼운 등산을 시작해보는 건 어떨까요?',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
                final titleText = mountains.isNotEmpty 
                    ? mountains.map((m) => m.name).join(', ') 
                    : _formatDate(workout.startTime);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecordDetailPage(workout: workout),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.directions_walk, color: Colors.green, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        titleText,
                                        style: const TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMiniMetric(Icons.route, '거리', '${(workout.totalDistanceMeters / 1000).toStringAsFixed(2)}km'),
                                _buildMiniMetric(Icons.timer, '시간', _formatDuration(workout.durationSeconds)),
                                _buildMiniMetric(Icons.speed, '평균속도', '${(workout.averageSpeedMps * 3.6).toStringAsFixed(1)}km/h'),
                                _buildMiniMetric(Icons.landscape, '고도', '${workout.maxAltitudeMeters.toStringAsFixed(0)}m'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
