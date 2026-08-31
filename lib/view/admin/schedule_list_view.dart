import 'package:flutter/material.dart';
import '../../controller/admin_controller.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';

class ScheduleListView extends StatefulWidget {
  const ScheduleListView({super.key});

  @override
  State<ScheduleListView> createState() => _ScheduleListViewState();
}

class _ScheduleListViewState extends State<ScheduleListView> {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await AdminController.getScheduledNotifications();
      setState(() {
        _schedules = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scheduled Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSchedules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(
            context,
            Routers.adminNotificationForm,
            arguments: {'isScheduled': true},
          );
          _fetchSchedules(); // Refresh after returning
        },
        backgroundColor: Constants.baseColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Error: $_error", style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchSchedules, child: const Text("Retry")),
          ],
        ),
      );
    }
    if (_schedules.isEmpty) return const Center(child: Text("No schedules found."));

    return RefreshIndicator(
      onRefresh: _fetchSchedules,
      child: ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          final data = _schedules[index];
          final id = data['id'];
          final isActive = data['active'] ?? true;
          final imageUrl = data['image'] as String?;
          final times = List<String>.from(data['times'] ?? []);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: imageUrl != null && imageUrl.startsWith("https://")
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                      ),
                    )
                  : const Icon(Icons.notifications_active),
              title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${times.join(', ')} | ${isActive ? 'Active' : 'Inactive'}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: isActive,
                    onChanged: (v) async {
                      try {
                        await AdminController.saveSchedule(
                          id: id,
                          title: data['title'],
                          body: data['body'],
                          imageUrl: data['image'],
                          times: times,
                          active: v,
                        );
                        _fetchSchedules();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Toggle Failed: $e")));
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      await Navigator.pushNamed(
                        context,
                        Routers.adminNotificationForm,
                        arguments: {'id': id, 'isScheduled': true, ...data},
                      );
                      _fetchSchedules();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Schedule?"),
        content: const Text("This will stop all future notifications for this schedule."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              try {
                await AdminController.deleteSchedule(id);
                if (c.mounted) Navigator.pop(c);
                _fetchSchedules();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: $e")));
                  Navigator.pop(c);
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
