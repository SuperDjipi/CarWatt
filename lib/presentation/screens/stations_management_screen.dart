import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/presentation/screens/station_form_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class StationsManagementScreen extends StatefulWidget {
  const StationsManagementScreen({super.key});

  @override
  State<StationsManagementScreen> createState() => _StationsManagementScreenState();
}

class _StationsManagementScreenState extends State<StationsManagementScreen> {
  final _db = DatabaseHelper.instance;
  List<Station> _stations = [];
  List<Station> _filteredStations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  LatLng? _userLocation;
  String _sortBy = 'nom'; // nom, distance, reseau

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
      _applyFilters();
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
        _applyFilters();
      }
    } catch (e) {
      // Silencieux
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredStations = _stations.where((station) {
        if (_searchQuery.isEmpty) return true;
        
        final query = _searchQuery.toLowerCase();
        final name = station.nom.toLowerCase();
        final address = station.adresse?.toLowerCase() ?? '';
        final networks = station.reseaux.join(' ').toLowerCase();
        
        return name.contains(query) || 
               address.contains(query) || 
               networks.contains(query);
      }).toList();

      // Tri
      switch (_sortBy) {
        case 'nom':
          _filteredStations.sort((a, b) => a.nom.compareTo(b.nom));
          break;
        case 'distance':
          if (_userLocation != null) {
            _filteredStations.sort((a, b) {
              final distA = a.distanceFrom(_userLocation) ?? double.infinity;
              final distB = b.distanceFrom(_userLocation) ?? double.infinity;
              return distA.compareTo(distB);
            });
          }
          break;
        case 'reseau':
          _filteredStations.sort((a, b) {
            final reseauA = a.reseaux.isNotEmpty ? a.reseaux.first : '';
            final reseauB = b.reseaux.isNotEmpty ? b.reseaux.first : '';
            return reseauA.compareTo(reseauB);
          });
          break;
      }
    });
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
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
              'Trier par',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSortOption('Nom', 'nom', Icons.sort_by_alpha),
          _buildSortOption('Distance', 'distance', Icons.near_me),
          _buildSortOption('Réseau', 'reseau', Icons.network_check),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSortOption(String label, String value, IconData icon) {
    final isSelected = _sortBy == value;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.green : Colors.grey[600],
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.green : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        _applyFilters();
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortMenu,
            tooltip: 'Trier',
          ),
        ],
      ),
      body: Column(
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
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),

          // Compteur
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredStations.length} station${_filteredStations.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Liste des stations
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.ev_station,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucune station enregistrée'
                                  : 'Aucun résultat',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredStations.length,
                          itemBuilder: (context, index) {
                            final station = _filteredStations[index];
                            return _buildStationCard(station);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<Station>(
            context,
            MaterialPageRoute(
              builder: (context) => const StationFormScreen(),
            ),
          );
          
          if (result != null) {
            _loadStations();
          }
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStationCard(Station station) {
    final distance = _userLocation != null
        ? station.distanceFrom(_userLocation)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push<Station>(
            context,
            MaterialPageRoute(
              builder: (context) => StationFormScreen(station: station),
            ),
          );
          
          if (result != null) {
            _loadStations();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.ev_station,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.nom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (distance != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.navigation, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${distance.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              if (station.reseaux.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
              
              if (station.adresse != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        station.adresse!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
