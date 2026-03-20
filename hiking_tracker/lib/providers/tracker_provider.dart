import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/models.dart';
import '../database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 트래킹 모드
enum TrackingMode {
  realtime,    // 3초마다 GPS 갱신 — 실시간 보기
  batterySave, // distanceFilter 기반 스트림 — 배터리 절약
}

class TrackerProvider extends ChangeNotifier with WidgetsBindingObserver {
  bool isTracking = false;
  DateTime? startTime;
  int durationSeconds = 0;
  double totalDistanceMeters = 0.0;
  double averageSpeedMps = 0.0;
  double maxAltitudeMeters = 0.0;

  Position? currentPosition;
  List<LocationPoint> locationPoints = [];
  List<Photo> currentWorkoutPhotos = [];
  List<Mountain> allMountains = [];
  Set<int> reachedMountainIds = {};

  /// 사용자가 선택한 트래킹 모드 (기본값: 배터리 세이브)
  TrackingMode trackingMode = TrackingMode.batterySave;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<Position>? _passiveLocationSubscription;
  Timer? _timer;
  Timer? _peakCheckTimer;
  Position? _lastPeakCheckPos;

  // Background Idle Check
  DateTime? lastMeaningfulMovementTime;
  Timer? _idleCheckTimer;
  bool _isIdlePromptActive = false;

  // Local Notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  TrackerProvider() {
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadMountains();
    _startPassiveLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleCheckTimer?.cancel();
    flutterLocalNotificationsPlugin.cancelAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isIdlePromptActive) {
        _cancelIdlePrompt();
      }
      // 백그라운드 수면에서 깼을 때 바로 아이들 타임 점검 후 자동종료 평가
      _checkIdleStatus();
    }
  }

  /// 외부(UI)에서 모드 변경
  void setTrackingMode(TrackingMode mode) {
    if (isTracking) return; // 운동 중에는 변경 불가
    trackingMode = mode;
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) async {},
    );
  }

  Future<void> _loadMountains() async {
    allMountains = await DatabaseHelper.instance.getAllMountains();
    notifyListeners();
  }

  /// 항상 켜져 있는 경량 위치 스트림 (지도 표시용)
  Future<void> _startPassiveLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final Position initial = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      currentPosition = initial;
      notifyListeners();

      _passiveLocationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 20,
        ),
      ).listen((position) {
        if (!isTracking) {
          currentPosition = position;
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  Future<void> startWorkout() async {
    // 백그라운드 퍼미션을 요청하는 활성 트래커와의 설정 충돌을 막기 위해 패시브 트래커 해제
    await _passiveLocationSubscription?.cancel();
    _passiveLocationSubscription = null;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    isTracking = true;
    startTime = DateTime.now();
    durationSeconds = 0;
    totalDistanceMeters = 0.0;
    averageSpeedMps = 0.0;
    maxAltitudeMeters = 0.0;
    locationPoints.clear();
    reachedMountainIds.clear();

    // 1초 타이머 (공통) - 백그라운드 일시정지 보완을 위한 절대시간 차이 사용
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (startTime != null) {
        durationSeconds = DateTime.now().difference(startTime!).inSeconds;
        notifyListeners();
      }
    });

    // 봉우리 감지 타이머 (공통)
    _peakCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (currentPosition != null) {
        _checkPeakArrivalThrottled(currentPosition!);
      }
    });

    lastMeaningfulMovementTime = DateTime.now();
    _isIdlePromptActive = false;

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: trackingMode == TrackingMode.realtime ? 0 : 10,
        intervalDuration: trackingMode == TrackingMode.realtime ? const Duration(seconds: 3) : null,
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "운동 기록 중입니다. 앱이 백그라운드에서도 동작합니다.",
          notificationTitle: "Hiking Tracker",
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0, 
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: trackingMode == TrackingMode.realtime ? 0 : 10,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position? position) {
      if (position != null) _updatePosition(position);
    });

    _idleCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkIdleStatus();
    });

    notifyListeners();
  }

  void _updatePosition(Position position) {
    if (locationPoints.isNotEmpty) {
      final lastPoint = locationPoints.last;
      final distance = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < 5.0) {
        // 미동(5m 미만)일 경우 타이머 리셋 방지 및 데이터 저장 안 함
        // 백그라운드에서 OS가 앱을 깨웠거나 Timer대신 동작하게 아이들 상태만 체크
        _checkIdleStatus();
        return; 
      }
      
      lastMeaningfulMovementTime = DateTime.now();
      if (_isIdlePromptActive) _cancelIdlePrompt();
      totalDistanceMeters += distance;
    } else {
      lastMeaningfulMovementTime = DateTime.now();
      if (_isIdlePromptActive) _cancelIdlePrompt();
    }

    currentPosition = position;

    if (position.altitude > maxAltitudeMeters) {
      maxAltitudeMeters = position.altitude;
    }

    if (durationSeconds > 0) {
      averageSpeedMps = totalDistanceMeters / durationSeconds;
    }

    locationPoints.add(LocationPoint(
      workoutId: 0,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      timestamp: DateTime.now().toIso8601String(),
    ));

    notifyListeners();
  }

  void _checkPeakArrivalThrottled(Position position) async {
    const double coarseDeg = 0.045;
    final nearMountains = allMountains.where((m) {
      return (m.latitude - position.latitude).abs() < coarseDeg &&
          (m.longitude - position.longitude).abs() < coarseDeg &&
          !reachedMountainIds.contains(m.id);
    }).toList();

    for (var mountain in nearMountains) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        mountain.latitude,
        mountain.longitude,
      );
      if (distance <= 50.0) {
        reachedMountainIds.add(mountain.id!);
        _triggerPeakNotification(mountain);
      }
    }
  }

  Future<void> _triggerPeakNotification(Mountain mountain) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'peak_channel',
      'Peak Achievements',
      channelDescription: 'Notifications for reaching mountain peaks',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Congratulations!',
      'You have reached the peak of ${mountain.name}!',
      platformChannelSpecifics,
      payload: mountain.id.toString(),
    );
  }

  void addPhotoToCurrentWorkout(
      String path, double lat, double lng, String? comment) {
    currentWorkoutPhotos.add(Photo(
      workoutId: 0,
      imagePath: path,
      latitude: lat,
      longitude: lng,
      comment: comment,
      timestamp: DateTime.now().toIso8601String(),
    ));
    notifyListeners();
  }

  Future<Workout> stopWorkout() async {
    isTracking = false;
    _timer?.cancel();
    _peakCheckTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _idleCheckTimer?.cancel();
    if (_isIdlePromptActive) _cancelIdlePrompt();

    final actualEndTime = DateTime.now();
    final int actualDuration =
        startTime != null ? actualEndTime.difference(startTime!).inSeconds : durationSeconds;

    final workout = Workout(
      startTime: startTime!.toIso8601String(),
      endTime: actualEndTime.toIso8601String(),
      durationSeconds: actualDuration,
      totalDistanceMeters: totalDistanceMeters,
      averageSpeedMps: averageSpeedMps,
      maxAltitudeMeters: maxAltitudeMeters,
    );

    int workoutId = await DatabaseHelper.instance.createWorkout(workout);

    for (var point in locationPoints) {
      await DatabaseHelper.instance.createLocationPoint(LocationPoint(
        workoutId: workoutId,
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: point.altitude,
        timestamp: point.timestamp,
      ));
    }

    for (var photo in currentWorkoutPhotos) {
      await DatabaseHelper.instance.createPhoto(Photo(
        workoutId: workoutId,
        imagePath: photo.imagePath,
        latitude: photo.latitude,
        longitude: photo.longitude,
        comment: photo.comment,
        timestamp: photo.timestamp,
      ));
    }

    for (var mId in reachedMountainIds) {
      await DatabaseHelper.instance.createPeakSuccess(PeakSuccess(
        mountainId: mId,
        workoutId: workoutId,
        timestamp: DateTime.now().toIso8601String(),
      ));
    }

    // UI에서 기록 중인 것처럼 보이지 않도록 내부 측정 변수들 완전 초기화
    startTime = null;
    durationSeconds = 0;
    totalDistanceMeters = 0.0;
    averageSpeedMps = 0.0;
    maxAltitudeMeters = 0.0;
    locationPoints.clear();
    currentWorkoutPhotos.clear();
    reachedMountainIds.clear();

    notifyListeners();
    // 운동 종료 시 지도 시야 확보를 위해 패시브 트래커 재가동
    _startPassiveLocationTracking();
    return workout;
  }

  void _checkIdleStatus() async {
    if (!isTracking || lastMeaningfulMovementTime == null) return;

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden) {
      return; 
    }

    final idleDuration = DateTime.now().difference(lastMeaningfulMovementTime!);

    if (!_isIdlePromptActive) {
      if (idleDuration.inSeconds >= 60) {
        _isIdlePromptActive = true;
        _sendIdleNotification();
      }
    } else {
      if (idleDuration.inSeconds >= 360) {
        await stopWorkout();
        _cancelIdlePrompt();

        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'idle_tracker_channel', 'Hiking Tracker Idle',
            importance: Importance.max, priority: Priority.high);
        const NotificationDetails details = NotificationDetails(
            android: androidDetails, iOS: DarwinNotificationDetails());
        flutterLocalNotificationsPlugin.show(
          998,
          '자동 기록 종료',
          '장시간 움직임이 없어 운동 기록이 자동으로 저장되었습니다.',
          details,
        );
      }
    }
  }

  Future<void> _sendIdleNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'idle_tracker_channel', 'Hiking Tracker Idle',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails details = NotificationDetails(
            android: androidDetails, iOS: DarwinNotificationDetails());

    await flutterLocalNotificationsPlugin.show(
      999,
      '운동이 종료되었나요?',
      '응답이 없으면 5분 후 자동으로 기록이 저장됩니다.',
      details,
    );
  }

  void _cancelIdlePrompt() {
    _isIdlePromptActive = false;
    flutterLocalNotificationsPlugin.cancel(999);
  }
}
