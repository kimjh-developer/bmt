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
  // workoutId -> (startPoint, endPoint) — null이면 경로 없음
  Map<int, _PinInfo?> _workoutPins = {};

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    try {
      final workouts = await DatabaseHelper.instance.getAllWorkouts();
      final Map<int, List<Mountain>> mountainsMap = {};
      final Map<int, _PinInfo?> pinsMap = {};

      for (var w in workouts) {
        if (w.id != null) {
          // 산 정보
          try {
            mountainsMap[w.id!] =
                await DatabaseHelper.instance.getMountainsForWorkout(w.id!);
          } catch (_) {
            mountainsMap[w.id!] = [];
          }

          // 첫/마지막 GPS 포인트 (핀용)
          try {
            final points =
                await DatabaseHelper.instance.getLocationPoints(w.id!);
            if (points.isNotEmpty) {
              pinsMap[w.id!] = _PinInfo(
                startLat: points.first.latitude,
                startLng: points.first.longitude,
                startTime: points.first.timestamp,
                endLat: points.last.latitude,
                endLng: points.last.longitude,
                endTime: points.last.timestamp,
                hasRoute: points.length > 1,
              );
            } else {
              pinsMap[w.id!] = null;
            }
          } catch (_) {
            pinsMap[w.id!] = null;
          }
        }
      }

      setState(() {
        _workouts = workouts;
        _workoutMountains = mountainsMap;
        _workoutPins = pinsMap;
      });
    } catch (e) {
      setState(() {
        _workouts = [];
        _workoutMountains = {};
        _workoutPins = {};
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
    if (hours > 0) return '$hours시간 $minutes분 $secs초';
    if (minutes > 0) return '$minutes분 $secs초';
    return '$secs초';
  }

  String _formatPinTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return '';
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
                  Icon(Icons.directions_run,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '아직 저장된 운동 기록이 없습니다.',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오늘 가벼운 등산을 시작해보는 건 어떨까요?',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                final mountains = _workoutMountains[workout.id] ?? [];
                final pins = _workoutPins[workout.id];
                final titleText = mountains.isNotEmpty
                    ? mountains.map((m) => m.name).join(', ')
                    : _formatDate(workout.startTime);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RecordDetailPage(workout: workout),
                      ),
                    ).then((_) => _loadWorkouts());
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
                          // ── 제목 행 ────────────────────────────────
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
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
                                      child: const Icon(
                                          Icons.directions_walk,
                                          color: Colors.green,
                                          size: 24),
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
                              const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                            ],
                          ),

                          // ── 핀 정보 행 ─────────────────────────────
                          if (pins != null) ...[
                            const SizedBox(height: 10),
                            _buildPinRow(pins),
                          ],

                          const SizedBox(height: 12),

                          // ── 수치 지표 ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _buildMiniMetric(
                                    Icons.route,
                                    '거리',
                                    '${(workout.totalDistanceMeters / 1000).toStringAsFixed(2)}km'),
                                _buildMiniMetric(Icons.timer, '시간',
                                    _formatDuration(workout.durationSeconds)),
                                _buildMiniMetric(
                                    Icons.speed,
                                    '평균속도',
                                    '${(workout.averageSpeedMps * 3.6).toStringAsFixed(1)}km/h'),
                                _buildMiniMetric(
                                    Icons.landscape,
                                    '고도',
                                    '${workout.maxAltitudeMeters.toStringAsFixed(0)}m'),
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

  // ── 핀 행 위젯 ──────────────────────────────────────────────────────────
  Widget _buildPinRow(_PinInfo pins) {
    return Row(
      children: [
        // 출발 핀
        _buildPinBadge(
          color: Colors.green.shade600,
          icon: Icons.play_arrow,
          label: '출발',
          time: _formatPinTime(pins.startTime),
        ),
        if (pins.hasRoute) ...[
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.green.shade400,
                  Colors.red.shade400,
                ]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 도착 핀
          _buildPinBadge(
            color: Colors.red.shade600,
            icon: Icons.flag,
            label: '도착',
            time: _formatPinTime(pins.endTime),
          ),
        ],
      ],
    );
  }

  Widget _buildPinBadge({
    required Color color,
    required IconData icon,
    required String label,
    required String time,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(time,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ],
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
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 카드용 핀 정보 DTO
class _PinInfo {
  final double startLat;
  final double startLng;
  final String startTime;
  final double endLat;
  final double endLng;
  final String endTime;
  final bool hasRoute;

  _PinInfo({
    required this.startLat,
    required this.startLng,
    required this.startTime,
    required this.endLat,
    required this.endLng,
    required this.endTime,
    required this.hasRoute,
  });
}
