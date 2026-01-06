import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/presentation/screens/charges_list_screen.dart';
import 'package:carwatt/presentation/screens/station_form_screen.dart';
import 'package:carwatt/presentation/widgets/app_drawer.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _db = DatabaseHelper.instance;
  final MapController _mapController = MapController();
  
  List<Station> _stations = [];
  List<Station> _filteredStations = [];
  bool _isLoading = true;
  LatLng? _userLocation;
  String _searchQuery = '';
  Set<String> _selectedNetworks = {};
  Set<String> _allNetworks = {};

  @override
  void initState() {
    super.initState();
    _loadStations();
    _getUserLocation();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    
    try {
      final stations = await _db.getStations();
      
      // Récupérer tous les réseaux uniques
      final networks = <String>{};
      for (var station in stations) {
        networks.addAll(station.reseaux);
      }
      
      setState(() {
        _stations = stations;
        _filteredStations = stations;
        _allNetworks = networks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
        
        // Centrer la carte sur la position de l'utilisateur
        if (_userLocation != null) {
          _mapController.move(_userLocation!, 10);
        }
      }
    } catch (e) {
      // Silencieux si la géolocalisation échoue
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredStations = _stations.where((station) {
        // Filtre par recherche
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final name = station.nom.toLowerCase();
          final address = station.adresse?.toLowerCase() ?? '';
          
          if (!name.contains(query) && !address.contains(query)) {
            return false;
          }
        }
        
        // Filtre par réseau
        if (_selectedNetworks.isNotEmpty) {
          final hasSelectedNetwork = station.reseaux.any(
            (network) => _selectedNetworks.contains(network),
          );
          if (!hasSelectedNetwork) return false;
        }
        
        return true;
      }).toList();
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Filtrer par réseau',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _allNetworks.map((network) {
                    final isSelected = _selectedNetworks.contains(network);
                    return CheckboxListTile(
                      title: Text(network),
                      value: isSelected,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            _selectedNetworks.add(network);
                          } else {
                            _selectedNetworks.remove(network);
                          }
                        });
                        setState(() {});
                        _applyFilters();
                      },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_selectedNetworks.isNotEmpty)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedNetworks.clear();
                            });
                            setState(() {});
                            _applyFilters();
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                    if (_selectedNetworks.isNotEmpty) const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _centerOnStations() {
    if (_filteredStations.isEmpty) return;
    
    // Calculer les limites pour englober toutes les stations
    double minLat = _filteredStations.first.positionGps!.latitude;
    double maxLat = _filteredStations.first.positionGps!.latitude;
    double minLng = _filteredStations.first.positionGps!.longitude;
    double maxLng = _filteredStations.first.positionGps!.longitude;
    
    for (var station in _filteredStations) {
      if (station.positionGps == null) continue;
      
      minLat = minLat < station.positionGps!.latitude ? minLat : station.positionGps!.latitude;
      maxLat = maxLat > station.positionGps!.latitude ? maxLat : station.positionGps!.latitude;
      minLng = minLng < station.positionGps!.longitude ? minLng : station.positionGps!.longitude;
      maxLng = maxLng > station.positionGps!.longitude ? maxLng : station.positionGps!.longitude;
    }
    
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _showNetworkStations(String network) {
    if (network.isEmpty) return;
    
    setState(() {
      _selectedNetworks = {network};
      _searchQuery = '';
    });
    _applyFilters();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filtré sur le réseau $network'),
        action: SnackBarAction(
          label: 'Réinitialiser',
          onPressed: () {
            setState(() {
              _selectedNetworks.clear();
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  void _editStation(Station station) async {
    final result = await Navigator.push<Station>(
      context,
      MaterialPageRoute(
        builder: (context) => StationFormScreen(station: station),
      ),
    );

    if (result != null) {
      // Recharger les stations
      _loadStations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Carte des stations'),
        actions: [
          if (_selectedNetworks.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedNetworks.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
            tooltip: 'Filtres',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnStations,
            tooltip: 'Centrer sur les stations',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une station...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _applyFilters();
                    },
                  ),
                ),

                // Compteur de stations
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_filteredStations.length} station${_filteredStations.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Carte
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _filteredStations.isNotEmpty && _filteredStations.first.positionGps != null
                            ? _filteredStations.first.positionGps!
                            : const LatLng(46.603354, 1.888334), // Centre de la France
                        initialZoom: 6,
                        minZoom: 5,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.carwatt',
                        ),
                        MarkerLayer(
                          markers: [
                            // Position de l'utilisateur
                            if (_userLocation != null)
                              Marker(
                                point: _userLocation!,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.my_location,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            // Stations
                            ..._filteredStations
                                .where((s) => s.positionGps != null)
                                .map((station) {
                              return Marker(
                                point: station.positionGps!,
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showStationDetails(station),
                                  child: Image.asset(
                                    'assets/images/map_marker.png', // Votre marker
                                    width: 40,
                                    height: 40,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showStationDetails(Station station) async {
    // Compter les charges à cette station
    final charges = await _db.getCharges();
    final chargesAtStation = charges.where((c) => c.stationId == station.id).length;
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.ev_station,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.nom,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (station.reseaux.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: station.reseaux.map((network) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Text(
                                network,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (station.adresse != null) ...[
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      station.adresse!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],

            if (_userLocation != null && station.positionGps != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.navigation, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Distance : ${station.distanceFrom(_userLocation)?.toStringAsFixed(1) ?? '?'} km',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            
            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showNetworkStations(station.reseaux.isNotEmpty ? station.reseaux.first : '');
                    },
                    icon: const Icon(Icons.network_check, size: 18),
                    label: const Text('Réseau', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editStation(station);
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Modifier', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Bouton vers les charges
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Naviguer vers l'onglet charges avec filtre sur cette station
                  // TODO: implémenter le filtre par station dans ChargesListScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChargesListScreenFiltered(stationId: station.id!),
                    ),
                  );
                },
                icon: const Icon(Icons.bolt),
                label: Text('Voir les $chargesAtStation charge${chargesAtStation > 1 ? 's' : ''}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
