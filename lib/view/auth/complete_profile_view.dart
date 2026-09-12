import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../controller/auth_controller.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';
import '../../services/api_service.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';

class CompleteProfileView extends StatefulWidget {
  final String phone;
  final String? customerId;
  final String? name;

  const CompleteProfileView({
    super.key,
    required this.phone,
    this.customerId,
    this.name,
  });

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _customCityController = TextEditingController();

  String? _selectedState;
  String? _selectedCity;
  bool _isCustomCity = false;
  bool _isPinLoading = false;
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  // Complete Indian States and their prominent Cities/Districts
  static const Map<String, List<String>> _statesAndCities = {
    'Andhra Pradesh': [
      'Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool',
      'Rajahmundry', 'Tirupati', 'Kakinada', 'Anantapur', 'Kadapa',
      'Eluru', 'Ongole', 'Vizianagaram', 'Machilipatnam', 'Chittoor', 'Other'
    ],
    'Arunachal Pradesh': [
      'Itanagar', 'Naharlagun', 'Pasighat', 'Tawang', 'Ziro', 'Tezu', 'Other'
    ],
    'Assam': [
      'Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia',
      'Tezpur', 'Barpeta', 'Bongaigaon', 'Dhubri', 'Karimganj', 'Sivasagar', 'Other'
    ],
    'Bihar': [
      'Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga',
      'Bihar Sharif', 'Arrah', 'Begusarai', 'Katihar', 'Munger', 'Chhapra',
      'Bettiah', 'Saharsa', 'Sasaram', 'Hajipur', 'Dehri', 'Siwan', 'Motihari', 'Other'
    ],
    'Chhattisgarh': [
      'Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Rajnandgaon', 'Jagdalpur',
      'Raigarh', 'Ambikapur', 'Durg', 'Dhamtari', 'Mahasamund', 'Other'
    ],
    'Goa': [
      'Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda', 'Bicholim', 'Other'
    ],
    'Gujarat': [
      'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar',
      'Junagadh', 'Gandhinagar', 'Anand', 'Navsari', 'Morbi', 'Nadiad',
      'Surendranagar', 'Bharuch', 'Mehsana', 'Bhuj', 'Porbandar', 'Vapi', 'Valsad', 'Other'
    ],
    'Haryana': [
      'Faridabad', 'Gurgaon', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak',
      'Hisar', 'Karnal', 'Sonipat', 'Panchkula', 'Sirsa', 'Bhiwani',
      'Bahadurgarh', 'Jind', 'Thanesar', 'Kaithal', 'Rewari', 'Palwal', 'Other'
    ],
    'Himachal Pradesh': [
      'Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Kullu', 'Bilaspur',
      'Hamirpur', 'Una', 'Nahan', 'Kangra', 'Chamba', 'Paonta Sahib', 'Other'
    ],
    'Jharkhand': [
      'Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar', 'Phusro',
      'Hazaribagh', 'Giridih', 'Ramgarh', 'Medininagar', 'Chirkunda', 'Other'
    ],
    'Karnataka': [
      'Bengaluru', 'Mysuru', 'Hubballi-Dharwad', 'Mangaluru', 'Belagavi',
      'Kalaburagi', 'Davanagere', 'Ballari', 'Vijayapura', 'Shivamogga',
      'Tumakuru', 'Raichur', 'Bidar', 'Hosapete', 'Hassan', 'Gadag', 'Udupi',
      'Bhadravati', 'Chitradurga', 'Kolar', 'Mandya', 'Chikmagalur', 'Bagalkot', 'Other'
    ],
    'Kerala': [
      'Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Kollam', 'Thrissur',
      'Kannur', 'Alappuzha', 'Kottayam', 'Palakkad', 'Manjeri', 'Thalassery',
      'Ponnani', 'Vatakara', 'Kanhangad', 'Payyanur', 'Malappuram', 'Other'
    ],
    'Madhya Pradesh': [
      'Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas',
      'Satna', 'Ratlam', 'Rewa', 'Katni', 'Singrauli', 'Burhanpur',
      'Khandwa', 'Bhind', 'Chhindwara', 'Guna', 'Shivpuri', 'Vidisha',
      'Chhatarpur', 'Damoh', 'Mandsaur', 'Khargone', 'Neemuch', 'Hoshangabad',
      'Sehore', 'Betul', 'Harda', 'Nagda', 'Other'
    ],
    'Maharashtra': [
      'Mumbai', 'Pune', 'Nagpur', 'Thane', 'Pimpri-Chinchwad', 'Nashik',
      'Kalyan-Dombivli', 'Vasai-Virar', 'Chhatrapati Sambhajinagar', 'Navi Mumbai',
      'Solapur', 'Mira-Bhayandar', 'Bhiwandi', 'Amravati', 'Nanded', 'Kolhapur',
      'Sangli', 'Malegaon', 'Jalgaon', 'Akola', 'Latur', 'Dhule', 'Ahmednagar',
      'Chandrapur', 'Parbhani', 'Ichalkaranji', 'Jalna', 'Panvel', 'Satara', 'Other'
    ],
    'Manipur': [
      'Imphal', 'Thoubal', 'Bishnupur', 'Churachandpur', 'Ukhrul', 'Other'
    ],
    'Meghalaya': [
      'Shillong', 'Tura', 'Nongpoh', 'Jowai', 'Baghmara', 'Other'
    ],
    'Mizoram': [
      'Aizawl', 'Lunglei', 'Saiha', 'Champhai', 'Kolasib', 'Other'
    ],
    'Nagaland': [
      'Kohima', 'Dimapur', 'Mokokchung', 'Tuensang', 'Wokha', 'Other'
    ],
    'Odisha': [
      'Bhubaneswar', 'Cuttack', 'Rourkela', 'Berhampur', 'Sambalpur',
      'Puri', 'Balasore', 'Bhadrak', 'Baripada', 'Jharsuguda', 'Bargarh', 'Other'
    ],
    'Punjab': [
      'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Hoshiarpur',
      'Mohali', 'Batala', 'Pathankot', 'Moga', 'Abohar', 'Malerkotla',
      'Khanna', 'Muktsar', 'Barnala', 'Firozpur', 'Kapurthala', 'Rajpura', 'Other'
    ],
    'Rajasthan': [
      'Jaipur', 'Jodhpur', 'Kota', 'Bikaner', 'Ajmer', 'Udaipur', 'Bhilwara',
      'Alwar', 'Bharatpur', 'Sikar', 'Pali', 'Sri Ganganagar', 'Beawar',
      'Hanumangarh', 'Dholpur', 'Sawai Madhopur', 'Churu', 'Jhunjhunu',
      'Baran', 'Chittorgarh', 'Nagaur', 'Bhiwadi', 'Bundi', 'Other'
    ],
    'Sikkim': [
      'Gangtok', 'Namchi', 'Gyalshing', 'Mangan', 'Other'
    ],
    'Tamil Nadu': [
      'Chennai', 'Coimbatore', 'Madurai', 'Tiruchirappalli', 'Salem',
      'Tiruppur', 'Erode', 'Tirunelveli', 'Vellore', 'Thoothukudi', 'Dindigul',
      'Thanjavur', 'Ranipet', 'Sivakasi', 'Karur', 'Hosur', 'Nagercoil',
      'Kanchipuram', 'Cuddalore', 'Kumbakonam', 'Tiruvannamalai', 'Other'
    ],
    'Telangana': [
      'Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar',
      'Ramagundam', 'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Suryapet',
      'Siddipet', 'Miryalaguda', 'Jagtial', 'Mancherial', 'Other'
    ],
    'Tripura': [
      'Agartala', 'Dharmanagar', 'Udaipur', 'Kailashahar', 'Belonia', 'Other'
    ],
    'Uttar Pradesh': [
      'Lucknow', 'Kanpur', 'Ghaziabad', 'Agra', 'Meerut', 'Varanasi',
      'Prayagraj', 'Bareilly', 'Aligarh', 'Moradabad', 'Saharanpur',
      'Gorakhpur', 'Noida', 'Firozabad', 'Jhansi', 'Muzaffarnagar',
      'Mathura', 'Badaun', 'Rampur', 'Shahjahanpur', 'Farrukhabad',
      'Ayodhya', 'Hapur', 'Etawah', 'Mirzapur', 'Bulandshahr', 'Sambhal',
      'Amroha', 'Hardoi', 'Fatehpur', 'Raebareli', 'Orai', 'Sitapur',
      'Bahraich', 'Unnao', 'Jaunpur', 'Lakhimpur', 'Hathras', 'Banda',
      'Pilibhit', 'Barabanki', 'Gonda', 'Mainpuri', 'Lalitpur', 'Etah',
      'Deoria', 'Basti', 'Ghazipur', 'Sultanpur', 'Azamgarh', 'Bijnor', 'Other'
    ],
    'Uttarakhand': [
      'Dehradun', 'Haridwar', 'Roorkee', 'Haldwani', 'Rudrapur', 'Kashipur',
      'Rishikesh', 'Pithoragarh', 'Ramnagar', 'Kotdwar', 'Mussoorie', 'Other'
    ],
    'West Bengal': [
      'Kolkata', 'Howrah', 'Asansol', 'Siliguri', 'Durgapur', 'Bardhaman',
      'Malda', 'Baharampur', 'Habra', 'Kharagpur', 'Shantipur', 'Dankuni',
      'Haldia', 'Raiganj', 'Krishnanagar', 'Midnapore', 'Jalpaiguri',
      'Balurghat', 'Bankura', 'Darjeeling', 'Other'
    ],
    'Delhi': [
      'Central Delhi', 'East Delhi', 'New Delhi', 'North Delhi', 'North East Delhi',
      'North West Delhi', 'Shahdara', 'South Delhi', 'South East Delhi',
      'South West Delhi', 'West Delhi', 'Other'
    ],
    'Jammu & Kashmir': [
      'Srinagar', 'Jammu', 'Anantnag', 'Baramulla', 'Pulwama', 'Sopore',
      'Kathua', 'Udhampur', 'Rajouri', 'Kupwara', 'Budgam', 'Poonch', 'Other'
    ],
    'Ladakh': [
      'Leh', 'Kargil', 'Other'
    ],
    'Chandigarh': [
      'Chandigarh', 'Other'
    ],
    'Puducherry': [
      'Puducherry', 'Karaikal', 'Mahe', 'Yanam', 'Other'
    ],
  };

  @override
  void initState() {
    super.initState();
    _prefillInitialData();
  }

  void _prefillInitialData() {
    if (widget.name != null && widget.name!.isNotEmpty) {
      final parts = widget.name!.trim().split(' ');
      _firstNameController.text = parts.first;
      if (parts.length > 1) {
        _lastNameController.text = parts.sublist(1).join(' ');
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _pincodeController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _customCityController.dispose();
    super.dispose();
  }

  List<String> get _cityOptions {
    if (_selectedState == null || !_statesAndCities.containsKey(_selectedState)) {
      return ['Other'];
    }
    return _statesAndCities[_selectedState]!;
  }

  void _onStateChanged(String? newState) {
    if (newState == null) return;
    setState(() {
      _selectedState = newState;
      _selectedCity = null;
      _isCustomCity = false;
      _customCityController.clear();
    });
  }

  void _onCityChanged(String? newCity) {
    if (newCity == null) return;
    setState(() {
      _selectedCity = newCity;
      _isCustomCity = (newCity == 'Other');
    });
  }

  Future<void> _fetchPincodeData(String pin) async {
    if (pin.length != 6) return;
    setState(() => _isPinLoading = true);
    try {
      final res = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pin'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOfficeList = data[0]['PostOffice'] as List?;
          if (postOfficeList != null && postOfficeList.isNotEmpty) {
            final po = postOfficeList[0];
            final stateFromApi = po['State']?.toString();
            final districtFromApi = po['District']?.toString();

            if (stateFromApi != null && stateFromApi.isNotEmpty) {
              String? matchedState = _findMatchingState(stateFromApi);
              if (matchedState != null) {
                setState(() {
                  _selectedState = matchedState;
                  final availableCities = _statesAndCities[matchedState] ?? ['Other'];
                  if (districtFromApi != null) {
                    final matchedCity = availableCities.firstWhere(
                      (c) => c.toLowerCase() == districtFromApi.toLowerCase(),
                      orElse: () => 'Other',
                    );
                    _selectedCity = matchedCity;
                    if (matchedCity == 'Other') {
                      _isCustomCity = true;
                      _customCityController.text = districtFromApi;
                    } else {
                      _isCustomCity = false;
                    }
                  }
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('CompleteProfileView: Pincode lookup error: $e');
    } finally {
      if (mounted) setState(() => _isPinLoading = false);
    }
  }

  String? _findMatchingState(String query) {
    final cleanQuery = query.toLowerCase().replaceAll('&', 'and').trim();
    for (final state in _statesAndCities.keys) {
      final cleanState = state.toLowerCase().replaceAll('&', 'and').trim();
      if (cleanState == cleanQuery || cleanState.contains(cleanQuery) || cleanQuery.contains(cleanState)) {
        return state;
      }
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services in device settings')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is required to detect address')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Please enter address manually.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          _pincodeController.text = place.postalCode!;
          await _fetchPincodeData(place.postalCode!);
        }

        final line1Parts = [place.street, place.subLocality]
            .whereType<String>()
            .where((p) => p.isNotEmpty)
            .join(', ');
        if (line1Parts.isNotEmpty && _address1Controller.text.isEmpty) {
          _address1Controller.text = line1Parts;
        }

        if (place.locality != null && place.locality!.isNotEmpty && _address2Controller.text.isEmpty) {
          _address2Controller.text = place.locality!;
        }
      }
    } catch (e) {
      debugPrint('Location detection error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your State from the dropdown'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your City/District from the dropdown'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final finalCity = _isCustomCity
        ? _customCityController.text.trim()
        : _selectedCity!;

    if (finalCity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your City name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
      final email = _emailController.text.trim();
      final pincode = _pincodeController.text.trim();
      final address1 = _address1Controller.text.trim();
      final address2 = _address2Controller.text.trim();
      final state = _selectedState!;
      final phone = widget.phone.replaceAll(RegExp(r'[^\d]'), '');

      // 1. Save locally to AuthController & Preferences
      await AuthController.saveAddress(
        pincode: pincode,
        address1: address1,
        address2: address2,
        city: finalCity,
        state: state,
        firstName: firstName,
        lastName: lastName,
        name: fullName,
        phone: phone,
      );

      await AuthController.setProfileCompleted(true);

      // 2. Sync with Backend API
      String? customerId = widget.customerId ?? await AuthController.getCustomerId();
      if (customerId == null || customerId.isEmpty) {
        final currentCustomer = await ApiService.getCurrentCustomer();
        customerId = (currentCustomer?['_id'] ?? currentCustomer?['id'])?.toString();
      }

      if (customerId != null && customerId.isNotEmpty) {
        final updatePayload = {
          'firstName': firstName,
          'lastName': lastName,
          'name': fullName,
          'email': email,
          'phone': phone,
          'isProfileCompleted': true,
          'isprofilecompleted': true,
          'defaultAddress': {
            'company': '',
            'address1': address1,
            'address2': address2,
            'city': finalCity,
            'province': state,
            'country': 'India',
            'zip': pincode,
            'phone': phone,
          }
        };

        await ApiService.updateCustomer(customerId, updatePayload);

        await ApiService.addAddress(customerId, {
          'name': fullName,
          'address1': address1,
          'address2': address2,
          'city': finalCity,
          'province': state,
          'country': 'India',
          'zip': pincode,
          'phone': phone,
          'isDefault': true,
        });
      }

      // 3. Notify AuthBloc of complete status
      if (mounted) {
        context.read<AuthBloc>().add(const CheckAuthStatusEvent());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Profile completed successfully!'),
              ],
            ),
            backgroundColor: Constants.baseColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Routers.goToHome(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text(
            'Complete Your Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Sign Out',
              icon: Icon(Icons.logout_rounded, size: 20, color: Colors.grey.shade600),
              onPressed: () => _confirmSignOut(context),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Constants.baseColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Constants.baseColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_pin_rounded, color: Constants.baseColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please enter your name & delivery address to start ordering.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Section 1: Personal Details
                  _buildSectionHeader(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Info',
                  ),
                  const SizedBox(height: 8),

                  // First & Last Name
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name *',
                          hint: 'Ramesh',
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          hint: 'Kumar',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Verified Phone & Optional Email
                  Row(
                    children: [
                      Expanded(child: _buildVerifiedPhoneField()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _emailController,
                          label: 'Email (Optional)',
                          hint: 'name@mail.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Section 2: Delivery Address
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.location_on_outlined,
                        title: 'Delivery Address',
                      ),
                      InkWell(
                        onTap: _isFetchingLocation ? null : _useCurrentLocation,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Constants.baseColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Constants.baseColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isFetchingLocation
                                  ? SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Constants.baseColor,
                                      ),
                                    )
                                  : Icon(Icons.my_location_rounded, size: 13, color: Constants.baseColor),
                              const SizedBox(width: 5),
                              Text(
                                AppLocalizations.of(context)?.useCurrentLocation ?? 'Use Current Location',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Constants.baseColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Pincode & State in one row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: _buildTextField(
                          controller: _pincodeController,
                          label: 'Pincode *',
                          hint: '6 digits',
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (val) {
                            if (val.length == 6) {
                              _fetchPincodeData(val);
                            }
                          },
                          suffixIcon: _isPinLoading
                              ? Container(
                                  width: 16,
                                  height: 16,
                                  padding: const EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Constants.baseColor,
                                  ),
                                )
                              : null,
                          validator: (val) {
                            if (val == null || val.trim().length != 6) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStateDropdown(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // City / District Dropdown
                  _buildCityDropdown(),

                  // Custom City field if "Other" is selected
                  if (_isCustomCity) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _customCityController,
                      label: 'Enter City / District Name *',
                      hint: 'Type your town or city name',
                      validator: (val) {
                        if (_isCustomCity && (val == null || val.trim().isEmpty)) {
                          return 'City name is required';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Address Line 1
                  _buildTextField(
                    controller: _address1Controller,
                    label: 'House No., Building, Village or Street *',
                    hint: 'e.g. House 45, Near Mandir, Main Road',
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Address Line 2
                  _buildTextField(
                    controller: _address2Controller,
                    label: 'Area, Landmark, Colony (Optional)',
                    hint: 'e.g. Behind Cooperative Bank',
                  ),

                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.baseColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Save & Continue',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to go back to login?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthController.signOut();
              if (context.mounted) {
                Routers.goToLogin(context);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Constants.baseColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile (Verified)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.phone.startsWith('+91') ? widget.phone : '+91 ${widget.phone}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade600),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: Colors.grey.shade400,
            ),
            counterText: '',
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Constants.baseColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'State *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedState,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Constants.baseColor, width: 1.5),
            ),
          ),
          hint: Text(
            'Select State',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: Colors.grey.shade400,
            ),
          ),
          items: _statesAndCities.keys.map((stateName) {
            return DropdownMenuItem<String>(
              value: stateName,
              child: Text(
                stateName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _onStateChanged,
        ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'City / District *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Constants.baseColor, width: 1.5),
            ),
          ),
          hint: Text(
            _selectedState == null ? 'Select state first' : 'Select City / District',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: Colors.grey.shade400,
            ),
          ),
          items: _cityOptions.map((cityName) {
            return DropdownMenuItem<String>(
              value: cityName,
              child: Text(
                cityName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _selectedState == null ? null : _onCityChanged,
        ),
      ],
    );
  }
}
