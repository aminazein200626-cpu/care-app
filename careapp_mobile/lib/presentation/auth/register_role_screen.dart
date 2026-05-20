import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/app_routes.dart';

class RegisterRoleScreen extends StatelessWidget {
  const RegisterRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Join Our Community", 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded, 
            color: isDark ? Colors.white : Colors.black87, 
            size: 20
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        children: [
          Text(
            "Select Account Type", 
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87
            )
          ),
          const SizedBox(height: 10),
          Text(
            "Please select your role to provide the best care experience.",
            style: TextStyle(color: Colors.grey[600], fontSize: 15)
          ),
          const SizedBox(height: 35),
          
          _buildRoleCard(
            context, 
            "Service Provider", 
            "Nurse, Sitter, Assistant, or Specialized Cleaner", 
            Icons.medical_services_outlined, 
            () {
              Navigator.pushNamed(context, AppRoutes.registerProvider);
            },
            isDark,
          ),
          
          const SizedBox(height: 20),
          
          _buildRoleCard(
            context, 
            "Client", 
            "I am looking for care for my parents, children, or relatives", 
            Icons.family_restroom_rounded, 
            () {
              Navigator.pushNamed(context, AppRoutes.registerClient);
            },
            isDark,
          ),
          
          const SizedBox(height: 20),
          
          _buildRoleCard(
            context, 
            "Authorized Person", 
            "Person authorized by the client to track care in their absence", 
            Icons.verified_user_outlined, 
            () {
              _showInfoDialog(context, "Authorized Person Registration");
            },
            isDark,
          ),
          
          const SizedBox(height: 40),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87),
                  children: [
                    const TextSpan(text: "Already have an account? "),
                    TextSpan(
                      text: "Sign In", 
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: const Text(
          "Authorized persons cannot register directly.\n\n"
          "They must be added by a client from within the app."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isDark ? Colors.white10 : AppTheme.primary.withOpacity(0.1),
            width: 2
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8)
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle
              ),
              child: Icon(icon, size: 32, color: AppTheme.primary),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey[600], 
                      fontSize: 13,
                      height: 1.4
                    )
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}