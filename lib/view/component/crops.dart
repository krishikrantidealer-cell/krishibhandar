import 'package:flutter/material.dart';

import '../../components/network_image.dart';
import '../../components/widget_button.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';
import '../../services/bhandar_api_service.dart';
import '../collection_view.dart';

class Crops extends StatefulWidget {
  const Crops({super.key});

  @override
  State<Crops> createState() => _CropsState();
}

class _CropsState extends State<Crops> {
  List<Map<String, String>> _crops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    final list = await BhandarApiService.getCrops(context);
    if (mounted) {
      setState(() {
        _crops = list.isNotEmpty ? list : Constants.cropsList;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF26842c)));
    }

    final crops = _crops.isNotEmpty ? _crops : Constants.cropsList;

    return GridView(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .9,
      ),
      children: [
        for (var crop in crops) ...[
          Card(
            clipBehavior: Clip.antiAlias,
            child: WidgetButton(
              onTap: () {
                Routers.goTO(
                  context,
                  toBody: CollectionView(
                    collectionId: (crop['slug'] ?? crop['name'] ?? crop['id'] ?? '').toString(),
                    title: crop['name'],
                  ),
                );
              },
              child: KskNetworkImage(
                crop['image'] ?? '',
                height: 160,
                width: MediaQuery.sizeOf(context).width,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
