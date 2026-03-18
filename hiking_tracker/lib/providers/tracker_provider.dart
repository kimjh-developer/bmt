import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/models.dart';
import '../database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import '../models/models.dart';
import '../database/database_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TrackerProvider extends ChangeNotifier {
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
  Set<int> reachedMountainIds = {}; // to prevent multiple notifications for the same peak in one workout

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _timer;
  
  // Local Notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  TrackerProvider() {
    _initNotifications();
    _loadMountains();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );
  }

  Future<void> _loadMountains() async {
    allMountains = await DatabaseHelper.instance.getAllMountains();
    notifyListeners();
  }

  Future<void> startWorkout() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    isTracking = true;
    startTime = DateTime.now();
    durationSeconds = 0;
    totalDistanceMeters = 0.0;
    averageSpeedMps = 0.0;
    maxAltitudeMeters = 0.0;
    locationPoints.clear();
    reachedMountainIds.clear();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationSeconds++;
      notifyListeners();
    });

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
          _updatePosition(position);
        }
      },
    );

    notifyListeners();
  }

  void _updatePosition(Position position) {
    currentPosition = position;
    
    if (locationPoints.isNotEmpty) {
      final lastPoint = locationPoints.last;
      final distance = Geolocator.distanceBetween(
        lastPoint.latitude,
        lastPoint.longitude,
        position.latitude,
        position.longitude,
      );
      totalDistanceMeters += distance;
    }

    if (position.altitude > maxAltitudeMeters) {
      maxAltitudeMeters = position.altitude;
    }

    if (durationSeconds > 0) {
      averageSpeedMps = totalDistanceMeters / durationSeconds;
    }

    final newPoint = LocationPoint(
      workoutId: 0, // temporary id placeholder until workout is saved
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      timestamp: DateTime.now().toIso8601String(),
    );
    locationPoints.add(newPoint);

    _checkPeakArrival(position);

    notifyListeners();
  }

  void _checkPeakArrival(Position position) async {
    for (var mountain in allMountains) {
      if (reachedMountainIds.contains(mountain.id)) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        mountain.latitude,
        mountain.longitude,
      );

      if (distance <= 50.0) { // 50 meters
        reachedMountainIds.add(mountain.id!);
        _triggerPeakNotification(mountain);
      }
    }
  }

  Future<void> _triggerPeakNotification(Mountain mountain) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'peak_channel', 'Peak Achievements',
            channelDescription: 'Notifications for reaching mountain peaks',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
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

  void addPhotoToCurrentWorkout(String path, double lat, double lng, String? comment) {
    currentWorkoutPhotos.add(Photo(
      workoutId: 0,
      imagePath: path,
      latitude: lat,
      longitude: lng,
      comment: comment,
      timestamp: DateTime.now().toIso8601String()
    ));
    notifyListeners();
  }

  Future<Workout> stopWorkout() async {
    isTracking = false;
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    
    final workout = Workout(
      startTime: startTime!.toIso8601String(),
      endTime: DateTime.now().toIso8601String(),
      durationSeconds: durationSeconds,
      totalDistanceMeters: totalDistanceMeters,
      averageSpeedMps: averageSpeedMps,
      maxAltitudeMeters: maxAltitudeMeters,
    );

    int workoutId = await DatabaseHelper.instance.createWorkout(workout);

    for (var point in locationPoints) {
      await DatabaseHelper.instance.createLocationPoint(
        LocationPoint(
          workoutId: workoutId,
          latitude: point.latitude,
          longitude: point.longitude,
          altitude: point.altitude,
          timestamp: point.timestamp,
        )
      );
    }

    for (var photo in currentWorkoutPhotos) {
      await DatabaseHelper.instance.createPhoto(
        Photo(
          workoutId: workoutId,
          imagePath: photo.imagePath,
          latitude: photo.latitude,
          longitude: photo.longitude,
          comment: photo.comment,
          timestamp: photo.timestamp,
        )
      );
    }

    for (var mId in reachedMountainIds) {
      await DatabaseHelper.instance.createPeakSuccess(
        PeakSuccess(
          mountainId: mId,
          workoutId: workoutId,
          timestamp: DateTime.now().toIso8601String(),
        )
      );
    }

    notifyListeners();
    return workout;
  }
}
