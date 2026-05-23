import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../services/client_api_service.dart';

class SelectDependantScreen extends StatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceName;
  final double hourlyRate; // ✅ جديد: السعر لكل ساعة

  const SelectDependantScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceName,
    required this.hourlyRate, // ✅ مطلوب
  });

  @override
  State<SelectDependantScreen> createState() => _SelectDependantScreenState();
}

class _SelectDependantScreenState extends State<SelectDependantScreen> {
  final ClientApiService _api = ClientApiService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _dependants = [];
  String? _selectedDependantId;
  String? _selectedDependantName;

  @override
  void initState() {
    super.initState();
    _loadDependants();
  }

  Future<void> _loadDependants() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getDependents();
      setState(() {
        _dependants = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dependants: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _goToAvailability() {
    if (_selectedDependantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/client/availability',
      arguments: {
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'serviceName': widget.serviceName,
        'hourlyRate': widget.hourlyRate, // ✅ تمرير السعر
        'dependantId': _selectedDependantId,
        'dependantName': _selectedDependantName,
      },
    );
  }

  void _addNewDependant() {
    Navigator.pushNamed(context, '/client/dependents').then((_) {
      _loadDependants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Select Person'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _dependants.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _dependants.length,
                          itemBuilder: (context, index) {
                            final dep = _dependants[index];
                            final isSelected = _selectedDependantId == dep['_id'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDependantId = dep['_id'];
                                  _selectedDependantName = dep['fullName'];
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                                      child: Icon(Icons.person, color: AppTheme.primary),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(dep['fullName'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          Text(dep['relationship'] ?? 'Family', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle, color: AppTheme.primary),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addNewDependant,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Person'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _goToAvailability,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No persons added', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Add your family members who need care.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addNewDependant,
            icon: const Icon(Icons.add),
            label: const Text('Add Person'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}