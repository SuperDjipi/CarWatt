import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/charge.dart';
import 'package:carwatt/presentation/screens/charge_form_screen.dart';
import 'package:intl/intl.dart';

class ChargesListScreen extends StatefulWidget {
  final int? initialStationFilter;
  
  const ChargesListScreen({
    super.key,
    this.initialStationFilter,
  });

  @override
  State<ChargesListScreen> createState() => _ChargesListScreenState();
}

class _ChargesListScreenState extends State<ChargesListScreen> {
  final _db = DatabaseHelper.instance;
  List<Charge> _charges = [];
  List<Charge> _filteredCharges = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'date_desc'; // date_desc, date_asc, montant_desc, montant_asc
  int? _stationFilter; 
  bool _showDraftsOnly = false;

  @override
  void initState() {
    super.initState();
    _stationFilter = widget.initialStationFilter; // Initialiser le filtre
    _loadCharges();
  }

  Future<void> _loadCharges() async {
    setState(() => _isLoading = true);
    
    try {
      final charges = await _db.getCharges();
      setState(() {
        _charges = charges;
        _filteredCharges = charges;
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

  void _applyFilters() {
    setState(() {
      _filteredCharges = _charges.where((charge) {

        // Filtre par statut (brouillons seulement)
        if (_showDraftsOnly && !charge.isDraft) {
          return false;
        }
        // Filtre par station
        if (_stationFilter != null && charge.stationId != _stationFilter) {
          return false;
        }
        
        if (_searchQuery.isEmpty) return true;
        
        final query = _searchQuery.toLowerCase();
        final stationName = charge.stationNom?.toLowerCase() ?? '';
        final dateStr = DateFormat('dd/MM/yyyy').format(charge.horodatage).toLowerCase();
        
        return stationName.contains(query) || dateStr.contains(query);
      }).toList();

      // Tri
      switch (_sortBy) {
        case 'date_desc':
          _filteredCharges.sort((a, b) => b.horodatage.compareTo(a.horodatage));
          break;
        case 'date_asc':
          _filteredCharges.sort((a, b) => a.horodatage.compareTo(b.horodatage));
          break;
        case 'montant_desc':
          _filteredCharges.sort((a, b) => b.paye.compareTo(a.paye));
          break;
        case 'montant_asc':
          _filteredCharges.sort((a, b) => a.paye.compareTo(b.paye));
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
          _buildSortOption('Date (récent → ancien)', 'date_desc', Icons.calendar_today),
          _buildSortOption('Date (ancien → récent)', 'date_asc', Icons.calendar_today),
          _buildSortOption('Montant (élevé → faible)', 'montant_desc', Icons.euro),
          _buildSortOption('Montant (faible → élevé)', 'montant_asc', Icons.euro),
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
        title: const Text('Charges'),
        actions: [
          // Badge avec nombre de brouillons
          if (_charges.where((c) => c.isDraft).isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${_charges.where((c) => c.isDraft).length}'),
                child: Icon(
                  _showDraftsOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _showDraftsOnly ? Colors.orange : null,
                ),
              ),
              onPressed: () {
                setState(() {
                  _showDraftsOnly = !_showDraftsOnly;
                });
                _applyFilters();
              },
              tooltip: _showDraftsOnly ? 'Afficher tout' : 'Afficher brouillons uniquement',
            ),
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
                hintText: 'Rechercher une station ou une date...',
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

          // Liste des charges
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCharges.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.battery_charging_full,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucune charge enregistrée'
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
                        onRefresh: _loadCharges,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredCharges.length,
                          itemBuilder: (context, index) {
                            final charge = _filteredCharges[index];
                            return _buildChargeCard(charge);
                          },
                        ),
                      ),
          ),
        ],
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
            _loadCharges(); // Recharger la liste
          }
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChargeCard(Charge charge) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: charge.isDraft ? Colors.orange[200]! : Colors.grey[200]!,
          width: charge.isDraft ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showChargeDetails(charge);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge brouillon si nécessaire
              if (charge.isDraft)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Brouillon - À compléter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              // En-tête : date + montant
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(charge.horodatage),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeFormat.format(charge.horodatage),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),                  
                  if (!charge.isDraft || charge.paye > 0)
                    Text(
                      '${charge.paye.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: charge.isDraft ? Colors.orange : Colors.green,
                      ),
                    ),
                ],
              ),
              
              // Station
              if (charge.stationNom != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        charge.stationNom!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Infos principales
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStat(
                      '${charge.nbKwh.toStringAsFixed(1)} kWh',
                      'Énergie',
                      Icons.bolt_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildQuickStat(
                      '${charge.jaugeDebut.toStringAsFixed(0)}% → ${charge.jaugeFin.toStringAsFixed(0)}%',
                      'Jauge',
                      Icons.battery_charging_full,
                    ),
                  ),
                  if (charge.distance != null)
                    Expanded(
                      child: _buildQuickStat(
                        '${charge.distance!.toStringAsFixed(0)} km',
                        'Distance',
                        Icons.route,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String value, String label, IconData icon) {
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

  void _showChargeDetails(Charge charge) {
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
                        Icons.bolt,
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
                            DateFormat('dd MMMM yyyy', 'fr_FR').format(charge.horodatage),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(charge.horodatage),
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

                if (charge.stationNom != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          charge.stationNom!,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Détails de la charge
                const Text(
                  'Détails de la charge',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _buildDetailRow('Montant payé', '${charge.paye.toStringAsFixed(2)} €'),
                _buildDetailRow('Énergie', '${charge.nbKwh.toStringAsFixed(2)} kWh'),
                if (charge.prixAuKwh != null)
                  _buildDetailRow('Prix au kWh', '${charge.prixAuKwh!.toStringAsFixed(3)} €/kWh'),
                _buildDetailRow('Jauge début', '${charge.jaugeDebut.toStringAsFixed(0)} %'),
                _buildDetailRow('Jauge fin', '${charge.jaugeFin.toStringAsFixed(0)} %'),
                if (charge.chargePertesPct != null)
                  _buildDetailRow('Pertes à la charge', '${charge.chargePertesPct!.toStringAsFixed(1)} %'),

                if (charge.kilometrage != null || charge.distance != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Trajet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (charge.kilometrage != null)
                  _buildDetailRow('Kilométrage', '${charge.kilometrage!.toStringAsFixed(0)} km'),
                if (charge.distance != null)
                  _buildDetailRow('Distance parcourue', '${charge.distance!.toStringAsFixed(0)} km'),
                if (charge.consoKwhAu100 != null)
                  _buildDetailRow('Consommation', '${charge.consoKwhAu100!.toStringAsFixed(1)} kWh/100km'),

                if (charge.economieTotale != null || charge.economieAu100 != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Économies',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (charge.prixE10 != null)
                  _buildDetailRow('Prix E10 (référence)', '${charge.prixE10!.toStringAsFixed(3)} €/L'),

                if (charge.consoEssence != null)
                  _buildDetailRow('Coût essence équivalent', '${charge.consoEssence!.toStringAsFixed(2)} €'),
                if (charge.economieTotale != null)
                  _buildDetailRow(
                    'Économie totale',
                    '${charge.economieTotale!.toStringAsFixed(2)} €',
                    valueColor: charge.economieTotale! >= 0 ? Colors.green : Colors.red,
                  ),

                if (charge.consoEssence != null)
                  _buildDetailRow('Coût essence équivalent', '${charge.consoEssence!.toStringAsFixed(2)} €'),
                if (charge.economieTotale != null)
                  _buildDetailRow(
                    'Économie totale',
                    '${charge.economieTotale!.toStringAsFixed(2)} €',
                    valueColor: charge.economieTotale! >= 0 ? Colors.green : Colors.red,
                  ),
                if (charge.economieAu100 != null)
                  _buildDetailRow(
                    'Économie au 100 km',
                    '${charge.economieAu100!.toStringAsFixed(2)} €/100km',
                    valueColor: charge.economieAu100! >= 0 ? Colors.green : Colors.red,
                  ),

                const SizedBox(height: 24),

                // bouton modifier
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChargeFormScreen(charge: charge),
                        ),
                      );
                    
                      if (result == true) {
                        _loadCharges();
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('MODIFIER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // FIN DU BOUTON
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Écran de liste filtré par station
class ChargesListScreenFiltered extends StatelessWidget {
  final int stationId;
  
  const ChargesListScreenFiltered({
    super.key,
    required this.stationId,
  });

  @override
  Widget build(BuildContext context) {
    return ChargesListScreen(initialStationFilter: stationId);
  }
}
