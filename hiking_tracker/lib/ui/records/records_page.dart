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

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await DatabaseHelper.instance.getAllWorkouts();
    setState(() {
      _workouts = workouts;
    });
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    final dt = DateTime.parse(isoString);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours > 0 ? '$hours h ' : ''}${minutes} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운동 기록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _workouts.isEmpty
          ? const Center(child: Text('아직 저장된 운동 기록이 없습니다.'))
          : ListView.builder(
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.directions_walk, size: 40, color: Colors.green),
                    title: Text(_formatDate(workout.startTime)),
                    subtitle: Text(
                      '거리: ${(workout.totalDistanceMeters / 1000).toStringAsFixed(2)}km | '
                      '시간: ${_formatDuration(workout.durationSeconds)} | '
                      '고도: ${workout.maxAltitudeMeters.toStringAsFixed(0)}m',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecordDetailPage(workout: workout),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
