import 'package:flutter/material.dart';
import '../../controller/admin_controller.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';

class AdminLoginView extends StatefulWidget {
  const AdminLoginView({super.key});

  @override
  State<AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<AdminLoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await AdminController.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        final isAdmin = await AdminController.isUserAdmin();
        if (isAdmin) {
          if (mounted) Navigator.pushReplacementNamed(context, Routers.adminDashboard);
        } else {
          await AdminController.signOut();
          throw "Access denied. You do not have admin privileges.";
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Portal")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Admin Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(backgroundColor: Constants.baseColor, foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Login as Admin"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
