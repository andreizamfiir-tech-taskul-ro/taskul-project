import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';
import '../state/auth_state.dart';
import 'task_detail_page.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  int? _cityId;
  int? _countyId;
  int? _countryId;
  String _category = 'Curatenie';
  LatLng _pin = const LatLng(44.4268, 26.1025);
  bool _isSubmitting = false;
  bool _isGeocoding = false;
  Timer? _geocodeDebounce;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final user = AuthState.instance.user;
    if (user != null) {
      _contactNameCtrl.text = user.name;
      _emailCtrl.text = user.email;
      if ((user.phone ?? '').isNotEmpty) {
        _phoneCtrl.text = user.phone!;
      }
    }
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _contactNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);

    Widget sectionCard({required String title, required List<Widget> children}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
    }

    InputDecoration fieldDecoration(String label) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E6F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue),
        ),
      );
    }

    final detailsCard = sectionCard(
      title: 'Detalii task',
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: fieldDecoration('Titlu* (min 16 caractere)').copyWith(
            hintText: 'ex: Reparatie instalatie electrica',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: fieldDecoration('Categorie*'),
          items: const [
            DropdownMenuItem(value: 'Curatenie', child: Text('Curatenie')),
            DropdownMenuItem(value: 'Reparatii', child: Text('Reparatii')),
            DropdownMenuItem(value: 'Livrare', child: Text('Livrare')),
            DropdownMenuItem(value: 'IT', child: Text('IT / Software')),
          ],
          onChanged: (val) => setState(() => _category = val ?? _category),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: fieldDecoration('Buget estimat (RON)').copyWith(
            hintText: 'ex: 350',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          minLines: 4,
          maxLines: 6,
          decoration: fieldDecoration('Descriere*').copyWith(
            hintText: 'Spune ce trebuie facut, materiale, deadline etc.',
          ),
        ),
      ],
    );

    final contactCard = sectionCard(
      title: 'Date de contact',
      children: [
        TextField(
          controller: _contactNameCtrl,
          decoration: fieldDecoration('Persoana de contact*'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          decoration: fieldDecoration('Email*'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: fieldDecoration('Numar de telefon*'),
        ),
      ],
    );

    final locationCard = sectionCard(
      title: 'Locatie',
      children: [
        TextField(
          controller: _cityCtrl,
          onChanged: _onAddressChanged,
          decoration: fieldDecoration('Localitate*').copyWith(
            hintText: 'ex: Bucuresti, Sectorul 3',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressCtrl,
          onChanged: _onAddressChanged,
          decoration: fieldDecoration('Adresa completa').copyWith(
            hintText: 'Strada Exemplu nr. 10, bl. X, ap. 5',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E6F0)),
            color: const Color(0xFFF7F9FC),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pin,
                initialZoom: 13,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _pin = latLng;
                  });
                  _reverseGeocode(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.taskul.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Color(0xFF0040FF), size: 38),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_isGeocoding)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_isGeocoding) const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Apasa pe harta pentru a muta pin-ul sau completeaza adresa pentru a-l pozitiona automat.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );

    final actionsRow = Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _preview,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: primaryBlue),
            ),
            child: Text(
              'Previzualizeaza',
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Publica task'),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Creeaza un task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Publica un task nou',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Completeaza detaliile, alege categoria si publica. Poti edita oricand ulterior.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                detailsCard,
                const SizedBox(height: 12),
                contactCard,
                const SizedBox(height: 12),
                locationCard,
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: actionsRow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final auth = AuthState.instance;
    if (!auth.isAuthenticated || auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autentificati-va pentru a crea un task')),
      );
      return;
    }
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titlul este obligatoriu')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final price = double.tryParse(_priceCtrl.text.trim());
      await createTaskApi(
        title: title,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        creatorId: auth.user!.id,
        price: price,
        lat: _pin.latitude,
        lng: _pin.longitude,
        estimatedDurationMinutes: null,
        startTime: DateTime.now(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        cityId: _cityId,
        countyId: _countyId,
        countryId: _countryId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task creat')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _preview() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titlul este obligatoriu')),
      );
      return;
    }

    final auth = AuthState.instance;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final address = _buildAddress();
    final locationLabel = _buildLocationLabel(address);
    final conciseAddress = _buildConciseAddress(address, locationLabel);
    final shortAddress = conciseAddress;
    final creatorName = _contactNameCtrl.text.trim().isNotEmpty
        ? _contactNameCtrl.text.trim()
        : (auth.user?.name ?? 'Tu');

    final task = Task(
      id: 0,
      creatorId: auth.user?.id ?? 0,
      creatorName: creatorName,
      title: title,
      price: price,
      startTime: DateTime.now(),
      statusLabel: 'Previzualizare',
      statusId: 0,
      lat: _pin.latitude,
      lng: _pin.longitude,
      address: address,
      locationLabel: locationLabel,
      conciseAddress: conciseAddress,
      shortAddress: shortAddress,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(task: task, isPreview: true),
      ),
    );
  }

  void _onAddressChanged(String _) {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 800), () {
      _forwardGeocode();
    });
  }

  String _buildAddress() {
    final city = _cityCtrl.text.trim();
    final addr = _addressCtrl.text.trim();
    final parts = [addr, city].where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Adresa nespecificata';
    return parts.join(', ');
  }

  String _buildLocationLabel(String address) {
    if (address == 'Adresa nespecificata') return 'Romania';
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}, ${parts.last}';
    }
    return parts.isNotEmpty ? parts.first : 'Romania';
  }

  String _buildConciseAddress(String address, String fallback) {
    if (address == 'Adresa nespecificata') return fallback;
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fallback;
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return parts.first;
  }

  Future<void> _forwardGeocode() async {
    final city = _cityCtrl.text.trim();
    final addr = _addressCtrl.text.trim();
    if (city.isEmpty && addr.isEmpty) return;

    setState(() => _isGeocoding = true);
    try {
      final query = [addr, city].where((e) => e.isNotEmpty).join(', ');
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'taskul-app/1.0'},
      );
      if (res.statusCode != 200) {
        throw Exception('Geocodare esuata (${res.statusCode})');
      }
      final List data = jsonDecode(res.body);
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nu am gasit locatia pentru adresa.')),
          );
        }
        return;
      }
      final lat = double.tryParse(data.first['lat']?.toString() ?? '');
      final lon = double.tryParse(data.first['lon']?.toString() ?? '');
      if (lat == null || lon == null) {
        return;
      }
      final newPin = LatLng(lat, lon);
      if (mounted) {
        setState(() => _pin = newPin);
        _mapController.move(newPin, 14);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu am putut plasa pin-ul pentru adresa.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'taskul-app/1.0'},
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final addr = data['address'] as Map<String, dynamic>?;
      final display = data['display_name']?.toString();

      String street = '';
      if (addr != null) {
        final road = addr['road']?.toString() ?? '';
        final house = addr['house_number']?.toString() ?? '';
        if (road.isNotEmpty || house.isNotEmpty) {
          street = [road, house].where((e) => e.isNotEmpty).join(' ');
        }
      }
      final cityCandidate = addr?['city']?.toString() ??
          addr?['town']?.toString() ??
          addr?['village']?.toString() ??
          addr?['municipality']?.toString() ??
          addr?['county']?.toString() ??
          '';
      final state = addr?['state']?.toString() ?? '';
      final postcode = addr?['postcode']?.toString() ?? '';
      final country = addr?['country']?.toString() ?? '';

      final fullAddressParts = [
        if (street.isNotEmpty) street,
        if (cityCandidate.isNotEmpty) cityCandidate,
        if (state.isNotEmpty) state,
        if (postcode.isNotEmpty) postcode,
        if (country.isNotEmpty) country,
      ];
      final fullAddress = fullAddressParts.isNotEmpty
          ? fullAddressParts.join(', ')
          : (display ?? '');

      if (mounted) {
        _addressCtrl.text = fullAddress;
        if (cityCandidate.isNotEmpty) {
          _cityCtrl.text = cityCandidate;
        }
      }
    } catch (_) {
      // swallow errors silently for reverse geocode
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }
}
