import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/trajet.dart';
import 'package:intl/intl.dart';

class TrajetStatsScreen extends StatefulWidget {
  const TrajetStatsScreen({super.key});

  @override
  State<TrajetStatsScreen> createState() => _TrajetStatsScreenState();
}

class _TrajetStatsScreenState extends State<TrajetStatsScreen> {
  final _db = DatabaseHelper.instance;
  List<Trajet> _trajets = [];
  bool _isLoading = true;
  
  // Stats globales
  int _totalTrajets = 0;
  double _distanceTotale = 0;
  double _consoMoyenne = 0;
  
  // Trajets récurrents (groupés par paire lieu départ/arrivée)
  Map<String, List<Trajet>> _trajetsRecurrents = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final trajets = await _db.getTrajets(orderBy: 'date DESC');
      
      // Calculer stats globales
      int total = trajets.length;
      double distTotal = 0;
      double consoTotal = 0;
      int consoCount = 0;
      
      for (var trajet in trajets) {
        final dist = trajet.distance;
        final conso = trajet.consoKwhAu100;
        
        if (dist != null) {
          distTotal += dist;
        }
        
        if (conso != null && conso > 0) {
          consoTotal += conso;
          consoCount++;
        }
      }
      
      // Grouper les trajets récurrents
      final recurrents = <String, List<Trajet>>{};
      print('=== DEBUG TRAJETS RÉCURRENTS ===');
      for (var trajet in trajets) {
        print('Trajet: ${trajet.lieuDepart} → ${trajet.lieuArrivee}');
        if (trajet.lieuDepart != null && trajet.lieuArrivee != null) {

          final depart = trajet.lieuDepart!.trim().toLowerCase();
          final arrivee = trajet.lieuArrivee!.trim().toLowerCase();

          // IGNORER les trajets avec départ = arrivée
          if (depart == arrivee) {
            print('  -> Ignoré (même lieu)');
            continue;
          }
          // Clé normalisée pour identifier les trajets similaires
          final key = '$depart → $arrivee';
          print('  -> Clé: $key');
          recurrents.putIfAbsent(key, () => []);
          recurrents[key]!.add(trajet);
        }
      }
      print('Trajets récurrents trouvés: ${recurrents.length}');
      recurrents.forEach((key, list) {
        print('  $key: ${list.length} occurrences');
      });
      // Ne garder que ceux avec au moins 2 occurrences
      recurrents.removeWhere((key, list) => list.length < 2);
      
      setState(() {
        _trajets = trajets;
        _totalTrajets = total;
        _distanceTotale = distTotal;
        _consoMoyenne = consoCount > 0 ? consoTotal / consoCount : 0;
        _trajetsRecurrents = recurrents;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques trajets'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trajets.isEmpty
              ? const Center(
                  child: Text('Aucun trajet enregistré'),
                )
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Stats globales
                      const Text(
                        'Vue d\'ensemble',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildStatsCard(
                        icon: Icons.route,
                        iconColor: Colors.blue,
                        title: 'Total trajets',
                        value: _totalTrajets.toString(),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildStatsCard(
                        icon: Icons.straighten,
                        iconColor: Colors.green,
                        title: 'Distance totale',
                        value: '${_distanceTotale.toStringAsFixed(0)} km',
                      ),
                      const SizedBox(height: 12),
                      
                      _buildStatsCard(
                        icon: Icons.eco,
                        iconColor: Colors.orange,
                        title: 'Consommation moyenne',
                        value: '${_consoMoyenne.toStringAsFixed(1)} kWh/100km',
                      ),

                      const SizedBox(height: 32),

                      // Trajets récurrents
                      if (_trajetsRecurrents.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Trajets récurrents',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_trajetsRecurrents.length}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trajets effectués au moins 2 fois',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        ..._trajetsRecurrents.entries.map((entry) {
                          return _buildRecurrentTrajetCard(entry.key, entry.value);
                        }).toList(),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.timeline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun trajet récurrent détecté',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Créez plusieurs fois le même trajet pour voir les statistiques',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrentTrajetCard(String normalizedRoute, List<Trajet> trajets) {
    // Utiliser les vrais noms du premier trajet pour l'affichage
    final displayRoute = trajets.isNotEmpty 
        ? '${trajets.first.lieuDepart} → ${trajets.first.lieuArrivee}'
         : normalizedRoute;
    // Calculer les stats pour ce trajet
    double consoTotal = 0;
    double consoMin = double.infinity;
    double consoMax = 0;
    int consoCount = 0;
    double distMoyenne = 0;
    int distCount = 0;
    
    for (var trajet in trajets) {
      final conso = trajet.consoKwhAu100;
      final dist = trajet.distance;
      
      if (conso != null && conso > 0) {
        consoTotal += conso;
        consoCount++;
        if (conso < consoMin) consoMin = conso;
        if (conso > consoMax) consoMax = conso;
      }
      
      if (dist != null) {
        distMoyenne += dist;
        distCount++;
      }
    }
    
    final consoMoy = consoCount > 0 ? consoTotal / consoCount : 0;
    distMoyenne = distCount > 0 ? distMoyenne / distCount : 0;
    
    final dateDebut = trajets.last.date;
    final dateFin = trajets.first.date;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTrajetDetails(displayRoute, trajets),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // displayRoute
              Row(
                children: [
                  Icon(Icons.repeat, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayRoute,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildSmallStat(
                      '${trajets.length}',
                      'fois',
                      Icons.replay,
                    ),
                  ),
                  Expanded(
                    child: _buildSmallStat(
                      '${distMoyenne.toStringAsFixed(0)} km',
                      'distance',
                      Icons.straighten,
                    ),
                  ),
                  Expanded(
                    child: _buildSmallStat(
                      '${consoMoy.toStringAsFixed(1)}',
                      'kWh/100km',
                      Icons.eco,
                    ),
                  ),
                ],
              ),

              if (consoCount > 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_down, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${consoMin.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${consoMax.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Text(
                'Du ${DateFormat('dd/MM/yyyy').format(dateDebut)} au ${DateFormat('dd/MM/yyyy').format(dateFin)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showTrajetDetails(String route, List<Trajet> trajets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  route,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: trajets.length,
                  itemBuilder: (context, index) {
                    final trajet = trajets[index];
                    final conso = trajet.consoKwhAu100;
                    final dist = trajet.distance;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            '${trajets.length - index}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        title: Text(
                          DateFormat('dd/MM/yyyy').format(trajet.date),
                        ),
                        subtitle: dist != null
                            ? Text('${dist.toStringAsFixed(0)} km')
                            : null,
                        trailing: conso != null
                            ? Text(
                                '${conso.toStringAsFixed(1)}\nkWh/100',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.right,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
