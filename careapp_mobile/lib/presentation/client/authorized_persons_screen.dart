// lib/screens/client/authorized_persons_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/app_theme.dart';
import '../../services/client_api_service.dart';

class AuthorizedPerson {
  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final String nationalId;
  final String avatar;
  final bool isActive;
  final bool canTrack;
  final bool canChat;
  final bool canViewLocation;
  final DateTime? invitedAt;

  AuthorizedPerson({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.nationalId,
    required this.avatar,
    required this.isActive,
    this.canTrack = true,
    this.canChat = true,
    this.canViewLocation = true,
    this.invitedAt,
  });

  factory AuthorizedPerson.fromJson(Map<String, dynamic> json) {
    return AuthorizedPerson(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['fullName'] ?? json['name'] ?? '',
      relationship: json['relationship'] ?? '',
      phone: json['phoneNumber'] ?? '',
      email: json['email'] ?? '',
      nationalId: json['nationalId'] ?? '',
      avatar: json['profilePicture'] ?? json['avatar'] ?? '',
      isActive: json['isActive'] ?? true,
      canTrack: json['canTrack'] ?? true,
      canChat: json['canChat'] ?? true,
      canViewLocation: json['canViewLocation'] ?? true,
      invitedAt: json['invitedAt'] != null ? DateTime.parse(json['invitedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': name,
      'email': email,
      'phoneNumber': phone,
      'relationship': relationship,
      'nationalId': nationalId,
      'canTrack': canTrack,
      'canChat': canChat,
      'canViewLocation': canViewLocation,
    };
  }
}

class AuthorizedPersonsScreen extends StatefulWidget {
  const AuthorizedPersonsScreen({super.key});

  @override
  State<AuthorizedPersonsScreen> createState() => _AuthorizedPersonsScreenState();
}

class _AuthorizedPersonsScreenState extends State<AuthorizedPersonsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final ClientApiService _api = ClientApiService();
  
  List<AuthorizedPerson> _persons = [];
  bool _isLoading = true;

  final Map<String, Color> _relationshipColors = {
    'Spouse': const Color(0xFF8B5CF6),
    'Son': const Color(0xFF3B82F6),
    'Daughter': const Color(0xFFF59E0B),
    'Sister': const Color(0xFF0D6E6E),
    'Brother': const Color(0xFF059669),
    'Parent': const Color(0xFF6366F1),
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
    
    _loadAuthorizedPersons();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthorizedPersons() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await _api.getAuthorizedPersons();
      setState(() {
        _persons = data.map((p) => AuthorizedPerson.fromJson(p)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load authorized persons: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showAddEditDialog({AuthorizedPerson? person}) {
    final nameCtrl = TextEditingController(text: person?.name ?? '');
    final relCtrl = TextEditingController(text: person?.relationship ?? '');
    final phoneCtrl = TextEditingController(text: person?.phone ?? '');
    final emailCtrl = TextEditingController(text: person?.email ?? '');
    final idCtrl = TextEditingController(text: person?.nationalId ?? '');
    final passwordCtrl = TextEditingController();  // ✅ حقل كلمة المرور
    final formKey = GlobalKey<FormState>();
    final isEditing = person != null;

    bool canTrack = person?.canTrack ?? true;
    bool canChat = person?.canChat ?? true;
    bool canViewLocation = person?.canViewLocation ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
                        isEditing ? 'Update Authorized Person' : 'Add Authorized Person',
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
                  _sheetField('Relationship', relCtrl, Icons.people_outline_rounded),
                  const SizedBox(height: 14),
                  _sheetField('Email Address', emailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _sheetField('Phone Number', phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _sheetField('National ID', idCtrl, Icons.badge_outlined, keyboardType: TextInputType.number),
                  const SizedBox(height: 14),
                  // ✅ إضافة حقل كلمة المرور (للأشخاص الجدد فقط)
                  if (!isEditing)
                    _sheetField('Password', passwordCtrl, Icons.lock_outline, isPassword: true, required: true),
                  const SizedBox(height: 20),
                  Text(
                    'Permissions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text('Can Track Services', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                    value: canTrack,
                    onChanged: (val) => setModalState(() => canTrack = val),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  SwitchListTile(
                    title: Text('Can Chat', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                    value: canChat,
                    onChanged: (val) => setModalState(() => canChat = val),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  SwitchListTile(
                    title: Text('Can View Location', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                    value: canViewLocation,
                    onChanged: (val) => setModalState(() => canViewLocation = val),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        
                        // التحقق من كلمة المرور للإضافة الجديدة
                        if (!isEditing && passwordCtrl.text.length < 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password must be at least 4 characters'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);
                        
                        try {
                          final newPersonData = {
                            'fullName': nameCtrl.text,
                            'relationship': relCtrl.text,
                            'email': emailCtrl.text,
                            'phoneNumber': phoneCtrl.text,
                            'nationalId': idCtrl.text,
                            'canTrack': canTrack,
                            'canChat': canChat,
                            'canViewLocation': canViewLocation,
                          };
                          
                          // إضافة كلمة المرور إذا كانت موجودة
                          if (!isEditing && passwordCtrl.text.isNotEmpty) {
                            newPersonData['password'] = passwordCtrl.text;
                          }
                          
                          await _api.addAuthorizedPerson(newPersonData);
                          await _loadAuthorizedPersons();
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEditing ? 'Person updated!' : 'Person added successfully!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => _isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save authorized person: $e'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        isEditing ? 'Save Changes' : 'Add Person',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(AuthorizedPerson person) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Person',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to remove ${person.name} from authorized persons?',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              
              try {
                await _api.deleteAuthorizedPerson(person.id);
                await _loadAuthorizedPersons();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Person removed'), backgroundColor: AppTheme.success),
                  );
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove person'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Remove', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Pending';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Authorized Persons'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _persons.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _persons.length,
                    itemBuilder: (context, i) => _buildPersonCard(_persons[i]),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Person', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildPersonCard(AuthorizedPerson person) {
    final color = _relationshipColors[person.relationship] ?? AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                ClipOval(
                  child: person.avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: person.avatar,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
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
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: person.isActive ? AppTheme.success : AppTheme.textMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          person.relationship,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        person.email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        person.phone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (person.invitedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Invited: ${_formatDate(person.invitedAt)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                  onPressed: () => _showAddEditDialog(person: person),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                  onPressed: () => _confirmDelete(person),
                ),
              ],
            ),
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
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withAlpha(80),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            'No Authorized Persons',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add people who are authorized to\nmanage services on your behalf.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl, IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
    bool isPassword = false,  // ✅ إضافة خاصية كلمة المرور
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }
}