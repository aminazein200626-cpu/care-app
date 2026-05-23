import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/client_api_service.dart';

class Dependant {
  final String id;
  final String name;
  final String relationship;
  final DateTime? dateOfBirth;
  final String nationalId;
  final String avatar;
  final String notes;
  final List<Map<String, dynamic>> files;

  Dependant({
    required this.id,
    required this.name,
    required this.relationship,
    this.dateOfBirth,
    required this.nationalId,
    required this.avatar,
    required this.notes,
    this.files = const [],
  });

  factory Dependant.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> fileList = [];
    if (json['files'] != null && json['files'] is List) {
      fileList = (json['files'] as List).map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }
    return Dependant(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['fullName'] ?? json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth']) : null,
      nationalId: json['nationalId'] ?? '',
      avatar: json['avatar'] ?? '',
      notes: json['healthNotes'] ?? json['notes'] ?? '',
      files: fileList,
    );
  }

  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  bool get isMinor => age < 15;
}

class DependantsScreen extends StatefulWidget {
  const DependantsScreen({super.key});

  @override
  State<DependantsScreen> createState() => _DependantsScreenState();
}

class _DependantsScreenState extends State<DependantsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final ClientApiService _api = ClientApiService();
  List<Dependant> _dependants = [];
  bool _isLoading = true;

  final Map<String, Color> _relationshipColors = {
    'Daughter': const Color(0xFF8B5CF6),
    'Son': const Color(0xFF3B82F6),
    'Mother': const Color(0xFF0D6E6E),
    'Father': const Color(0xFF059669),
    'Spouse': const Color(0xFFF59E0B),
    'Other': AppTheme.textMuted,
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadDependants();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDependants() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.getDependents();
      setState(() {
        _dependants = data.map((d) => Dependant.fromJson(d)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load dependants: $e');
    }
  }

  void _showAddEditDialog({Dependant? dependant}) {
    final isEditing = dependant != null;
    final nameCtrl = TextEditingController(text: dependant?.name ?? '');
    final relCtrl = TextEditingController(text: dependant?.relationship ?? '');
    final notesCtrl = TextEditingController(text: dependant?.notes ?? '');
    final nationalIdCtrl = TextEditingController(text: dependant?.nationalId ?? '');
    DateTime? selectedDate = dependant?.dateOfBirth;
    bool isMinor = dependant?.isMinor ?? false;
    List<XFile> selectedFiles = [];

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> _pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 10)),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: AppTheme.primary),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setModalState(() {
                selectedDate = picked;
                final tempAge = DateTime.now().year - picked.year;
                isMinor = tempAge < 15;
                if (isMinor) nationalIdCtrl.clear();
              });
            }
          }

          Future<void> _pickFiles() async {
            final picker = ImagePicker();
            final files = await picker.pickMultiImage();
            if (files.isNotEmpty) {
              setModalState(() {
                selectedFiles.addAll(files);
              });
            }
          }

          void _removeFile(int index) {
            setModalState(() {
              selectedFiles.removeAt(index);
            });
          }

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEditing ? 'Update Dependant' : 'Add Dependant',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sheetField('Full Name', nameCtrl, Icons.person_outline_rounded),
                    const SizedBox(height: 14),
                    _sheetField('Relationship', relCtrl, Icons.family_restroom_rounded),
                    const SizedBox(height: 14),
                    _buildDateField(selectedDate, _pickDate),
                    const SizedBox(height: 14),
                    _buildNationalIdField(nationalIdCtrl, isMinor),
                    const SizedBox(height: 14),
                    _sheetField('Health Notes', notesCtrl, Icons.note_outlined, required: false),
                    const SizedBox(height: 14),
                    _buildFilesSection(selectedFiles, _pickFiles, _removeFile),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (selectedDate == null) {
                            _showError('Please select date of birth');
                            return;
                          }
                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);
                          try {
                            final dependantData = {
                              'fullName': nameCtrl.text,
                              'relationship': relCtrl.text,
                              'dateOfBirth': DateFormat('yyyy-MM-dd').format(selectedDate!),
                              'nationalId': nationalIdCtrl.text,
                              'healthNotes': notesCtrl.text,
                            };
                            final fileList = selectedFiles.map((f) => File(f.path)).toList();
                            if (isEditing) {
                              // Update logic can be added here later
                            } else {
                              await _api.addDependent(dependantData, files: fileList);
                            }
                            await _loadDependants();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? 'Dependant updated!' : 'Dependant added!'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => _isLoading = false);
                            _showError('Failed to save dependant: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Add Dependant',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateField(DateTime? selectedDate, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date of Birth', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(selectedDate)
                        : 'Select date of birth',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: selectedDate != null ? AppTheme.textPrimary : AppTheme.textMuted,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, color: AppTheme.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNationalIdField(TextEditingController controller, bool isMinor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('National ID', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            if (isMinor)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Optional for minors', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.warning)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textMuted, size: 20),
            hintText: 'Enter national ID number',
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (value) {
            if (!isMinor && (value == null || value.isEmpty)) {
              return 'National ID is required for ages 15+';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFilesSection(List<XFile> files, VoidCallback onAdd, Function(int) onRemove) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medical Files (Optional)', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...files.asMap().entries.map((entry) {
              int idx = entry.key;
              XFile file = entry.value;
              return Chip(
                label: Text(file.name.length > 20 ? '${file.name.substring(0, 20)}...' : file.name, style: const TextStyle(fontSize: 12)),
                onDeleted: () => onRemove(idx),
                deleteIcon: const Icon(Icons.close, size: 16),
                avatar: const Icon(Icons.insert_drive_file, size: 16),
              );
            }),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text('Add File', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmDelete(Dependant dependant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${dependant.name}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove this dependant?', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _api.deleteDependent(dependant.id);
                await _loadDependants();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dependant removed'), backgroundColor: AppTheme.success),
                  );
                }
              } catch (e) {
                setState(() => _isLoading = false);
                _showError('Failed to remove dependant');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: Text('Remove', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dependants'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _dependants.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _dependants.length,
                    itemBuilder: (context, i) => _buildDependantCard(_dependants[i]),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Dependant', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildDependantCard(Dependant dep) {
    final color = _relationshipColors[dep.relationship] ?? AppTheme.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ClipOval(
                  child: dep.avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: dep.avatar,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            color: color.withAlpha(30),
                            child: Icon(Icons.person_rounded, color: color, size: 26),
                          ),
                        )
                      : Container(
                          width: 52,
                          height: 52,
                          color: color.withAlpha(30),
                          child: Icon(Icons.person_rounded, color: color, size: 26),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dep.name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                            child: Text(dep.relationship, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                          ),
                          const SizedBox(width: 8),
                          Text('${dep.age} years old', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textMuted)),
                          if (dep.isMinor)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.warning.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                              child: Text('Minor', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.warning)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                      onPressed: () => _showAddEditDialog(dependant: dep),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                      onPressed: () => _confirmDelete(dep),
                    ),
                  ],
                ),
              ],
            ),
            if (dep.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.warning.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(child: Text(dep.notes, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            ],
            if (dep.files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: dep.files.map((fileMap) {
                  final filename = fileMap['filename'] ?? 'file';
                  return Chip(
                    label: Text(filename, style: const TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.attachment, size: 14),
                    onDeleted: () {}, // File deletion can be added later
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: AppTheme.primaryContainer.withAlpha(80), shape: BoxShape.circle),
            child: const Icon(Icons.family_restroom_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text('No Dependants Added', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('Add family members who depend on\nyour care services.', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, IconData icon, {bool required = true}) {
    return TextFormField(
      controller: ctrl,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }
}