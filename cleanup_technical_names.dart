import 'dart:convert';
import 'dart:io';

String slugify(String text) {
  return text.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String cleanTechnicalName(String name) {
  String current = name.trim();
  bool changed = true;
  
  while (changed) {
    changed = false;
    
    // 1. Remove leading brackets and dashes
    final leadingSpecials = RegExp(r'^[()\-–—]+');
    if (leadingSpecials.hasMatch(current)) {
      current = current.replaceFirst(leadingSpecials, '').trim();
      changed = true;
    }
    
    // 2. Remove leading numeric codes (e.g., 404, 505, 4G, 20-20-20) followed by space
    // Pattern: One or more digits, followed by optional -/digits/G, followed by whitespace
    final numericPrefix = RegExp(r'^\d+[-0-9G]*\s+');
    if (numericPrefix.hasMatch(current)) {
      current = current.replaceFirst(numericPrefix, '').trim();
      changed = true;
    }
  }
  
  return current;
}

void main() {
  final file = File('assets/technical_names.json');
  if (!file.existsSync()) {
    print('Error: assets/technical_names.json not found');
    return;
  }

  final List<dynamic> data = json.decode(file.readAsStringSync());
  int totalCleaned = 0;
  int specialCleaned = 0;
  int numericCleaned = 0;
  List<String> corrections = [];

  for (var entry in data) {
    String originalName = entry['technicalName'];
    String cleanedName = cleanTechnicalName(originalName);
    
    if (originalName != cleanedName) {
      totalCleaned++;
      
      // Determine what type of cleaning happened for the report
      if (RegExp(r'^[()\-–—]').hasMatch(originalName)) specialCleaned++;
      if (RegExp(r'^\d').hasMatch(originalName)) numericCleaned++;
      
      if (corrections.length < 20) {
        corrections.add('"$originalName" -> "$cleanedName"');
      }
      
      entry['technicalName'] = cleanedName;
      entry['slug'] = slugify(cleanedName);
    }
  }

  file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(data));

  print('Technical Names Cleanup Report:');
  print('-------------------------------');
  print('Total records cleaned: $totalCleaned');
  print('Special-character entries cleaned: $specialCleaned');
  print('Numeric-prefix entries cleaned: $numericCleaned');
  print('\nFirst 20 corrected examples:');
  for (var correction in corrections) {
    print(correction);
  }
  print('-------------------------------');
}
