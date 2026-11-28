import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kisan_sewa_kendra/controller/cart_controller.dart';
import 'package:kisan_sewa_kendra/services/attribution_service.dart';
import 'package:kisan_sewa_kendra/services/shiprocket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Auto-infers utm_source=meta and utm_medium=cpc when fbclid is present', () async {
    final attributionService = AttributionService();
    await attributionService.saveAttributionFromMap({
      'fbclid': 'IwAR_TEST_FBCLID_XYZ123',
      'utm_campaign': 'spring_sale_2026',
    });

    final attribution = await attributionService.getAttribution();
    expect(attribution['utm_source'], 'meta');
    expect(attribution['utm_medium'], 'cpc');
    expect(attribution['utm_campaign'], 'spring_sale_2026');
    expect(attribution['fbclid'], 'IwAR_TEST_FBCLID_XYZ123');
  });

  test('Preserves explicit utm_source from Meta Ads', () async {
    final attributionService = AttributionService();
    await attributionService.saveAttributionFromMap({
      'utm_source': 'facebook',
      'utm_medium': 'paid_social',
      'utm_campaign': 'cotton_farmer_campaign',
      'utm_content': 'video_ad_1',
      'fbclid': 'IwAR_TEST_FBCLID_999',
    });

    final attribution = await attributionService.getAttribution();
    expect(attribution['utm_source'], 'facebook');
    expect(attribution['utm_medium'], 'paid_social');
    expect(attribution['utm_campaign'], 'cotton_farmer_campaign');
    expect(attribution['utm_content'], 'video_ad_1');
    expect(attribution['fbclid'], 'IwAR_TEST_FBCLID_999');
  });

  test('Preserves first-touch initial_utm_source across clearAttribution()', () async {
    final attributionService = AttributionService();
    await attributionService.saveAttributionFromMap({
      'utm_source': 'meta_app_ad',
      'utm_medium': 'paid_social',
      'utm_campaign': 'install_campaign_1',
      'fbclid': 'FB_CLICK_1',
    });

    await attributionService.clearAttribution();
    final afterClear = await attributionService.getAttribution();

    expect(afterClear['utm_source'], 'organic');
    expect(afterClear['fbclid'], '');
    expect(afterClear['initial_utm_source'], 'meta_app_ad');
    expect(afterClear['initial_utm_campaign'], 'install_campaign_1');
    expect(afterClear['channel'], 'Mobile App');
    expect(afterClear['order_source'], 'mobile_app');
  });

  test('Push notification does not overwrite active paid fbclid attribution', () async {
    final attributionService = AttributionService();
    await attributionService.saveAttributionFromMap({
      'utm_source': 'meta',
      'utm_medium': 'cpc',
      'utm_campaign': 'paid_campaign',
      'fbclid': 'ACTIVE_FBCLID_123',
    });

    await attributionService.handlePushNotification(
      const RemoteMessage(data: {'campaign': 'diwali_push'}),
    );

    final attribution = await attributionService.getAttribution();
    expect(attribution['utm_source'], 'meta');
    expect(attribution['utm_campaign'], 'paid_campaign');
    expect(attribution['fbclid'], 'ACTIVE_FBCLID_123');
    expect(attribution['last_push_campaign'], 'diwali_push');
  });

  test('ShiprocketService.buildCheckoutPayload includes channel=Mobile App and UTMs in cartAttributes', () async {
    final attributionService = AttributionService();
    await attributionService.saveAttributionFromMap({
      'utm_source': 'meta',
      'utm_medium': 'cpc',
      'utm_campaign': 'diwali_test',
      'fbclid': 'FB_TEST_999',
    });

    final attribution = await attributionService.getAttribution();
    final payload = ShiprocketService.buildCheckoutPayload(
      cartItems: [
        CartItem(
          id: 'gid://shopify/ProductVariant/44053721088153',
          productId: 'gid://shopify/Product/123456',
          title: 'Chlormites',
          price: '₹250.00',
          qty: 1,
          image: 'https://example.com/img.png',
          variantTitle: '250ML',
        ),
      ],
      attributionParams: attribution,
      customerPhone: '9876543210',
      shippingAddress: {
        'city': 'Pune',
        'state': 'Maharashtra',
        'pincode': '411001',
      },
    );

    final cartAttrs = payload['cartAttributes'] as Map<String, dynamic>;
    expect(cartAttrs['channel'], 'Mobile App');
    expect(cartAttrs['order_source'], 'mobile_app');
    expect(cartAttrs['utm_source'], 'meta');
    expect(cartAttrs['utm_campaign'], 'diwali_test');
    expect(cartAttrs['fbclid'], 'FB_TEST_999');
    expect(cartAttrs['initial_utm_source'], 'meta');
    expect(cartAttrs['customer_phone'], '9876543210');
    expect(payload['utmParams'].toString(), contains('utm_source=meta'));
  });

  test('Sanitizes legacy "(not set)" values from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'utm_source': '(not set)',
      'utm_medium': '(not set)',
      'initial_utm_source': '(not set)',
      'utm_campaign': 'none',
    });

    final attribution = await AttributionService().getAttribution();
    expect(attribution['utm_source'], 'organic');
    expect(attribution['utm_medium'], 'app');
    expect(attribution['initial_utm_source'], 'organic');
    expect(attribution['utm_campaign'], '');
  });
}
