import 'package:flutter/material.dart';
import 'admin_panel_screen.dart';

/// Gizli admin girişi. Uygulamanın normal akışında hiçbir yerden
/// linklenmez, sadece '/admin' route'unu bilen kişi ulaşabilir.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  // ÖNEMLİ: Bu şifreyi kendi belirleyeceğiniz gizli bir değerle değiştirin.
  static const String _adminPassword = 'E8011ytu!';

  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _isChecking = false;

  void _submit() {
    setState(() => _isChecking = true);

    if (_passwordController.text == _adminPassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      );
    } else {
      setState(() {
        _errorText = 'Hatalı şifre.';
        _isChecking = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF01132A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Admin Şifresi',
                  labelStyle: const TextStyle(color: Colors.white70),
                  errorText: _errorText,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _submit,
                  child: const Text('Giriş Yap'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
