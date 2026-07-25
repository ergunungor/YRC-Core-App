import 'package:latlong2/latlong.dart';

class PickedLocation {
  final LatLng latLng;
  final String displayName;

  const PickedLocation({required this.latLng, required this.displayName});
}
