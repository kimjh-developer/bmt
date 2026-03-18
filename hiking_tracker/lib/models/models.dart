class Workout {
  final int? id;
  final String startTime;
  final String? endTime;
  final int durationSeconds;
  final double totalDistanceMeters;
  final double averageSpeedMps;
  final double maxAltitudeMeters;

  Workout({
    this.id,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.totalDistanceMeters,
    required this.averageSpeedMps,
    required this.maxAltitudeMeters,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'startTime': startTime,
        'endTime': endTime,
        'durationSeconds': durationSeconds,
        'totalDistanceMeters': totalDistanceMeters,
        'averageSpeedMps': averageSpeedMps,
        'maxAltitudeMeters': maxAltitudeMeters,
      };

  static Workout fromJson(Map<String, Object?> json) => Workout(
        id: json['id'] as int?,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String?,
        durationSeconds: json['durationSeconds'] as int,
        totalDistanceMeters: json['totalDistanceMeters'] as double,
        averageSpeedMps: json['averageSpeedMps'] as double,
        maxAltitudeMeters: json['maxAltitudeMeters'] as double,
      );
}

class LocationPoint {
  final int? id;
  final int workoutId;
  final double latitude;
  final double longitude;
  final double altitude;
  final String timestamp;

  LocationPoint({
    this.id,
    required this.workoutId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'timestamp': timestamp,
      };

  static LocationPoint fromJson(Map<String, Object?> json) => LocationPoint(
        id: json['id'] as int?,
        workoutId: json['workoutId'] as int,
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        altitude: json['altitude'] as double,
        timestamp: json['timestamp'] as String,
      );
}

class Photo {
  final int? id;
  final int workoutId;
  final String imagePath;
  final double latitude;
  final double longitude;
  final String? comment;
  final String timestamp;

  Photo({
    this.id,
    required this.workoutId,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.comment,
    required this.timestamp,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'workoutId': workoutId,
        'imagePath': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'comment': comment,
        'timestamp': timestamp,
      };

  static Photo fromJson(Map<String, Object?> json) => Photo(
        id: json['id'] as int?,
        workoutId: json['workoutId'] as int,
        imagePath: json['imagePath'] as String,
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        comment: json['comment'] as String?,
        timestamp: json['timestamp'] as String,
      );
}

class Mountain {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final double altitude;

  Mountain({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
      };

  static Mountain fromJson(Map<String, Object?> json) => Mountain(
        id: json['id'] as int?,
        name: json['name'] as String,
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
        altitude: json['altitude'] as double,
      );
}

class PeakSuccess {
  final int? id;
  final int mountainId;
  final int workoutId;
  final String timestamp;

  PeakSuccess({
    this.id,
    required this.mountainId,
    required this.workoutId,
    required this.timestamp,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'mountainId': mountainId,
        'workoutId': workoutId,
        'timestamp': timestamp,
      };

  static PeakSuccess fromJson(Map<String, Object?> json) => PeakSuccess(
        id: json['id'] as int?,
        mountainId: json['mountainId'] as int,
        workoutId: json['workoutId'] as int,
        timestamp: json['timestamp'] as String,
      );
}
