import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hiking_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const doubleType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE Workouts (
  id $idType,
  startTime $textType,
  endTime $textTypeNullable,
  durationSeconds $intType,
  totalDistanceMeters $doubleType,
  averageSpeedMps $doubleType,
  maxAltitudeMeters $doubleType
)
''');

    await db.execute('''
CREATE TABLE LocationPoints (
  id $idType,
  workoutId INTEGER NOT NULL,
  latitude $doubleType,
  longitude $doubleType,
  altitude $doubleType,
  timestamp $textType,
  FOREIGN KEY (workoutId) REFERENCES Workouts (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE Photos (
  id $idType,
  workoutId INTEGER NOT NULL,
  imagePath $textType,
  latitude $doubleType,
  longitude $doubleType,
  comment $textTypeNullable,
  timestamp $textType,
  FOREIGN KEY (workoutId) REFERENCES Workouts (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE Mountains (
  id $idType,
  name $textType,
  latitude $doubleType,
  longitude $doubleType,
  altitude $doubleType
)
''');

    await db.execute('''
CREATE TABLE PeaksSuccess (
  id $idType,
  mountainId INTEGER NOT NULL,
  workoutId INTEGER NOT NULL,
  timestamp $textType,
  FOREIGN KEY (mountainId) REFERENCES Mountains (id) ON DELETE CASCADE,
  FOREIGN KEY (workoutId) REFERENCES Workouts (id) ON DELETE CASCADE
)
''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // Workouts
  Future<int> createWorkout(Workout workout) async {
    final db = await instance.database;
    return await db.insert('Workouts', workout.toJson());
  }

  Future<int> updateWorkout(Workout workout) async {
    final db = await instance.database;
    return await db.update(
      'Workouts',
      workout.toJson(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await instance.database;
    final orderBy = 'startTime DESC';
    final result = await db.query('Workouts', orderBy: orderBy);
    return result.map((json) => Workout.fromJson(json)).toList();
  }

  // Location Points
  Future<int> createLocationPoint(LocationPoint point) async {
    final db = await instance.database;
    return await db.insert('LocationPoints', point.toJson());
  }

  Future<List<LocationPoint>> getLocationPoints(int workoutId) async {
    final db = await instance.database;
    final result = await db.query(
      'LocationPoints',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'timestamp ASC'
    );
    return result.map((json) => LocationPoint.fromJson(json)).toList();
  }

  // Photos
  Future<int> createPhoto(Photo photo) async {
    final db = await instance.database;
    return await db.insert('Photos', photo.toJson());
  }

  Future<List<Photo>> getPhotos(int workoutId) async {
    final db = await instance.database;
    final result = await db.query(
      'Photos',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );
    return result.map((json) => Photo.fromJson(json)).toList();
  }

  // Peak Success
  Future<int> createPeakSuccess(PeakSuccess peakSuccess) async {
    final db = await instance.database;
    return await db.insert('PeaksSuccess', peakSuccess.toJson());
  }

  Future<int> getPeakSuccessCount(int mountainId) async {
    final db = await instance.database;
    final result = await db.query(
      'PeaksSuccess',
      where: 'mountainId = ?',
      whereArgs: [mountainId],
    );
    return result.length;
  }

  Future<List<Mountain>> getMountainsForWorkout(int workoutId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT M.* FROM Mountains M
      JOIN PeaksSuccess P ON M.id = P.mountainId
      WHERE P.workoutId = ?
    ''', [workoutId]);
    return result.map((json) => Mountain.fromJson(json)).toList();
  }

  // Mountains
  Future<List<Mountain>> getAllMountains() async {
    final db = await instance.database;
    final result = await db.query('Mountains');
    return result.map((json) => Mountain.fromJson(json)).toList();
  }

  Future<void> loadMountainsIfEmpty() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM Mountains'));
    
    // If the DB only has the old small dataset, clear and reload
    if (count == null || count < 1000) {
      await db.rawDelete('DELETE FROM Mountains');
      // Load from JSON
      final String jsonString = await rootBundle.loadString('assets/mountains.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      Batch batch = db.batch();
      for (var item in jsonList) {
        batch.insert('Mountains', {
          'name': item['name'],
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'altitude': item['altitude'],
        });
      }
      await batch.commit(noResult: true);
    }
  }
}

