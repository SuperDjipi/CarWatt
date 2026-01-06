import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/presentation/screens/station_form_screen.dart';
import 'package:carwatt/presentation/screens/charges_list_screen.dart';
import 'package:carwatt/presentation/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final _db = DatabaseHelper.instance;
  List<Station> _stations = [];
  List<Station> _filteredStations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  LatLng? _userLocation;
  String? _selectedNetwork;

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
      setState(() {
        _stations = stations;
        _filteredStations = stations;
        _isLoading = false;
      });
      
      // Centrer sur les stations après chargement
      Future.delayed(const Duration(milliseconds: 300), () {
        _fitMapToStations();
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
      }
    } catch (e) {
      // Silencieux si échec géolocalisation
    }
  }

  void _fitMapToStations() {
    if (_filteredStations.isEmpty) return;
    
    final stationsWithPos = _filteredStations
        .where((s) => s.positionGps != null)
        .toList();
    
    if (stationsWithPos.isEmpty) return;
    
    // Calculer les limites
    double minLat = stationsWithPos.first.positionGps!.latitude;
    double maxLat = stationsWithPos.first.positionGps!.latitude;
    double minLng = stationsWithPos.first.positionGps!.longitude;
    double maxLng = stationsWithPos.first.positionGps!.longitude;
    
    for (var station in stationsWithPos) {
      final pos = station.positionGps!;
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }
    
    // Ajouter une marge de 10%
    final latMargin = (maxLat - minLat) * 0.1;
    final lngMargin = (maxLng - minLng) * 0.1;
    
    final bounds = LatLngBounds(
      LatLng(minLat - latMargin, minLng - lngMargin),
      LatLng(maxLat + latMargin, maxLng + lngMargin),
    );
    
    // Ajuster la vue
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _centerOnUserLocation() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 14);
    }
  }

  void _applyFilter() {
    setState(() {
      // Filtrer par réseau si sélectionné
      List<Station> filtered = _selectedNetwork == null
          ? _stations
          : _stations.where((s) => s.reseaux.contains(_selectedNetwork)).toList();
      
      // Filtrer par recherche
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((station) {
          final name = station.nom.toLowerCase();
          final address = station.adresse?.toLowerCase() ?? '';
          final networks = station.reseaux.join(' ').toLowerCase();
          return name.contains(query) || 
                 address.contains(query) || 
                 networks.contains(query);
        }).toList();
      }
      
      _filteredStations = filtered;
    });
    
    // Recentrer après filtrage
    Future.delayed(const Duration(milliseconds: 100), () {
      _fitMapToStations();
    });
  }

  List<String> _getAllNetworks() {
    final networks = <String>{};
    for (var station in _stations) {
      networks.addAll(station.reseaux);
    }
    final sortedNetworks = networks.toList()..sort();
    return sortedNetworks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Carte des stations'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
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
                                    _applyFilter();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _applyFilter();
                        },
                      ),
                    ),

                    // Compteur de stations
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_filteredStations.length} station${_filteredStations.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_selectedNetwork != null)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedNetwork = null;
                                });
                                _applyFilter();
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: Text(_selectedNetwork!),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Carte
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(46.603354, 1.888334),
                          initialZoom: 6,
                          minZoom: 5,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'club.djipi.carwatt',
                          ),
                          if (_userLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _userLocation!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: _filteredStations
                                .where((s) => s.positionGps != null)
                                .map((station) {
                              return Marker(
                                point: station.positionGps!,
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showStationDetails(station),
                                  child: Image.asset(
                                    'assets/images/map_marker.png',
                                    width: 40,
                                    height: 40,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Filtre réseau en haut à droite
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.filter_list,
                        color: _selectedNetwork != null ? Colors.green : Colors.grey[700],
                      ),
                      tooltip: 'Filtrer par réseau',
                      onSelected: (network) {
                        setState(() {
                          _selectedNetwork = network == 'Tous' ? null : network;
                        });
                        _applyFilter();
                      },
                      itemBuilder: (context) {
                        final networks = ['Tous', ..._getAllNetworks()];
                        return networks.map((network) {
                          return PopupMenuItem(
                            value: network,
                            child: Row(
                              children: [
                                if (network == 'Tous' && _selectedNetwork == null ||
                                    network == _selectedNetwork)
                                  const Icon(Icons.check, color: Colors.green, size: 20),
                                if (network != 'Tous' || _selectedNetwork != null)
                                  const SizedBox(width: 20),
                                const SizedBox(width: 8),
                                Text(network),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),

                // FAB en bas à droite
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bouton centrer sur position GPS
                      if (_userLocation != null)
                        FloatingActionButton(
                          heroTag: 'location',
                          onPressed: _centerOnUserLocation,
                          backgroundColor: Colors.white,
                          tooltip: 'Ma position',
                          child: const Icon(Icons.my_location, color: Colors.blue),
                        ),
                      const SizedBox(height: 12),
                      // Bouton centrer sur toutes les stations
                      FloatingActionButton(
                        heroTag: 'fit',
                        onPressed: _fitMapToStations,
                        backgroundColor: Colors.white,
                        tooltip: 'Voir toutes les stations',
                        child: const Icon(Icons.fit_screen, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showStationDetails(Station station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return FutureBuilder<List<Charge>>(
            future: _db.getCharges(orderBy: 'horodatage DESC'),
            builder: (context, snapshot) {
              final allCharges = snapshot.data ?? [];
              final stationCharges = allCharges
                  .where((c) => c.stationId == station.id)
                  .toList();

              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (station.adresse != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  station.adresse!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (station.reseaux.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: station.reseaux.map((network) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text(
                              network,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Statistiques
                    if (stationCharges.isNotEmpty) ...[
                      Text(
                        '${stationCharges.length} charge${stationCharges.length > 1 ? 's' : ''} enregistrée${stationCharges.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dernière charge : ${DateFormat('dd/MM/yyyy').format(stationCharges.first.horodatage)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                if (station.reseaux.isNotEmpty) {
                                  _selectedNetwork = station.reseaux.first;
                                }
                              });
                              _applyFilter();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Réseau'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      StationFormScreen(station: station),
                                ),
                              );
                              if (result != null) {
                                _loadStations();
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Modifier'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (stationCharges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChargesListScreenFiltered(
                                  initialStationFilter: station.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.list),
                          label: Text('Voir les ${stationCharges.length} charges'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChargesListScreenFiltered extends StatelessWidget {
  final int? initialStationFilter;

  const ChargesListScreenFiltered({
    super.key,
    this.initialStationFilter,
  });

  @override
  Widget build(BuildContext context) {
    return ChargesListScreen(
      initialStationFilter: initialStationFilter,
    );
  }
}