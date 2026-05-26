// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get home => 'முகப்பு';

  @override
  String get categories => 'வகைகள்';

  @override
  String get myOrders => 'எனదు ஆர்டர்கள்';

  @override
  String get myCart => 'எனது கார்ட்';

  @override
  String get support => 'உதவி';

  @override
  String get contactUs => 'எங்களைத் தொடர்பு கொள்ளவும்';

  @override
  String get privacyPolicy => 'தனியுரிமைக் கொள்கை';

  @override
  String get shippingPolicy => 'ஷிப்பிங் கொள்கை';

  @override
  String get termsConditions => 'விதிமுறைகள் மற்றும் నిబంధనలు';

  @override
  String get pureOrganic => 'பிரீமியம் தேர்வு';

  @override
  String get searchProducts => 'தயாரிப்புகளைத் தேடுங்கள்...';

  @override
  String get menu => 'மெனு';

  @override
  String get viewCart => 'கார்ட்டைப் பார்க்கவும்';

  @override
  String get organic => 'இயற்கை';

  @override
  String get bestSeller => 'அதிக விற்பனை';

  @override
  String get insecticides => 'பூச்சிக்கொல்லிகள்';

  @override
  String get fungicides => 'பூஞ்சை కాళాన్';

  @override
  String get fertilizers => 'உரங்கள்';

  @override
  String get herbicides => 'களைக்கொல்லிகள்';

  @override
  String get growthPromotors => 'வளர்ச்சி ஊக்குவிப்பாளர்கள்';

  @override
  String itemsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பொருட்கள்',
      one: '1 பொருள்',
    );
    return '$_temp0 சேர்க்கப்பட்டன';
  }

  @override
  String get exploreMore => 'மேலும் ஆராயுங்கள்';

  @override
  String get freeShipping => 'இலவச ஷிப்பிங்';

  @override
  String get securePay => 'பாதுகாப்பான கட்டணம்';

  @override
  String get agriSupport => 'விவசாய உதவி';

  @override
  String get whatsAppSupport => 'వాట్సాప్ உதவி';

  @override
  String get collection => 'சேகரிப்பு';

  @override
  String get aToZ => 'అ → క్ష (A → Z)';

  @override
  String get zToA => 'క్ష → అ (Z → A)';

  @override
  String get defaultText => 'இயல்புநிலை';

  @override
  String get pureSelection => 'Krishi Bhandar • பிரீமியம் தேர்வு';

  @override
  String get active => 'செயலில் உள்ளது';

  @override
  String get noActiveOrders => 'செயலில் உள்ள ஆர்டர்கள் எதுவும் இல்லை';

  @override
  String get orderHistory => 'ஆர்டர் வரலாறு';

  @override
  String get total => 'மொத்தம்';

  @override
  String get allOrders => 'அனைத்து ஆர்டர்கள்';

  @override
  String get ongoing => 'நடைபெறுகிறது';

  @override
  String get delivered => 'வழங்கப்பட்டது';

  @override
  String get cancelled => 'ரத்து செய்யப்பட்டது';

  @override
  String items(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count பொருட்கள்',
      one: '1 பொருள்',
    );
    return '$_temp0';
  }

  @override
  String get details => 'விవరங்கள்';

  @override
  String get reorder => 'மீண்டும் ஆர்டர் செய்';

  @override
  String get itemsAddedToBag => 'பொருட்கள் பையில் சேர்க்கப்பட்டன';

  @override
  String get accessRestricted => 'అణుకల్ కట్టుప్పడుత్తప్పట్టదు';

  @override
  String get signInPrompt =>
      'உங்கள் ஆர்டர்களைப் பார்க்கவும் மற்றும் உங்கள் ஷிப்மென்ட்டைப் పిన్రొడరవుం தயவுசெய்து உள்நுழையவும்.';

  @override
  String get bagEmpty => 'உங்கள் பை காலியாக உள்ளது';

  @override
  String get emptyOrdersPrompt =>
      'நீங்கள் இன்னும் எந்த ஆர்டரையும் செய்யவில்லை என்று தெரிகிறது. షాప్పింగ్ చేయండి!';

  @override
  String get callNow => 'ఇప్పుడే కాల్ చేయండి';

  @override
  String get helpSupport => 'உதவி మరియు ஆதரவு';

  @override
  String get supportSubtitle =>
      'உங்களுக்கு ఎరிலும் உதவ நாங்கள் தயாராக இருக்கிறோம்.';

  @override
  String get sendMessage => 'செய்தி அனுப்பு';

  @override
  String get replyTime => 'நாங்கள் 24 மணி நேரத்திற்குள் பதிலளிப்போம்';

  @override
  String get fullName => 'முழு பெயர்';

  @override
  String get enterName => 'உங்கள் பெயரை உள்ளிடவும்';

  @override
  String get phoneNumber => 'தொலைபேசி எண்';

  @override
  String get enterMobile => '10-இலக்க எண்';

  @override
  String get emailAddress => 'மின்னஞ்சல் முகவரி';

  @override
  String get enterEmail => 'செல்லுபடியாகும் மின்னஞ்சலை உள்ளிடவும்';

  @override
  String get yourMessage => 'உங்கள் செய்தி';

  @override
  String get minCharacters => 'குறைந்தது 3 எழுத்துக்கள்';

  @override
  String get sending => 'அனுப்பப்படுகிறது...';

  @override
  String get sendWhatsApp => 'வாட்ஸ்அப் மூலம் அனுப்பு';

  @override
  String get headOffice => 'தலைமை அலுவலகம்';

  @override
  String get officeAddress =>
      'G-2/197A, குல்மோகர் காலனி, போபால், మ.పి., 462039';

  @override
  String get officeEmail => 'info@krishikrantiorganics.com';

  @override
  String get orderSummary => 'ஆர்டர் சுருக்கம்';

  @override
  String get trackOrder => 'ஆர்டரைப் పిన్రొడరవుం';

  @override
  String get orderPlaced => 'ஆர்டர் செய்யப்பட்டது';

  @override
  String get processing => 'செயலாக்கம்';

  @override
  String get shipped => 'అనుప్పప్పట్టదు';

  @override
  String get outForDelivery => 'டெலிவரிக்கு వెలియే ఉంది';

  @override
  String get statusUpdatedRecently => 'நிலை ఇటీవల నవీకరించబడింది';

  @override
  String get trackOnShopify => 'Shopify இல் పిన్రొడరవుం';

  @override
  String get orderInfo => 'ஆர்டர் தகவல்';

  @override
  String get placedOn => 'అన్రు செய்யப்பட்டது';

  @override
  String get payment => 'கட்டணம்';

  @override
  String get yourOrderItems => 'உங்கள் ஆர்டர் பொருட்கள்';

  @override
  String get billSummary => 'பில் சுருக்கம்';

  @override
  String get itemTotal => 'பொருட்களின் మొత్తం';

  @override
  String get deliveryCharge => 'டெலிவரி கட்டணம்';

  @override
  String get handlingFee => 'கையாளுதல் கட்டணம்';

  @override
  String get grandTotal => 'மொத்த தொகை';

  @override
  String get needHelp => 'இந்த ஆர்டரில் உதவி தேவையா?';

  @override
  String paidVia(Object method) {
    return '$method மூலம் செலுத்தப்பட்டது';
  }

  @override
  String get cancelOrder => 'ஆர்டரை ரத்து செய்';

  @override
  String get cancellationReason =>
      'ரத்து செய்வதற்கான காரணத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get goBack => 'பின்னால் செல்';

  @override
  String get cancelSuccess => 'ஆர்டர் வெற்றிகரமாக రత్తు செய்யப்பட்டது';

  @override
  String get cancelFail =>
      'ஆர்டரை రత్తు చేయ ముడియవిల్లై. மீண்டும் முயற்சிக்கவும்.';

  @override
  String get reasonChangedMind => 'என் எண்ணத்தை மாற்றிக்கொண்டேன்';

  @override
  String get reasonMistake => 'தவறாக ஆர்டர் செய்யப்பட்டது';

  @override
  String get reasonBetterPrice => 'வேறு இடங்களில் சிறந்த விலை கிடைத்தது';

  @override
  String get reasonLongTime => 'டெলিவரி நேரம் மிக அதிகம்';

  @override
  String get reasonCoupon => 'కూపన్ పయన్రొడుత్త మరందువిట్టేన్';

  @override
  String get reasonOther => 'இதர';

  @override
  String get statusDeliveredMsg =>
      'உங்கள் வீட்டு வாசலில் வெற்றிகரமாக வழங்கப்பட்டது.';

  @override
  String get statusShippedMsg => 'வணிகர் கூரியரிடம் ஆர்டரை ஒப்படைத்துள்ளார்.';

  @override
  String get statusProcessingMsg =>
      'ஆர்டர் பேக் செய்யப்பட்டு பிக்கப்பிற்குத் தயாராக உள்ளது.';

  @override
  String get statusCancelledMsg =>
      'உங்கள் ஆர்டர் ரத்து செய்யப்பட்டது. பணத்தைத் திரும்பப் பெறுதல் செயல்படுத்தப்படும்.';

  @override
  String get statusDefaultMsg =>
      'அற்புதம்! உங்களுக்குச் సేవాయాట్ర ఆవలుడన్ కాత్తిరుక్కిరోమ్.';

  @override
  String get shopByCategory => 'வகையின் அடிப்படையில் ஷాப்பிங் செய்யுங்கள்';

  @override
  String categoryCount(Object count) {
    return '$count வகைகள்';
  }

  @override
  String get premiumSelection => 'பிரீமியம் தேர்வு';

  @override
  String get appBrandName => 'Krishi Bhandar';

  @override
  String get madeWithHeartForFarmers =>
      'விவசாயிகளுக்காக ❤️ உடன் உருவாக்கப்பட்டது';

  @override
  String get review1Name => 'ராகுல் சர்மா';

  @override
  String get review2Name => 'அமித் படేல்';

  @override
  String get you => 'நீங்கள்';

  @override
  String get appTagline => 'ஒவ்வொரு விவசாயியின் அடையாளம்!';

  @override
  String get updateRequired => 'புதுப்பித்தல் தேவை';

  @override
  String get updateAvailable => 'புதுப்பித்தல் உள்ளது';

  @override
  String get forceUpdateMsg =>
      'ஒரு முக்கியமான புதுப்பித்தல் உள்ளது. எங்கள் சேவைகளைத் தொடர தயவுசெய்து பயன்பாட்டைப் புதுப்பிக்கவும்.';

  @override
  String get optionalUpdateMsg =>
      'புதிய அம்சங்கள் మరియు மேம்பாடுகளுடன் பயன்பாட்டின் புதிய பதிப்பு உள்ளது.';

  @override
  String get later => 'பிறகு';

  @override
  String get updateNow => 'இப்போது புதுப்பி';

  @override
  String get welcomeTo => 'தொடங்குவோம்';

  @override
  String get loginPrompt => 'தொடర உங்கள் మొబైల్ எண்ணுடன் உள்நுழையவும்';

  @override
  String get mobileNumber => 'மொபைல் எண்';

  @override
  String get enterMobileValid => 'தயவுசெய்து உங்கள் మొబైల్ எண்ணை உள்ளிடவும்';

  @override
  String get enterMobile10 => 'மொபைல் எண் 10 இலக்கங்களாக ఉండాలి';

  @override
  String tryAgainIn(Object seconds) {
    return '$seconds వినాడిగళిల్ மீண்டும் முயற்சிக்கவும்';
  }

  @override
  String get sendOtp => 'OTP அனுப்பு';

  @override
  String get verificationSentMsg =>
      'உங்கள் எண்ணுக்கு சரிபார்ப்புக் குறியீட்டை அனுப்புவோம்';

  @override
  String get agreeTermsMsg => 'தொடர்வதன் மூலம், நீங்கள் எங்களின் ';

  @override
  String get and => ' மற்றும் ';

  @override
  String get verifyPhone => 'உங்கள் தொலைபேசி எண்ணைச் சரிபார்க்கவும்';

  @override
  String get enterOtpPrompt => 'அனுப்பப்பட்ட 6-இலக்க குறியீட்டை உள்ளிடவும்';

  @override
  String get verifyOtp => 'OTP சரிபார்க்கவும்';

  @override
  String get resendOtpIn => 'OTP மீண்டும் அனுப்பு ';

  @override
  String get resendOtp => 'OTP மீண்டும் அனுப்பு';

  @override
  String get otpSentAgain => 'OTP மீண்டும் அனுப்பப்பட்டது!';

  @override
  String get farmingEssentials => 'விவசாயத் தேவைகள்';

  @override
  String get slideToDelete => 'నీక్క இடదుపురం స్లైడ్ చేయవుమ్';

  @override
  String get checkout => 'செக்அவுட்';

  @override
  String get cart => 'கார்ட்';

  @override
  String get address => 'చిరునామా';

  @override
  String get basketEmpty => 'கூடை காலியாக உள்ளது';

  @override
  String get basketEmptyMsg =>
      'உங்கள் கூடை எங்கள் பண்ணை-புதிய,\nசிறந்த விவசாயப் பொருட்களுக்காகக் காத்திருக்கிறது.';

  @override
  String get startShopping => 'షాప్పింగ్ చేయడానికి తొడరుంగళ్';

  @override
  String get pureOrganicQuality => 'பிரீமியம் தரத் தேர்வு';

  @override
  String get haveCoupon => 'కూపన్ కురియీడు ఉళ్ళదా?';

  @override
  String get couponApplied => 'కూపన్ పయన్రొడుత్తప్పట్టదు';

  @override
  String get saveMoreMsg => 'உங்கள் ஆர்டரில் மேலும் சேமிக்கவும்';

  @override
  String couponAppliedMsg(Object code) {
    return '$code வெற்றிகரமாக பயன்படுத்தப்பட்டது';
  }

  @override
  String youSaved(Object amount) {
    return 'இந்த ஆர்டரில் நீங்கள் $amount சேமித்துள்ளீர்கள்';
  }

  @override
  String get free => 'இலவசம்';

  @override
  String get deliveryAddress => 'டெலிவரி முகவரி';

  @override
  String deliveringTo(Object name) {
    return '$name க்கான டெலிவரி';
  }

  @override
  String orderSuccessMsg(Object title) {
    return '$title உடன் ஷாப்பிங் செய்ததற்கு நன்றி. உங்கள் ஆர்டர் உறுதிப்படுத்தப்பட்டுள்ளது.';
  }

  @override
  String get orderSuccessTitle => 'ஆர்டர் வெற்றி';

  @override
  String get kisanSewaKendra => 'Krishi Bhandar';

  @override
  String get amountPending => 'நிலுவைத் தொகை';

  @override
  String get paymentMethod => 'கட்டண முறை';

  @override
  String get cod => 'டெலிவரி செய்யும் போது பணம் செலுத்துதல் (COD)';

  @override
  String get onlinePayment => 'ஆன்லைன் கட்டணம்';

  @override
  String get confirmationEmailMsg =>
      'உங்களுக்கு விரைவில் உறுதிப்படுத்தல் மின்னஞ்சல் வரும்';

  @override
  String get continueShopping => 'షాప్పింగైత్ తొడరవుమ్';

  @override
  String get couponDiscount => 'కూపన్ తళ్ళిబడి';

  @override
  String get deliveryFee => 'டெலிவரி கட்டணம்';

  @override
  String get change => 'మాత్రు';

  @override
  String get orderNumber => 'ஆர்டர் எண்';

  @override
  String get amountPaid => 'సెలుత్తప్పట్ట తొహై';

  @override
  String get paymentId => 'கட்டண ஐடி';

  @override
  String get noProductsFound =>
      'இந்த பிரிவில் தயாரிப்புகள் எதுவும் காணப்படவில்லை';

  @override
  String get sortBy => 'దీనిపడి వరుసైప్పడుత్తు';

  @override
  String get add => 'సేర్క్కవుమ్';

  @override
  String get options => 'விருப்பங்கள்';

  @override
  String get selectOption => 'விருப்பத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get productUnavailable =>
      'தயாரிப்பு விவரங்கள் ప్రస్తుతం కిడైక్కవిల్లై';

  @override
  String get brand => 'பிராண்ட்';

  @override
  String get fastDelivery => 'விரைவான டெலிவரி';

  @override
  String get inclusiveTaxes => 'அனைத்து வரிகளும் உட்பட';

  @override
  String get trust1Line1 => '100%';

  @override
  String get trust1Line2 => 'அசல் தயாரிப்புகள்';

  @override
  String get trust2Line1 => 'பாதுகாப்பான';

  @override
  String get trust2Line2 => 'கட்டணங்கள்';

  @override
  String get trust3Line1 => 'சிறந்த முடிவுகள்';

  @override
  String get trust3Line2 => 'உத்தரவாదం';

  @override
  String get selectVariant => 'வகையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get overview => 'కణ్ణోట్టం';

  @override
  String get similarProducts => 'ஒத்த தயாரிப்புகள்';

  @override
  String get viewAll => 'அனைத்தையும் பார்';

  @override
  String get addedToCart => 'தயாரிப்பு கார்ட்டில் சேர்க்கப்பட்டது!';

  @override
  String get easy => 'ఎళిదాన';

  @override
  String get fast => 'వేగమాన';

  @override
  String get addToCart => 'கார்ட்டில் சேர்க்கவும்';

  @override
  String get buyNow => 'இப்போது வாங்கவும்';

  @override
  String get productName => 'தயாரிப்பு பெயர்';

  @override
  String get category => 'வகை';

  @override
  String get technicalContent => 'தொழில்நுட்ப உள்ளடக்கம்';

  @override
  String get noDescription => 'விளக்கம் எதுவும் கிடைக்கவில்லை.';

  @override
  String get aboutProduct => 'தயாரிப்பு பற்றி';

  @override
  String get viewMore => 'மேலும் பார்க்க';

  @override
  String get viewLess => 'குறைவாக பார்க்க';

  @override
  String get howToUse => 'எப்படி பயன்படுத்துவது';

  @override
  String get dosage => 'அளவு';

  @override
  String get applyTime => 'பயன்படுத்தும் நேரம்';

  @override
  String get method => 'முறை';

  @override
  String get writeReview => 'விமர்சனம் எழுதவும்';

  @override
  String get shareExperience =>
      'ఈ తైయారిప్పుడనాన ఉంగళ్ అనుభవత్తైప్ పగిరందు కొళ్ళుంగళ్';

  @override
  String get describeExperience => 'உங்கள் அனுபவத்தை విவரிக்கவும்...';

  @override
  String get submitReview => 'விமர்சனத்தைச் சமர்ப்பிக்கவும்';

  @override
  String get customerReviews => 'வாடிக்கையாளர் விமர்சனங்கள்';

  @override
  String get dosageDesc =>
      'ஒரு லிட்டர் தண்ணீருக்கு 2-3 மி.லி கலந்து பயன்படுத்தவும்.';

  @override
  String get applyTimeDesc =>
      'அதிகாலை அல்லது மாலை வேளையில் பயன்படுத்துவது சிறந்தது.';

  @override
  String get methodDesc =>
      'அதிகபட்ச செயல்திறனுக்காக ఇలై తెలియ్ప్పు మురైయాహప్ పయన్రొడుత్తవుమ్.';

  @override
  String get review1Comment =>
      'மிகவும் பயனுள்ள தயாரிப்பு. 1 வாரத்தில் முடிவுகளைக் கண்டேன். பரிந்துரைக்கிறேன்!';

  @override
  String get review2Comment =>
      'நல்ல தரம் மற்றும் அசல் தயாரிப்பு. பேக்கேஜிங் மிகவும் நன்றாக இருந்தது.';

  @override
  String daysAgo(Object count) {
    return '$count நாட்களுக்கு முன்பு';
  }

  @override
  String off(Object percentage) {
    return '$percentage% தள்ளுபடி';
  }

  @override
  String get pgr => 'வளர்ச்சி ஊக்குவிப்பான் (PGR)';

  @override
  String get npkFertilizer => 'NPK உரம்';

  @override
  String get bioPesticide => 'உயிரி பூச்சிக்கொல்லி';

  @override
  String get bioFungicide => 'உயிரி பூஞ்சை காளான்';

  @override
  String get bioFertilizer => 'உயிரி உரம்';

  @override
  String get selectAddressToProceed =>
      'తొడర డెలివరీ ముహవరియైత్ తేర్న్దెడుక్కవుమ్';

  @override
  String get addDeliveryAddress => 'டெலிவரி முகவரியைச் சேர்க்கவும்';

  @override
  String get proceedToPlaceOrder => 'ஆர்டர் செய்யத் தொடரவும்';

  @override
  String get paymentOptions => 'கட்டண விருப்பங்கள்';

  @override
  String get choosePreferredMethod =>
      'உங்களுக்கு விருப்பமான முறையைத் தேர்ந்தெடுக்கவும்';

  @override
  String get couponActiveOnlineDisabled =>
      'కూపన్ సెయలిల్ ఉళ్ళదు: ஆன்லைன் தள்ளுபடி ముడక్కప్పట్టదు.';

  @override
  String get payMethodSubtitle => 'UPI, கார்டு, வாலட்';

  @override
  String get codSubtitle => 'உங்கள் வீட்டு வாசலில் பணம் செலுத்துங்கள்';

  @override
  String get secureTransactions => '100% பாதுகாப்பான పరివర్తనైహళ్';

  @override
  String get trustBadges => 'அசல் • సాன்றிదழ் పెట్ర • నంబహమాన';

  @override
  String get applyCoupon => 'కూపనైప్ పయన్రొడుత్తు';

  @override
  String get enterCouponCode => 'కూపన్ కురియీట్టై ఉళ్ళిడవుమ్';

  @override
  String get apply => 'பயன்படுத்து';

  @override
  String get invalidCoupon => 'தவறான அல்லது காலாவதியான కూపన్ కురియీడు.';

  @override
  String get newDeliveryAddress => 'புதிய டெலிவரி முகவரி';

  @override
  String get firstName => 'முதல் பெயர்';

  @override
  String get lastName => 'குடும்ப பெயர்';

  @override
  String get placeholderFirstName => 'முதல் பெயர்';

  @override
  String get placeholderLastName => 'குடும்ப பெயர்';

  @override
  String get enterPhoneNumber => 'தொலைபேசி எண்ணை உள்ளிடவும்';

  @override
  String get errPhoneRequired => 'தொலைபேசி எண் தேவை';

  @override
  String get errPhoneValid => 'செல்லுபடியாகும் 10-இலக்க எண்ணை உள்ளிடவும்';

  @override
  String get locating => 'கண்டறிகிறது...';

  @override
  String get useCurrentLocation => 'తర్పెడైయ ఇరుప్పిడత్తైప్ పయన్రొడుత్తవుమ్';

  @override
  String get pincode => 'பின்கோடு';

  @override
  String get addressLine1 => 'முகவரி வரி 1';

  @override
  String get addressLine1Hint => 'வீட்டு எண், தெரு, பகுதி';

  @override
  String get addressLine2 => 'முகவரி வரி 2 (விருப்பம்)';

  @override
  String get addressLine2Hint => 'அடையாளம், காலனி, முதலியன';

  @override
  String get cityDistrict => 'நகரம் / மாவட்டம்';

  @override
  String get state => 'மாநிலம்';

  @override
  String get addNew => 'புதியதைச் சேர்க்கவும்';

  @override
  String get selectAddress => 'முகவரியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get saveAndConfirm => 'சேமித்து உறுதிப்படுத்தவும்';

  @override
  String get confirmAddress => 'முகவரியை உறுதிப்படுத்தவும்';

  @override
  String get locationDisabled => 'இருப்பிட சேவைகள் ముడక్కప్పట్టుళ్ళన.';

  @override
  String get locationDenied => 'இருப்பிட அனுமதிகள் నిరాకరించప్పట్టుళ్ళన.';

  @override
  String get locationPermanentlyDenied =>
      'இருப்பிட அனுமதிகள் నిరందరమాహ నిరాకరించప్పట్టుళ్ళన.';

  @override
  String get locationFailed => 'இருப்பிடத்தைப் பெறுவதில் தோல்வி';

  @override
  String get fieldRequired => 'இந்த புலம் தேவை';

  @override
  String get placeholderCity => 'சென்னை';

  @override
  String get placeholderState => 'தமிழ்நாடு';

  @override
  String get placeholderPincode => '600001';

  @override
  String get clearCart => 'அனைத்தையும் நீக்கு';

  @override
  String get clearCartConfirm => 'கார்ட்டை కాల్యాక్కవా?';

  @override
  String get clearCartConfirmMsg =>
      'நிச்சயமாக உங்கள் கார்ட்டிலிருந்து அனைத்து பொருட்களையும் நீக்க விரும்புகிறீர்களா?';

  @override
  String get cancel => 'ரத்து';

  @override
  String get addFollowingToGetFree => 'Add following to get free:';

  @override
  String get loading => 'Loading...';

  @override
  String get shippingInfo => 'ஷிப்பிங் தகவல்';
}
