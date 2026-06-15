import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('assets/technical_names.json');
  final List<dynamic> data = json.decode(file.readAsStringSync());
  for (var entry in data) {
    String name = entry['technicalName'];
    if (RegExp(r'^[()\-–—\d]').hasMatch(name.trim())) {
      print('DIRTY: $name');
    }
  }
}
