import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  String _mapLayer = 'Standard';
  LatLng? _userLocation;
  LatLng? _markerPosition;
  List<LatLng> _routePoints = [];
  final _searchController = TextEditingController();
  StreamSubscription<Position>? _positionStream;
  static const String _locationGrantedKey = 'location_permission_granted';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionStatus();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final granted = prefs.getBool(_locationGrantedKey) ?? false;
    if (granted) {
      _loadLocation();
    } else {
      _askPermissionDialog(prefs);
    }
  }

  Future<void> _askPermissionDialog(SharedPreferences prefs) async {
    final navigator = Navigator.of(context);
    final granted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Autoriser la localisation ?'),
        content: const Text('Be Safe a besoin de votre position pour fonctionner.'),
        actions: [
          TextButton(onPressed: () => navigator.pop(false), child: const Text('Non')),
          TextButton(onPressed: () => navigator.pop(true), child: const Text('Oui')),
        ],
      ),
    );

    if (!mounted || granted != true) return;

    await prefs.setBool(_locationGrantedKey, true);
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (Platform.isAndroid) await Geolocator.openLocationSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activez la localisation.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission localisation refusée.')),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    _moveTo(pos.latitude, pos.longitude);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    });
  }

  void _moveTo(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 15);
  }

  Future<void> _searchAddress(String query) async {
    final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'be_safe_app'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        final pos = LatLng(lat, lon);
        if (!mounted) return;
        setState(() {
          _markerPosition = pos;
          _routePoints.clear();
        });
        _moveTo(lat, lon);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse non trouvée')),
        );
      }
    }
  }

  Future<void> _buildRoute(LatLng start, LatLng end) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final coords = data['routes'][0]['geometry']['coordinates'];
      if (!mounted) return;
      setState(() {
        _routePoints = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (_userLocation != null)
        Marker(
          point: _userLocation!,
          width: 30,
          height: 30,
          child: const Icon(Icons.my_location, color: Colors.blue),
        ),
      if (_markerPosition != null)
        Marker(
          point: _markerPosition!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red),
        ),
    ];

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher une adresse',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchAddress(_searchController.text.trim()),
                ),
              ),
              onSubmitted: _searchAddress,
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(46.603354, 1.888334),
                initialZoom: 5,
                onLongPress: (tapPos, point) {
                  setState(() => _markerPosition = point);
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions),
                        label: const Text('Itinéraire vers ce point'),
                        onPressed: () async {
                          Navigator.pop(context);
                          if (!mounted) return;
                          if (_userLocation != null && _markerPosition != null) {
                            await _buildRoute(_userLocation!, _markerPosition!);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapLayer == 'Satellite'
                      ? 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.be_safe',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, strokeWidth: 4, color: Colors.blue),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'btn_location',
            onPressed: () {
              if (_userLocation != null) {
                _moveTo(_userLocation!.latitude, _userLocation!.longitude);
              } else {
                _checkPermissionStatus();
              }
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'btn_layer',
            onPressed: () {
              setState(() {
                _mapLayer = _mapLayer == 'Standard' ? 'Satellite' : 'Standard';
              });
            },
            child: const Icon(Icons.layers),
          ),
        ],
      ),
    );
  }
}
