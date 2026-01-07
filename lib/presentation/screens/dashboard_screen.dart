import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/presentation/screens/charge_form_screen.dart';
import 'package:carwatt/presentation/widgets/app_drawer.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper.instance;
  
  Charge? _lastCharge;
  List<Charge> _charges = [];
  List<Station> _stations = [];
  int _totalCharges = 0;
  double _totalDistance = 0;
  double _totalEconomies = 0;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      // Charger toutes les charges (complètes seulement)
      final allCharges = await _db.getCharges(orderBy: 'horodatage DESC');
      final charges = allCharges.where((c) => c.statut == StatutCharge.complete).toList();
      
      // Charger les stations
      final stations = await _db.getStations();

      double totalDist = 0;
      for (var charge in charges) {
        if (charge.distance != null) {
          totalDist += charge.distance!;
        }
      }

      setState(() {
        _charges = charges;
        _stations = stations;
        _lastCharge = charges.isNotEmpty ? charges.first : null;
        _totalCharges = charges.length;
        _totalDistance = totalDist;
        _totalEconomies = _lastCharge?.economieTotale ?? 0;
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
    super.build(context);
    
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Dernière charge
                  if (_lastCharge != null) _buildLastChargeCard(),
                  
                  const SizedBox(height: 16),

                  // Statistiques globales
                  const Text(
                    'Statistiques globales',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildStatsCard(
                    icon: Icons.bolt,
                    iconColor: Colors.orange,
                    title: 'Nombre de charges',
                    value: _totalCharges.toString(),
                  ),
                  const SizedBox(height: 12),

                  _buildStatsCard(
                    icon: Icons.route,
                    iconColor: Colors.blue,
                    title: 'Distance totale',
                    value: '${_totalDistance.toStringAsFixed(0)} km',
                  ),
                  const SizedBox(height: 12),

                  _buildStatsCard(
                    icon: Icons.savings,
                    iconColor: Colors.green,
                    title: 'Économies cumulées',
                    value: '${_totalEconomies.toStringAsFixed(2)} €',
                  ),

                  const SizedBox(height: 24),

                  // Graphiques
                  const Text(
                    'Graphiques',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Graphique 1 : Évolution consommation
                  if (_charges.length >= 3)
                    _buildConsommationChart(),

                  const SizedBox(height: 16),

                  // Graphique 2 : Répartition par réseau
                  if (_charges.isNotEmpty && _stations.isNotEmpty)
                    _buildReseauPieChart(),

                  const SizedBox(height: 16),

                  // Graphique 3 : Économies cumulées
                  if (_charges.length >= 3)
                    _buildEconomiesChart(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChargeFormScreen(),
            ),
          );
          if (result == true) {
            _loadStats();
          }
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLastChargeCard() {
    final charge = _lastCharge!;
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green[200]!),
      ),
      color: Colors.green[50],
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
                    Icons.bolt,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Dernière charge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (charge.stationNom != null) ...[
              Text(
                charge.stationNom!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            
            Text(
              dateFormat.format(charge.horodatage),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSmallStat(
                  '${charge.nbKwh.toStringAsFixed(1)} kWh',
                  'Énergie',
                  Icons.battery_charging_full,
                ),
                _buildSmallStat(
                  '${charge.paye.toStringAsFixed(2)} €',
                  'Coût',
                  Icons.euro,
                ),
                if (charge.consoKwhAu100 != null)
                  _buildSmallStat(
                    '${charge.consoKwhAu100!.toStringAsFixed(1)}',
                    'kWh/100km',
                    Icons.speed,
                  ),
              ],
            ),
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

  Widget _buildSmallStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.green[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
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

  // Graphique : Évolution de la consommation (kWh/100km)
  Widget _buildConsommationChart() {
    final lastCharges = _charges.take(10).toList().reversed.toList();
    final validCharges = lastCharges
        .where((c) => c.consoKwhAu100 != null && c.consoKwhAu100! > 0)
        .toList();
    
    if (validCharges.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < validCharges.length; i++) {
      spots.add(FlSpot(i.toDouble(), validCharges[i].consoKwhAu100!));
    }

    // Calculer min/max pour l'axe Y
    final consoValues = validCharges.map((c) => c.consoKwhAu100!).toList();
    final minConso = consoValues.reduce((a, b) => a < b ? a : b);
    final maxConso = consoValues.reduce((a, b) => a > b ? a : b);
    final range = maxConso - minConso;
    final yMin = (minConso - range * 0.2).clamp(0.0, double.infinity).toDouble();
    final yMax = maxConso + range * 0.2;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Évolution de la consommation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${validCharges.length} dernières charges',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (yMax - yMin) / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= validCharges.length) {
                            return const SizedBox.shrink();
                          }
                          final charge = validCharges[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('dd/MM').format(charge.horodatage),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (validCharges.length - 1).toDouble(),
                  minY: yMin,
                  maxY: yMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.blue,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final charge = validCharges[spot.x.toInt()];
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} kWh/100km\n${DateFormat('dd/MM/yyyy').format(charge.horodatage)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'kWh/100km',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Graphique : Répartition par réseau (camembert)
  Widget _buildReseauPieChart() {
    final reseauStats = <String, int>{};
    
    for (var charge in _charges) {
      if (charge.stationId == null) continue;
      
      final station = _stations.firstWhere(
        (s) => s.id == charge.stationId,
        orElse: () => Station(nom: 'Inconnue', reseaux: ['Autre']),
      );
      
      final reseau = station.reseaux.isNotEmpty ? station.reseaux.first : 'Autre';
      reseauStats[reseau] = (reseauStats[reseau] ?? 0) + 1;
    }
    
    if (reseauStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];

    final sections = <PieChartSectionData>[];
    int colorIndex = 0;
    
    reseauStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..forEach((entry) {
        final percentage = (entry.value / _charges.length * 100);
        sections.add(
          PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${percentage.toStringAsFixed(0)}%',
            color: colors[colorIndex % colors.length],
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Répartition par réseau',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Légende
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: () {
                final sorted = reseauStats.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

                return sorted.asMap().entries.map((entry) {
                  final colorIndex = entry.key;
                  final reseau = entry.value.key;
                  final count = entry.value.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: colors[colorIndex % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$reseau ($count)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                }).toList();
              }(),          
            ),
          ],
        ),
      ),
    );
  }

  // Graphique : Économies cumulées
  Widget _buildEconomiesChart() {
    final chargesWithEco = _charges
        .where((c) => c.economieTotale != null)
        .toList()
        .reversed
        .toList();
    
    if (chargesWithEco.length < 3) {
      return const SizedBox.shrink();
    }

    // Prendre max 20 points pour lisibilité
    final step = (chargesWithEco.length / 20).ceil();
    final displayCharges = <Charge>[];
    for (int i = 0; i < chargesWithEco.length; i += step) {
      displayCharges.add(chargesWithEco[i]);
    }

    if (displayCharges.last.id != chargesWithEco.last.id) {
      displayCharges.add(chargesWithEco.last);
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < displayCharges.length; i++) {
      spots.add(FlSpot(i.toDouble(), displayCharges[i].economieTotale!));
    }

    final maxEco = chargesWithEco.map((c) => c.economieTotale!).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Économies cumulées',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}€',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: (displayCharges.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= displayCharges.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MM/yy').format(displayCharges[index].horodatage),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (displayCharges.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxEco * 1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final charge = displayCharges[spot.x.toInt()];
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(0)}€\n${DateFormat('dd/MM/yyyy').format(charge.horodatage)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}