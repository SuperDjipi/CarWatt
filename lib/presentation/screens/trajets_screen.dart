import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/trajet.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/presentation/screens/trajet_form_screen.dart';
import 'package:carwatt/presentation/screens/trajet_stats_screen.dart';

class TrajetsScreen extends StatefulWidget {
  const TrajetsScreen({super.key});

  @override
  State<TrajetsScreen> createState() => _TrajetsScreenState();
}

class _TrajetsScreenState extends State<TrajetsScreen> {
  final _db = DatabaseHelper.instance;
  List<Trajet> _trajets = [];
  List<Charge> _charges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final trajets = await _db.getTrajets();
      final charges = await _db.getCharges();
      
      setState(() {
        _trajets = trajets;
        _charges = charges;
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

  // Récupérer une charge par son ID
  Charge? _getChargeById(int id) {
    try {
      return _charges.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trajets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrajetStatsScreen(),
                ),
              );
            },
            tooltip: 'Statistiques',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trajets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.route,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun trajet enregistré',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _createTrajet,
                        icon: const Icon(Icons.add),
                        label: const Text('Créer un trajet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trajets.length,
                    itemBuilder: (context, index) {
                      final trajet = _trajets[index];
                      return _buildTrajetCard(trajet);
                    },
                  ),
                ),
      floatingActionButton: _trajets.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createTrajet,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTrajetCard(Trajet trajet) {
    Charge? chargeDepart;
    Charge? chargeArrivee;
  
    if (trajet.rechargeDepart != null) {
      chargeDepart = _getChargeById(trajet.rechargeDepart!);
    }
    if (trajet.rechargeArrivee != null) {
      chargeArrivee = _getChargeById(trajet.rechargeArrivee!);
    }
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    // Calculer la distance
    double? distance = trajet.distance; // Utiliser la méthode de la classe Trajet
  
    // Si pas de distance calculée, essayer avec les charges
    if (distance == null && chargeDepart?.kilometrage != null && chargeArrivee?.kilometrage != null) {
      distance = chargeArrivee!.kilometrage! - chargeDepart!.kilometrage!;
    }

    // Calculer la consommation
    final consoAu100 = trajet.consoKwhAu100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTrajetDetails(trajet),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(trajet.date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (consoAu100 != null)
                    Container(
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
                        '${consoAu100.toStringAsFixed(1)} kWh/100km',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),

              // Trajet visuel
              Row(
                children: [
                  // Départ
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Départ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chargeDepart?.stationNom ?? 'Station inconnue',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (chargeDepart?.jaugeFin != null)
                          Text(
                            '${chargeDepart!.jaugeFin.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Flèche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(Icons.arrow_forward, color: Colors.grey[400], size: 20),
                        if (distance != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${distance.toStringAsFixed(0)} km',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Arrivée
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Arrivée',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chargeArrivee?.stationNom ?? 'Station inconnue',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                        if (chargeArrivee?.jaugeDebut != null)
                          Text(
                            '${chargeArrivee!.jaugeDebut.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    '${trajet.qtEnergiePercent.toStringAsFixed(0)}%',
                    'Énergie',
                    Icons.battery_charging_full,
                  ),
                  if (distance != null)
                    _buildStat(
                      '${distance.toStringAsFixed(0)} km',
                      'Distance',
                      Icons.route,
                    ),
                  if (consoAu100 != null)
                    _buildStat(
                      '${consoAu100.toStringAsFixed(1)}',
                      'kWh/100km',
                      Icons.eco,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
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
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showTrajetDetails(Trajet trajet) {
    Charge? chargeDepart;
    Charge? chargeArrivee;
  
    if (trajet.rechargeDepart != null) {
      chargeDepart = _getChargeById(trajet.rechargeDepart!);
    }
    if (trajet.rechargeArrivee != null) {
      chargeArrivee = _getChargeById(trajet.rechargeArrivee!);
    }
    
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
                        Icons.route,
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
                            DateFormat('dd MMMM yyyy', 'fr_FR').format(trajet.date),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trajet #${trajet.id}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Détails
                const Text(
                  'Départ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (chargeDepart != null) ...[
                  Text('Station : ${chargeDepart.stationNom ?? "Inconnue"}'),
                  Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(chargeDepart.horodatage)}'),
                  Text('Niveau batterie : ${chargeDepart.jaugeFin.toStringAsFixed(0)}%'),
                  if (chargeDepart.kilometrage != null)
                    Text('Kilométrage : ${chargeDepart.kilometrage!.toStringAsFixed(0)} km'),
                ],

                const SizedBox(height: 24),

                const Text(
                  'Arrivée',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (chargeArrivee != null) ...[
                  Text('Station : ${chargeArrivee.stationNom ?? "Inconnue"}'),
                  Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(chargeArrivee.horodatage)}'),
                  Text('Niveau batterie : ${chargeArrivee.jaugeDebut.toStringAsFixed(0)}%'),
                  if (chargeArrivee.kilometrage != null)
                    Text('Kilométrage : ${chargeArrivee.kilometrage!.toStringAsFixed(0)} km'),
                ],

                const SizedBox(height: 24),

                const Text(
                  'Trajet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Énergie consommée : ${trajet.qtEnergiePercent.toStringAsFixed(1)}%'),
                
                const SizedBox(height: 24),

                // Bouton supprimer
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteTrajet(trajet);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('SUPPRIMER'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createTrajet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrajetFormScreen(),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteTrajet(Trajet trajet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce trajet ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteTrajet(trajet.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trajet supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}
