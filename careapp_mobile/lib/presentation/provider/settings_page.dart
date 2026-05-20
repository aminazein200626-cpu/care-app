import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import 'change_password_page.dart';
import 'provider_dashboard.dart';
import '../auth/login_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _bookingNotifications = true;
  bool _paymentNotifications = true;
  bool _adNotifications = true;
  bool _messageNotifications = true;

  bool _showPhoneNumber = true;
  bool _showEmail = true;

  String _selectedLanguage = 'English';
  final List<String> _languages = ['English', 'العربية', 'Français'];

  String _selectedCurrency = 'DZD';
  final List<String> _currencies = ['DZD', 'EUR', 'USD'];

  final List<Map<String, String>> _blockedUsers = [
    {'name': 'Ahmed Benali', 'reason': 'Harassment'},
    {'name': 'Sara Lounis', 'reason': 'Late payment'},
  ];

  void _updateNotificationSettings() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings updated"), backgroundColor: Colors.green),
    );
  }

  void _unblockUser(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Unblock User"),
        content: Text("Are you sure you want to unblock ${_blockedUsers[index]['name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _blockedUsers.removeAt(index);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User unblocked"), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Unblock"),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Block User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "User Name",
                hintText: "Enter client name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Reason",
                hintText: "Why are you blocking this user?",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _blockedUsers.add({
                    'name': nameController.text,
                    'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User blocked"), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Block"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently removed.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Account deletion requested. Admin will contact you."), backgroundColor: Colors.orange),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete Account"),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ProviderDashboard(providerName: "Amina"),
              ),
            );
          },
        ),
        title: Text(
          "Settings",
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSection("Account", Icons.person_outlined, isDark, [
              _settingTile(
                icon: Icons.lock_outlined,
                title: "Change Password",
                subtitle: "Update your password",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                  );
                },
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.email_outlined,
                title: "Change Email",
                subtitle: "Update your email address",
                onTap: () {},
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.phone_android,
                title: "Change Phone Number",
                subtitle: "Update your contact number",
                onTap: () {},
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.delete_outline,
                title: "Delete Account",
                subtitle: "Permanently delete your account",
                onTap: _showDeleteAccountDialog,
                isDark: isDark,
                color: Colors.red,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection("Notifications", Icons.notifications_outlined, isDark, [
              _switchTile(
                icon: Icons.notifications,
                title: "Push Notifications",
                value: _notificationsEnabled,
                onChanged: (v) {
                  setState(() {
                    _notificationsEnabled = v;
                  });
                  _updateNotificationSettings();
                },
                isDark: isDark,
              ),
              if (_notificationsEnabled) ...[
                _switchTile(
                  icon: Icons.assignment,
                  title: "Booking Requests",
                  value: _bookingNotifications,
                  onChanged: (v) {
                    setState(() {
                      _bookingNotifications = v;
                    });
                    _updateNotificationSettings();
                  },
                  isDark: isDark,
                ),
                _switchTile(
                  icon: Icons.payment,
                  title: "Payment Updates",
                  value: _paymentNotifications,
                  onChanged: (v) {
                    setState(() {
                      _paymentNotifications = v;
                    });
                    _updateNotificationSettings();
                  },
                  isDark: isDark,
                ),
                _switchTile(
                  icon: Icons.campaign,
                  title: "Ad Status",
                  value: _adNotifications,
                  onChanged: (v) {
                    setState(() {
                      _adNotifications = v;
                    });
                    _updateNotificationSettings();
                  },
                  isDark: isDark,
                ),
                _switchTile(
                  icon: Icons.chat,
                  title: "New Messages",
                  value: _messageNotifications,
                  onChanged: (v) {
                    setState(() {
                      _messageNotifications = v;
                    });
                    _updateNotificationSettings();
                  },
                  isDark: isDark,
                ),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection("Privacy", Icons.lock_outlined, isDark, [
              _switchTile(
                icon: Icons.phone,
                title: "Show Phone Number",
                subtitle: "Visible to clients",
                value: _showPhoneNumber,
                onChanged: (v) {
                  setState(() {
                    _showPhoneNumber = v;
                  });
                  _updateNotificationSettings();
                },
                isDark: isDark,
              ),
              _switchTile(
                icon: Icons.email,
                title: "Show Email Address",
                subtitle: "Visible to clients",
                value: _showEmail,
                onChanged: (v) {
                  setState(() {
                    _showEmail = v;
                  });
                  _updateNotificationSettings();
                },
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.block,
                title: "Blocked Users",
                subtitle: "${_blockedUsers.length} users blocked",
                onTap: () => _showBlockedUsersDialog(isDark),
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.block_flipped,
                title: "Block New User",
                subtitle: "Prevent a client from booking you",
                onTap: _showBlockUserDialog,
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection("Preferences", Icons.tune, isDark, [
              _dropdownTile(
                icon: Icons.language,
                title: "Language",
                value: _selectedLanguage,
                items: _languages,
                onChanged: (v) {
                  setState(() {
                    _selectedLanguage = v;
                  });
                  _updateNotificationSettings();
                },
                isDark: isDark,
              ),
              _dropdownTile(
                icon: Icons.attach_money,
                title: "Currency",
                value: _selectedCurrency,
                items: _currencies,
                onChanged: (v) {
                  setState(() {
                    _selectedCurrency = v;
                  });
                  _updateNotificationSettings();
                },
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection("Support", Icons.help_outline, isDark, [
              _settingTile(
                icon: Icons.help,
                title: "Help Center",
                subtitle: "FAQs and guides",
                onTap: () {},
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.report_problem,
                title: "Report a Problem",
                subtitle: "Contact support team",
                onTap: () {},
                isDark: isDark,
              ),
              _settingTile(
                icon: Icons.info_outline,
                title: "About",
                subtitle: "Version 1.0.0 | Terms of Service",
                onTap: () {},
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection("Logout", Icons.logout, isDark, [
              _settingTile(
                icon: Icons.logout,
                title: "Sign Out",
                subtitle: "Log out of your account",
                onTap: _showLogoutDialog,
                isDark: isDark,
                color: Colors.red,
              ),
            ]),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.primary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: color ?? (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _dropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                items: items.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (v) => onChanged(v!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsersDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Blocked Users"),
        content: _blockedUsers.isEmpty
            ? const Text("No blocked users")
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return ListTile(
                      title: Text(user['name']!),
                      subtitle: Text(user['reason']!),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _unblockUser(index);
                        },
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }
}