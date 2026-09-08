import 'package:flutter/material.dart';
import '../../controller/admin_controller.dart';
import '../../controller/routers.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AdminController.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, Routers.root);
            },
          )
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildCard(
            context,
            "Send Now",
            Icons.send,
            Colors.blue,
            () => Navigator.pushNamed(context, Routers.adminNotificationForm, arguments: {'isScheduled': false}),
          ),
          _buildCard(
            context,
            "Schedules",
            Icons.schedule,
            Colors.orange,
            () => Navigator.pushNamed(context, Routers.adminSchedules),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
