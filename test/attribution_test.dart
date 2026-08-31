import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kisan_sewa_kendra/services/attribution_service.dart';

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

  test('Sanitizes (not set) values and recovers source=meta via fbclid', () async {
    final attributionService = AttributionService();
    await attributionService.saveAttributionFromMap({
      'utm_source': '(not set)',
      'utm_medium': '(not set)',
      'utm_campaign': '(not set)',
      'utm_term': 'null',
      'utm_content': 'undefined',
      'fbclid': 'IwAR_TEST_FBCLID_456',
    });

    final attribution = await attributionService.getAttribution();
    expect(attribution['utm_source'], 'meta');
    expect(attribution['utm_medium'], 'cpc');
    expect(attribution['utm_campaign'], '');
    expect(attribution['utm_term'], '');
    expect(attribution['utm_content'], '');
    expect(attribution['fbclid'], 'IwAR_TEST_FBCLID_456');
  });
}
