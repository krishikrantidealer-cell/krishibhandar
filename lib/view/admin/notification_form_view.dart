import 'package:flutter/material.dart';
import '../../controller/admin_controller.dart';
import '../../controller/constants.dart';

class NotificationFormView extends StatefulWidget {
  final Map<String, dynamic>? scheduleData;
  const NotificationFormView({super.key, this.scheduleData});

  @override
  State<NotificationFormView> createState() => _NotificationFormViewState();
}

class _NotificationFormViewState extends State<NotificationFormView> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _imageController = TextEditingController();
  final List<String> _times = [];
  bool _isScheduled = false;
  bool _isActive = true;
  bool _isLoading = false;
  String? _previewUrl;

  @override
  void initState() {
    super.initState();
    if (widget.scheduleData != null) {
      _titleController.text = widget.scheduleData!['title'] ?? '';
      _bodyController.text = widget.scheduleData!['body'] ?? '';
      _imageController.text = widget.scheduleData!['image'] ?? '';
      _previewUrl = _imageController.text;
      
      // Handle isScheduled from navigation arguments or data
      _isScheduled = widget.scheduleData!['isScheduled'] ?? false;
      
      if (widget.scheduleData!['times'] != null) {
        _times.addAll(List<String>.from(widget.scheduleData!['times']));
        _isScheduled = true;
      }
      _isActive = widget.scheduleData!['active'] ?? true;
    }

    _imageController.addListener(() {
      final url = _imageController.text.trim();
      if (url.startsWith("https://")) {
        setState(() => _previewUrl = url);
      } else {
        setState(() => _previewUrl = null);
      }
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Constants.baseColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final String time = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      if (!_times.contains(time)) {
        setState(() => _times.add(time));
      }
    }
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final image = _imageController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Body are required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isScheduled) {
        if (_times.isEmpty) throw "Please add at least one time slot for scheduling.";
        await AdminController.saveSchedule(
          id: widget.scheduleData?['id'],
          title: title,
          body: body,
          imageUrl: image.isEmpty ? null : image,
          times: _times,
          active: _isActive,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Saved Successfully")));
      } else {
        await AdminController.sendNow(
          title: title,
          body: body,
          imageUrl: image.isEmpty ? null : image,
        );
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification Queued Successfully")));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isScheduled ? (widget.scheduleData?['id'] != null ? "Edit Schedule" : "New Schedule") : "New Notification")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Notification Title*", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Message Body*", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _imageController,
              decoration: const InputDecoration(labelText: "Shopify Image URL (HTTPS)", border: OutlineInputBorder(), helperText: "Optional. Must start with https://"),
            ),
            if (_previewUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _previewUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Text("Invalid Image URL"),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text("Schedule (Daily Recurring)", style: TextStyle(fontWeight: FontWeight.bold)),
              value: _isScheduled,
              onChanged: (v) => setState(() => _isScheduled = v),
              activeThumbColor: Constants.baseColor,
            ),
            if (_isScheduled) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Daily Time Slots (24h)", style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(onPressed: _pickTime, icon: const Icon(Icons.add), label: const Text("Add Time")),
                ],
              ),
              Wrap(
                spacing: 8,
                children: _times.map((t) => Chip(
                  label: Text(t),
                  onDeleted: () => setState(() => _times.remove(t)),
                )).toList(),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text("Active"),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeThumbColor: Constants.baseColor,
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(backgroundColor: Constants.baseColor, foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isScheduled ? "Save Schedule" : "Send Now"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
