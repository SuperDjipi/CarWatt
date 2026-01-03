import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/presentation/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  bool _isLoading = true;
  
  int _totalCharges = 0;
  double _totalPaye = 0;
  double _economieTotale = 0;
  double _consoMoyenne = 0;
  double _distanceTotale = 0;
  Charge? _derniereCharge;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final charges = await _db.getCharges(orderBy: 'horodatage ASC');
      
      if (charges.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      double totalPaye = 0;
      double totalDistance = 0;
      double totalConso = 0;
      int consoCount = 0;

      for (var charge in charges) {
        totalPaye += charge.paye;
        if (charge.distance != null) {
          totalDistance += charge.distance!;
        }
        if (charge.consoKwhAu100 != null && charge.consoKwhAu100! > 0) {
          totalConso += charge.consoKwhAu100!;
          consoCount++;
        }
      }

      setState(() {
        _totalCharges = charges.length;
        _totalPaye = totalPaye;
        _distanceTotale = totalDistance;
        _derniereCharge = charges.last;
        _economieTotale = _derniereCharge?.economieTotale ?? 0;
        _consoMoyenne = consoCount > 0 ? totalConso / consoCount : 0;
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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('CarWatt'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec dernière charge
                    if (_derniereCharge != null) ...[
                      _buildLastChargeCard(),
                      const SizedBox(height: 24),
                    ],

                    // Stats principales
                    const Text(
                      'Vue d\'ensemble',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildStatsGrid(),
                    
                    const SizedBox(height: 24),
                    
                    // Économies
                    _buildEconomyCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLastChargeCard() {
    final charge = _derniereCharge!;
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    
    return Card(
      elevation: 0,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dernière charge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              dateFormat.format(charge.horodatage),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            if (charge.stationNom != null) ...[
              const SizedBox(height: 4),
              Text(
                charge.stationNom!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  '${charge.jaugeDebut.toStringAsFixed(0)}% → ${charge.jaugeFin.toStringAsFixed(0)}%',
                  'Jauge',
                ),
                _buildStatItem(
                  '${charge.nbKwh.toStringAsFixed(1)} kWh',
                  'Énergie',
                ),
                _buildStatItem(
                  '${charge.paye.toStringAsFixed(2)} €',
                  'Coût',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.ev_station,
            value: _totalCharges.toString(),
            label: 'Recharges',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.route,
            value: '${_distanceTotale.toStringAsFixed(0)} km',
            label: 'Distance',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomyCard() {
    return Card(
      elevation: 0,
      color: _economieTotale >= 0 ? Colors.green[50] : Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _economieTotale >= 0 ? Colors.green[200]! : Colors.red[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _economieTotale >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: _economieTotale >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Économie vs essence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_economieTotale.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _economieTotale >= 0 ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total économisé',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_consoMoyenne.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conso moy. / 100km',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    '${_totalPaye.toStringAsFixed(2)} €',
                    'Coût total électricité',
                  ),
                  _buildStatItem(
                    '${(_totalPaye / _distanceTotale * 100).toStringAsFixed(2)} €',
                    'Coût / 100km',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
