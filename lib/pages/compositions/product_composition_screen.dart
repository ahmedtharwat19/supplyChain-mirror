import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:puresip_purchasing/models/product_composition_model.dart';
import 'package:puresip_purchasing/models/finished_product.dart';
import 'package:puresip_purchasing/pages/compositions/add_composition_screen.dart';
import 'package:puresip_purchasing/pages/compositions/services/composition_service.dart';
import 'package:puresip_purchasing/pages/finished_products/services/finished_product_service.dart';
import 'package:puresip_purchasing/services/company_service.dart';
import 'package:puresip_purchasing/services/factory_service.dart';
import 'package:puresip_purchasing/services/firestore_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ProductCompositionScreen extends StatefulWidget {
  final String productId;

  const ProductCompositionScreen({super.key, required this.productId});

  @override
  State<ProductCompositionScreen> createState() => _ProductCompositionScreenState();
}

class _ProductCompositionScreenState extends State<ProductCompositionScreen> {
  late bool isArabic;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    isArabic = context.locale.languageCode == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    final compositionService = Provider.of<CompositionService>(context);
    final finishedProductService = Provider.of<FinishedProductService>(context);
    final companyService = Provider.of<CompanyService>(context);
    final factoryService = Provider.of<FactoryService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('manufacture.product_composition'.tr()),
      ),
      body: StreamBuilder<FinishedProduct?>(
        stream: finishedProductService.getFinishedProductByIdStream(widget.productId),
        builder: (context, productSnapshot) {
          if (productSnapshot.hasError) {
            return Center(child: Text('error_loading_product'.tr()));
          }

          if (productSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final product = productSnapshot.data;

          return StreamBuilder<ProductComposition?>(
            stream: compositionService.getCompositionByProductId(widget.productId),
            builder: (context, compositionSnapshot) {
              if (compositionSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('manufacture.error_loading_composition'.tr()),
                      const SizedBox(height: 16),
                      Text(
                        compositionSnapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (compositionSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final composition = compositionSnapshot.data;

              if (composition == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('manufacture.no_composition_found'.tr()),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddCompositionScreen(
                                productId: widget.productId,
                                companyId: product?.companyId ?? '',
                                factoryId: product?.factoryId ?? '',
                              ),
                            ),
                          );
                        },
                        child: Text('manufacture.add_composition'.tr()),
                      ),
                    ],
                  ),
                );
              }

              return _buildCompositionDetails(
                context,
                composition,
                product,
                companyService,
                factoryService,
                firestoreService,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCompositionDetails(
    BuildContext context,
    ProductComposition composition,
    FinishedProduct? product,
    CompanyService companyService,
    FactoryService factoryService,
    FirestoreService firestoreService,
  ) {
    return FutureBuilder<Map<String, String?>>(
      future: _getCompanyAndFactoryNames(composition, companyService, factoryService),
      builder: (context, snapshot) {
        final companyName = snapshot.data?['companyName'];
        final factoryName = snapshot.data?['factoryName'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${'product_name'.tr()}: ${product?.nameAr ?? composition.productId}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('${'company'.tr()}: ${companyName ?? composition.companyId}'),
                      Text('${'factory'.tr()}: ${factoryName ?? composition.factoryId}'),
                      Text('${'batch_size'.tr()}: ${composition.batchSize} ${composition.unit}'),
                      Text('${'shelf_life'.tr()}: ${composition.shelfLife} ${'months'.tr()}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (composition.rawMaterials.isNotEmpty) ...[
                Text(
                  'raw_materials'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...composition.rawMaterials.map((material) => _buildMaterialCard(material, firestoreService)),
                const SizedBox(height: 20),
              ],
              if (composition.packagingMaterials.isNotEmpty) ...[
                Text(
                  'packaging_materials'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...composition.packagingMaterials.map((material) => _buildMaterialCard(material, firestoreService)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialCard(CompositionItem material, FirestoreService firestoreService) {
    return FutureBuilder<String>(
      future: _getItemName(material.itemId, firestoreService),
      builder: (context, snapshot) {
        final itemName = snapshot.data ?? material.itemId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(itemName),
            subtitle: Text('${material.quantity} ${material.unit}'),
            trailing: Text(
              material.unit,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Future<String> _getItemName(String itemId, FirestoreService firestoreService) async {
    try {
      final item = await firestoreService.getItemById(itemId);
      if (item == null) return itemId;
      return isArabic ? item.nameAr : item.nameEn;
    } catch (e) {
      return itemId;
    }
  }

  Future<Map<String, String?>> _getCompanyAndFactoryNames(
    ProductComposition composition,
    CompanyService companyService,
    FactoryService factoryService,
  ) async {
    try {
      final companyName = await companyService
          .getCompanyById(composition.companyId)
          .then((c) => isArabic ? c?.nameAr : c?.nameEn);
      final factoryName = await factoryService
          .getFactoryById(composition.factoryId)
          .then((f) => isArabic ? f?.nameAr : f?.nameEn);

      return {
        'companyName': companyName,
        'factoryName': factoryName,
      };
    } catch (e) {
      return {'companyName': null, 'factoryName': null};
    }
  }
}
