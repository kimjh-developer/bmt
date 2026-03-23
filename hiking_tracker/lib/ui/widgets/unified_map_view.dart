import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as amaps;

/// A unified marker that can be converted to either Google or Apple maps markers.
class UnifiedMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String? title;
  final String? snippet;
  final VoidCallback? onTap;
  final Color? color;
  final Uint8List? iconBytes;
  final int zIndex;

  UnifiedMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.title,
    this.snippet,
    this.onTap,
    this.color,
    this.iconBytes,
    this.zIndex = 0,
  });
}

/// A unified polyline that can be converted to either Google or Apple maps polylines.
class UnifiedPolyline {
  final String id;
  final List<UnifiedLatLng> points;
  final Color color;
  final double width;

  UnifiedPolyline({
    required this.id,
    required this.points,
    this.color = Colors.blue,
    this.width = 5.0,
  });
}

class UnifiedLatLng {
  final double latitude;
  final double longitude;
  UnifiedLatLng(this.latitude, this.longitude);
}

/// Controller to unify map operations.
class UnifiedMapController {
  gmaps.GoogleMapController? _googleController;
  amaps.AppleMapController? _appleController;

  void setGoogleController(gmaps.GoogleMapController controller) => _googleController = controller;
  void setAppleController(amaps.AppleMapController controller) => _appleController = controller;

  Future<void> moveCamera(UnifiedLatLng center, double zoom) async {
    if (_googleController != null) {
      await _googleController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(center.latitude, center.longitude),
          zoom,
        ),
      );
    } else if (_appleController != null) {
      await _appleController!.animateCamera(
        amaps.CameraUpdate.newLatLngZoom(
          amaps.LatLng(center.latitude, center.longitude),
          zoom,
        ),
      );
    }
  }

  Future<void> fitBounds(List<UnifiedLatLng> points, {double padding = 50.0}) async {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if (_googleController != null) {
      final bounds = gmaps.LatLngBounds(
        southwest: gmaps.LatLng(minLat, minLng),
        northeast: gmaps.LatLng(maxLat, maxLng),
      );
      await _googleController!.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } else if (_appleController != null) {
      final bounds = amaps.LatLngBounds(
        southwest: amaps.LatLng(minLat, minLng),
        northeast: amaps.LatLng(maxLat, maxLng),
      );
      await _appleController!.animateCamera(
        amaps.CameraUpdate.newLatLngBounds(bounds, padding),
      );
    }
  }
}

class UnifiedMapView extends StatelessWidget {
  final UnifiedLatLng initialCenter;
  final double initialZoom;
  final Set<UnifiedMarker> markers;
  final Set<UnifiedPolyline> polylines;
  final Function(UnifiedMapController)? onMapCreated;
  final Function(double lat, double lng, double zoom)? onCameraMove;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;

  const UnifiedMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14.0,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onCameraMove,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(child: Text('Web maps not implemented yet'));
    }

    if (Platform.isAndroid) {
      return _buildGoogleMap();
    } else if (Platform.isIOS) {
      return _buildAppleMap();
    } else {
      return const Center(child: Text('Unsupported Platform'));
    }
  }

  Widget _buildGoogleMap() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(initialCenter.latitude, initialCenter.longitude),
        zoom: initialZoom,
      ),
      onMapCreated: (controller) {
        if (onMapCreated != null) {
          final unified = UnifiedMapController();
          unified.setGoogleController(controller);
          onMapCreated!(unified);
        }
      },
      markers: markers.map((m) {
        return gmaps.Marker(
          markerId: gmaps.MarkerId(m.id),
          position: gmaps.LatLng(m.latitude, m.longitude),
          infoWindow: gmaps.InfoWindow(title: m.title, snippet: m.snippet, onTap: m.onTap),
          onTap: m.onTap,
          zIndexInt: m.zIndex,
          icon: m.iconBytes != null
              ? gmaps.BitmapDescriptor.bytes(m.iconBytes!)
              : (m.color != null 
                  ? gmaps.BitmapDescriptor.defaultMarkerWithHue(_colorToHue(m.color!))
                  : gmaps.BitmapDescriptor.defaultMarker),
        );
      }).toSet(),
      onCameraMove: (cam) {
        onCameraMove?.call(cam.target.latitude, cam.target.longitude, cam.zoom);
      },
      polylines: polylines.map((p) {
        return gmaps.Polyline(
          polylineId: gmaps.PolylineId(p.id),
          points: p.points.map((pt) => gmaps.LatLng(pt.latitude, pt.longitude)).toList(),
          color: p.color,
          width: p.width.toInt(),
        );
      }).toSet(),
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildAppleMap() {
    return amaps.AppleMap(
      initialCameraPosition: amaps.CameraPosition(
        target: amaps.LatLng(initialCenter.latitude, initialCenter.longitude),
        zoom: initialZoom,
      ),
      onMapCreated: (controller) {
        if (onMapCreated != null) {
          final unified = UnifiedMapController();
          unified.setAppleController(controller);
          onMapCreated!(unified);
        }
      },
      annotations: markers.map((m) {
        return amaps.Annotation(
          annotationId: amaps.AnnotationId(m.id),
          position: amaps.LatLng(m.latitude, m.longitude),
          infoWindow: amaps.InfoWindow(title: m.title, snippet: m.snippet, onTap: m.onTap),
          onTap: m.onTap,
          icon: m.iconBytes != null
              ? amaps.BitmapDescriptor.fromBytes(m.iconBytes!)
              : amaps.BitmapDescriptor.defaultAnnotation,
        );
      }).toSet(),
      onCameraMove: (cam) {
        onCameraMove?.call(cam.target.latitude, cam.target.longitude, cam.zoom);
      },
      polylines: polylines.map((p) {
        return amaps.Polyline(
          polylineId: amaps.PolylineId(p.id),
          points: p.points.map((pt) => amaps.LatLng(pt.latitude, pt.longitude)).toList(),
          color: p.color,
          width: p.width.toInt(),
        );
      }).toSet(),
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
    );
  }

  double _colorToHue(Color color) {
    if (color == Colors.red || color == Colors.redAccent) return gmaps.BitmapDescriptor.hueRed;
    if (color == Colors.green || color == Colors.greenAccent) return gmaps.BitmapDescriptor.hueGreen;
    if (color == Colors.blue || color == Colors.blueAccent) return gmaps.BitmapDescriptor.hueBlue;
    if (color == Colors.orange || color == Colors.orangeAccent) return gmaps.BitmapDescriptor.hueOrange;
    if (color == Colors.yellow) return gmaps.BitmapDescriptor.hueYellow;
    if (color == Colors.purple) return gmaps.BitmapDescriptor.hueViolet;
    return gmaps.BitmapDescriptor.hueRed;
  }
}
