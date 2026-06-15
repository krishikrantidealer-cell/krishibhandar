import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controller/constants.dart';
import '../controller/routers.dart';
import '../controller/technical_mapping_controller.dart';
import '../model/product_model.dart';
import '../model/technical_mapping_model.dart';
import '../shopify/shopify.dart';
import '../view/product_view.dart';
import 'network_image.dart';
import '../services/attribution_service.dart';

class CustomSearchDelegate extends SearchDelegate<String> {
  final ValueNotifier<int> _searchMode = ValueNotifier<int>(0); // 0: Product, 1: Technical
  final ValueNotifier<TechnicalMappingModel?> _selectedTechnical = ValueNotifier<TechnicalMappingModel?>(null);
  final TechnicalMappingController _techController = TechnicalMappingController();

  CustomSearchDelegate() {
    _techController.ensureLoaded();
  }

  @override
  String get searchFieldLabel => _searchMode.value == 0 ? "Search by Product Name" : "Search by Technical Name";

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return ValueListenableBuilder<TechnicalMappingModel?>(
      valueListenable: _selectedTechnical,
      builder: (context, selected, _) {
        return IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () {
            if (selected != null) {
              _selectedTechnical.value = null;
            } else {
              close(context, '');
            }
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isNotEmpty) {
      AttributionService.logSearch(query);
    }
    return _wrapWithToggle(context, isSuggestions: false);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _wrapWithToggle(context, isSuggestions: true);
  }

  Widget _wrapWithToggle(BuildContext context, {required bool isSuggestions}) {
    return ValueListenableBuilder<int>(
      valueListenable: _searchMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<TechnicalMappingModel?>(
          valueListenable: _selectedTechnical,
          builder: (context, selectedTech, _) {
            final content = isSuggestions
                ? _buildSuggestionsContent(context, selectedTech)
                : _buildSearchContent(context, selectedTech);
            return Column(
              children: [
                _buildSegmentedControl(context, mode),
                Expanded(
                  child: content,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSegmentedControl(BuildContext context, int currentMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      height: 80, // Slightly taller for 2 lines
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildSegmentItem(context, "Search by\nProduct Name", 0, currentMode),
          const SizedBox(width: 8),
          _buildSegmentItem(context, "Search by\nTechnical Name", 1, currentMode),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(BuildContext context, String title, int mode, int currentMode) {
    final isSelected = mode == currentMode;
    final lines = title.split('\n');

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _selectedTechnical.value = null;
          _searchMode.value = mode;
          query = '';
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Constants.baseColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                lines[0],
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white.withOpacity(0.9) : const Color(0xFF616161),
                ),
              ),
              Text(
                lines[1],
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsContent(BuildContext context, TechnicalMappingModel? selectedTech) {
    if (_searchMode.value == 1) {
      return _buildTechnicalBrowser(context, selectedTech);
    }

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<ProductModel>>(
      future: Shopify.fetchSearchResults(context, query: query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "No products found for '$query'",
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          );
        }
        return _buildProductList(context, snapshot.data!);
      },
    );
  }

  Widget _buildSearchContent(BuildContext context, TechnicalMappingModel? selectedTech) {
    if (_searchMode.value == 1) {
      return _buildTechnicalBrowser(context, selectedTech);
    }

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<ProductModel>>(
      future: Shopify.fetchSearchResults(context, query: query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No results found for '$query'"));
        }
        return _buildProductList(context, snapshot.data!);
      },
    );
  }

  Widget _buildTechnicalBrowser(BuildContext context, TechnicalMappingModel? selectedTech) {
    if (!_techController.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedTech != null) {
      final products = _techController.getProductsForTechnical(selectedTech.technicalName);
      return _buildProductList(context, products, selectedTech.technicalName);
    }

    if (query.isNotEmpty) {
      final results = _techController.searchMappings(query);
      if (results.isEmpty) {
        return Center(
          child: Text(
            "No technical names found for '$query'",
            style: GoogleFonts.outfit(color: Colors.grey),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final m = results[index];
          return ListTile(
            dense: true,
            title: Text(m.technicalName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
            onTap: () {
              _selectedTechnical.value = m;
              query = '';
            },
          );
        },
      );
    }

    final groups = _techController.getAlphabeticalGroups();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final letter = groups.keys.elementAt(index);
        final mappings = groups[letter]!;
        return _AlphabetRow(
          letter: letter,
          mappings: mappings,
          onTap: (m) {
            _selectedTechnical.value = m;
            query = '';
          },
        );
      },
    );
  }

  Widget _buildProductList(BuildContext context, List<ProductModel> products, [String? title]) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: products.length + (title != null ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, index) {
        if (title != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          );
        }
        final product = products[title != null ? index - 1 : index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 55, height: 55,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF5F5F5))),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: KskNetworkImage(product.image ?? '', fit: BoxFit.contain)),
          ),
          title: Text(product.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text("${Constants.inr}${product.variants.isNotEmpty ? product.variants.first.price : '0'}",
                style: TextStyle(color: Constants.baseColor, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          onTap: () async {
            // SAME Product Details Page for both modes
            await Routers.goTO(context, toBody: ProductView(product: product));
            // Reset search state on return
            query = '';
            _selectedTechnical.value = null;
          },
        );
      },
    );
  }
}

class _AlphabetRow extends StatefulWidget {
  final String letter;
  final List<TechnicalMappingModel> mappings;
  final Function(TechnicalMappingModel) onTap;

  const _AlphabetRow({required this.letter, required this.mappings, required this.onTap});

  @override
  State<_AlphabetRow> createState() => _AlphabetRowState();
}

class _AlphabetRowState extends State<_AlphabetRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          minTileHeight: 60,
          title: Text(widget.letter, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
          trailing: Icon(_isExpanded ? Icons.remove : Icons.add, color: Colors.black87),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
        if (_isExpanded)
          ...widget.mappings.map((m) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(m.technicalName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
            onTap: () => widget.onTap(m),
          )),
      ],
    );
  }
}
