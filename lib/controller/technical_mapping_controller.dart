import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../model/technical_mapping_model.dart';
import '../model/product_model.dart';

class TechnicalMappingController {
  static final TechnicalMappingController _instance = TechnicalMappingController._internal();
  factory TechnicalMappingController() => _instance;
  TechnicalMappingController._internal();

  List<TechnicalMappingModel> _allMappings = [];
  bool _isLoaded = false;
  Map<String, List<TechnicalMappingModel>> _cachedGroups = {};
  
  // Precomputed for fast search and navigation
  Map<String, List<ProductModel>> _technicalToProducts = {};
  List<ProductModel> _allProducts = [];

  bool get isLoaded => _isLoaded;

  Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    try {
      final sw = Stopwatch()..start();
      debugPrint('JSON load started');
      final String response = await rootBundle.loadString('assets/technical_names.json');
      final data = json.decode(response);
      debugPrint('JSON decode finished in ${sw.elapsedMilliseconds} ms');
      
      if (data is List) {
        _allMappings = data.map((e) => TechnicalMappingModel.fromJson(e)).toList();
        
        debugPrint('Precomputing data started');
        _cachedGroups = _calculateAlphabeticalGroups(_allMappings);
        
        // Precompute technical to products mapping
        _technicalToProducts = {};
        for (var mapping in _allMappings) {
          final List<ProductModel> products = mapping.products.map((tp) {
            return ProductModel(
              id: tp.id,
              title: tp.title,
              body: '',
              vendor: '',
              productType: '',
              handle: tp.handle,
              images: tp.image != null ? [tp.image!] : [],
              image: tp.image,
              variants: [
                VariantModel(
                  id: tp.id,
                  title: 'Default',
                  price: tp.price,
                  inventoryQuantity: 1,
                )
              ],
            );
          }).toList();
          _technicalToProducts[mapping.technicalName.toLowerCase()] = products;
        }
        debugPrint('Precomputing data finished in ${sw.elapsedMilliseconds} ms');
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading technical mappings: $e');
    }
  }

  List<TechnicalMappingModel> getAllMappings() => _allMappings;

  // Faster search using precomputed lowercase names
  List<TechnicalMappingModel> searchMappings(String query) {
    if (query.isEmpty) return _allMappings;
    final lowercaseQuery = query.toLowerCase();
    return _allMappings.where((element) {
      return element.technicalName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
  
  // New: Search products by technical name
  List<ProductModel> searchProductsByTechnical(String query) {
    if (query.isEmpty) return [];
    final lowercaseQuery = query.toLowerCase();
    final List<ProductModel> results = [];
    final seenProductIds = <String>{};

    for (var entry in _technicalToProducts.entries) {
      if (entry.key.contains(lowercaseQuery)) {
        for (var product in entry.value) {
          if (!seenProductIds.contains(product.id)) {
            results.add(product);
            seenProductIds.add(product.id);
          }
        }
      }
    }
    return results;
  }

  List<ProductModel> getProductsForTechnical(String technicalName) {
    return _technicalToProducts[technicalName.toLowerCase()] ?? [];
  }

  Map<String, List<TechnicalMappingModel>> getAlphabeticalGroups() => _cachedGroups;

  Map<String, List<TechnicalMappingModel>> _calculateAlphabeticalGroups(List<TechnicalMappingModel> mappings) {
    final Map<String, List<TechnicalMappingModel>> groups = {};
    for (var mapping in mappings) {
      if (mapping.technicalName.isEmpty) continue;
      final String firstLetter = mapping.technicalName[0].toUpperCase();
      if (!groups.containsKey(firstLetter)) {
        groups[firstLetter] = [];
      }
      groups[firstLetter]!.add(mapping);
    }
    
    final sortedKeys = groups.keys.toList()..sort();
    final Map<String, List<TechnicalMappingModel>> sortedGroups = {};
    for (var key in sortedKeys) {
      sortedGroups[key] = groups[key]!..sort((a, b) => a.technicalName.compareTo(b.technicalName));
    }
    
    return sortedGroups;
  }
}
