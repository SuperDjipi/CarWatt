import 'package:flutter/material.dart';
import 'package:carwatt/data/database/database_helper.dart';
import 'package:carwatt/data/models/station.dart';
import 'package:carwatt/presentation/screens/map_picker_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class StationFormScreen extends StatefulWidget {
  final Station? station; // null = nouvelle station, sinon édition
  
  const StationFormScreen({
    super.key,
    this.station,
  });

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;
  
  // Contrôleurs
  late TextEditingController _nomController;
  late TextEditingController _adresseController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  
  // État
  bool _isSaving = false;
  bool _isLoadingPosition = false;
  List<String> _reseaux = [];
  final TextEditingController _reseauController = TextEditingController();
  
  // Réseaux prédéfinis
  final List<String> _reseauxPredefined = [
    'Maison',
    'Tesla',
    'Ionity',
    'Izivia',
    'TotalEnergies',
    'Electra',
    'Fastned',
    'Allego',
    'Reveo',
    'Indigo',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.station != null) {
      // Mode édition
      final station = widget.station!;
      _nomController = TextEditingController(text: station.nom);
      _adresseController = TextEditingController(text: station.adresse ?? '');
      _latitudeController = TextEditingController(
        text: station.positionGps?.latitude.toString() ?? '',
      );
      _longitudeController = TextEditingController(
        text: station.positionGps?.longitude.toString() ?? '',
      );
      _reseaux = List.from(station.reseaux);
    } else {
      // Mode création
      _nomController = TextEditingController();
      _adresseController = TextEditingController();
      _latitudeController = TextEditingController();
      _longitudeController = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.station == null ? 'Nouvelle station' : 'Modifier la station'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nom
            const Text(
              'Informations générales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomController,
              decoration: InputDecoration(
                labelText: 'Nom de la station *',
                hintText: 'Ex: Tesla Supercharger Aix',
                prefixIcon: const Icon(Icons.ev_station),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Le nom est requis' : null,
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _adresseController,
              decoration: InputDecoration(
                labelText: 'Adresse',
                hintText: 'Ex: 1 Avenue de la Gare, 13100 Aix',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            // Réseaux
            const Text(
              'Réseau(x)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Chips des réseaux sélectionnés
            if (_reseaux.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reseaux.map((reseau) {
                  return Chip(
                    label: Text(reseau),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _reseaux.remove(reseau);
                      });
                    },
                    backgroundColor: Colors.green[50],
                    side: BorderSide(color: Colors.green[200]!),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            
            // Bouton ajouter réseau
            OutlinedButton.icon(
              onPressed: _showAddReseauDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un réseau'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
              ),
            ),

            const SizedBox(height: 24),

            // Position GPS
            const Text(
              'Position GPS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optionnel - Permet de localiser la station sur la carte',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      hintText: '43.5297',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return null;
                      final val = double.tryParse(value!.replaceAll(',', '.'));
                      if (val == null || val < -90 || val > 90) {
                        return 'Invalide';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      hintText: '5.4474',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return null;
                      final val = double.tryParse(value!.replaceAll(',', '.'));
                      if (val == null || val < -180 || val > 180) {
                        return 'Invalide';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingPosition ? null : _getCurrentPosition,
                    icon: _isLoadingPosition
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Ma position'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPositionOnMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Choisir sur carte'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Bouton enregistrer
            ElevatedButton(
              onPressed: _isSaving ? null : _saveStation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.station == null ? 'CRÉER LA STATION' : 'MODIFIER',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            if (widget.station != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _deleteStation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('SUPPRIMER LA STATION'),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAddReseauDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un réseau'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Réseaux courants :'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reseauxPredefined.map((reseau) {
                final isSelected = _reseaux.contains(reseau);
                return FilterChip(
                  label: Text(reseau),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!_reseaux.contains(reseau)) {
                          _reseaux.add(reseau);
                        }
                      } else {
                        _reseaux.remove(reseau);
                      }
                    });
                    Navigator.pop(context);
                  },
                  selectedColor: Colors.green[100],
                  checkmarkColor: Colors.green,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Ou entrez un nom personnalisé :'),
            const SizedBox(height: 8),
            TextField(
              controller: _reseauController,
              decoration: const InputDecoration(
                hintText: 'Nom du réseau',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.isNotEmpty && !_reseaux.contains(value)) {
                  setState(() {
                    _reseaux.add(value);
                  });
                  _reseauController.clear();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final value = _reseauController.text.trim();
              if (value.isNotEmpty && !_reseaux.contains(value)) {
                setState(() {
                  _reseaux.add(value);
                });
                _reseauController.clear();
              }
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
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
        setState(() {
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
          _isLoadingPosition = false;
        });
      } else {
        setState(() => _isLoadingPosition = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission de géolocalisation refusée'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingPosition = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _saveStation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_reseaux.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un réseau')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      LatLng? position;
      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty) {
        position = LatLng(
          double.parse(_latitudeController.text.replaceAll(',', '.')),
          double.parse(_longitudeController.text.replaceAll(',', '.')),
        );
      }

      final station = Station(
        id: widget.station?.id,
        nom: _nomController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty
            ? null
            : _adresseController.text.trim(),
        positionGps: position,
        reseaux: _reseaux,
      );

      if (widget.station == null) {
        await _db.insertStation(station);
      } else {
        await _db.updateStation(station);
      }

      if (mounted) {
        Navigator.pop(context, station); // Retourner la station créée/modifiée
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _pickPositionOnMap() async {
    // Position initiale : soit celle déjà saisie, soit null
    LatLng? initialPosition;
    if (_latitudeController.text.isNotEmpty && 
        _longitudeController.text.isNotEmpty) {
      try {
        initialPosition = LatLng(
          double.parse(_latitudeController.text.replaceAll(',', '.')),
          double.parse(_longitudeController.text.replaceAll(',', '.')),
        );
      } catch (e) {
        // Position invalide, on laisse null
      }
    }

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialPosition: initialPosition),
      ),
    );

    if (result != null) {
      setState(() {
        _latitudeController.text = result.position.latitude.toStringAsFixed(6);
        _longitudeController.text = result.position.longitude.toStringAsFixed(6);
        
        // Remplir l'adresse si elle est disponible et que le champ est vide
        if (result.address != null && _adresseController.text.isEmpty) {
          _adresseController.text = result.address!;
        }
      });
    }
  }

  Future<void> _deleteStation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette station ?'),
        content: const Text(
          'Les charges associées à cette station ne seront pas supprimées.',
        ),
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

    if (confirmed == true && widget.station != null) {
      try {
        await _db.deleteStation(widget.station!.id!);
        if (mounted) {
          Navigator.pop(context, null); // null = station supprimée
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

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _reseauController.dispose();
    super.dispose();
  }
}
