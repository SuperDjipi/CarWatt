import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  
  const MapPickerScreen({
    super.key,
    this.initialPosition,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class MapPickerResult {
  final LatLng position;
  final String? address;
  
  MapPickerResult({
    required this.position,
    this.address,
  });
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _selectedPosition;
  bool _isLoadingPosition = false;
  String? _address;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    // Position initiale : soit celle passée, soit centre de la France
    _selectedPosition = widget.initialPosition ?? 
        const LatLng(46.603354, 1.888334);
    
    // Si pas de position initiale, essayer de récupérer la position actuelle
    if (widget.initialPosition == null) {
      _getCurrentPosition();
    }
  }

  Future<void> _getCurrentPosition() async {
    setState(() => _isLoadingPosition = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        final newPosition = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _selectedPosition = newPosition;
          _isLoadingPosition = false;
        });
        
        // Centrer la carte sur la position
        _mapController.move(_selectedPosition, 15);
        
        // Récupérer l'adresse
        await _onMapTap(newPosition);
      } else {
        setState(() => _isLoadingPosition = false);
      }
    } catch (e) {
      setState(() => _isLoadingPosition = false);
    }
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _selectedPosition = position;
      _address = null;
      _isLoadingAddress = true;
    });

    // Récupérer l'adresse
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final addressParts = <String>[];
        
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }
        if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty) {
          addressParts.add(placemark.postalCode!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }
        
        setState(() {
          _address = addressParts.join(', ');
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélectionner la position'),
        actions: [
          TextButton.icon(
            onPressed: () {
              final result = MapPickerResult(
                position: _selectedPosition,
                address: _address,
              );
              Navigator.pop(context, result);
            },
            icon: const Icon(Icons.check, color: Colors.green),
            label: const Text(
              'Valider',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15,
              minZoom: 5,
              maxZoom: 18,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'club.djipi.carwatt',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition,
                    width: 50,
                    height: 50,
                    child: Image.asset(
                      'assets/images/map_marker.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Instructions en haut
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Appuyez sur la carte pour placer le marqueur',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Coordonnées en bas
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Position sélectionnée',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Latitude',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _selectedPosition.latitude.toStringAsFixed(6),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Longitude',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _selectedPosition.longitude.toStringAsFixed(6),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // AJOUTER CETTE PARTIE POUR L'ADRESSE
                    if (_isLoadingAddress || _address != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      const Text(
                        'Adresse',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _isLoadingAddress
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Recherche de l\'adresse...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _address ?? 'Adresse non disponible',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bouton ma position
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _isLoadingPosition ? null : _getCurrentPosition,
              backgroundColor: Colors.white,
              child: _isLoadingPosition
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
