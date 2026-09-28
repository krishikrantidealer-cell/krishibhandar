import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../controller/auth_controller.dart';
import '../home_view.dart';

class CompleteProfileView extends StatefulWidget {
  final String? phone;
  final bool isFromLogin;
  final bool isEditing;
  final bool canSkip;

  const CompleteProfileView({
    super.key,
    this.phone,
    this.isFromLogin = false,
    this.isEditing = false,
    this.canSkip = false,
  });

  @override
  State<CompleteProfileView> createState() => _CompleteProfileViewState();
}

class _CompleteProfileViewState extends State<CompleteProfileView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _pincodeController;
  late TextEditingController _cityController;

  String? _selectedState;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  bool _isPinLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const List<String> _indianStates = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    "Delhi",
    "Jammu and Kashmir",
    "Ladakh",
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();

    final currentName = AuthController.currentName;
    final displayName = (currentName != null &&
            currentName.toLowerCase() != "krishi farmer" &&
            currentName.toLowerCase() != "krishi customer")
        ? currentName
        : "";
    _nameController = TextEditingController(text: displayName);
    _addressController = TextEditingController();
    _pincodeController = TextEditingController();
    _cityController = TextEditingController();

    _loadExistingAddress();
  }

  Future<void> _loadExistingAddress() async {
    final addr = await AuthController.getSavedAddress();
    if (addr.isNotEmpty && mounted) {
      setState(() {
        if (_addressController.text.isEmpty) {
          _addressController.text = addr['address1'] ?? addr['address2'] ?? '';
        }
        if (_pincodeController.text.isEmpty) {
          _pincodeController.text = addr['pincode'] ?? '';
        }
        if (_cityController.text.isEmpty) {
          _cityController.text = addr['city'] ?? '';
        }
        if (_selectedState == null && addr['state'] != null && addr['state']!.isNotEmpty) {
          _selectedState = _matchState(addr['state']!);
        }
      });
    }
  }

  String? _matchState(String stateName) {
    final clean = stateName.trim().toLowerCase();
    for (var s in _indianStates) {
      if (s.toLowerCase() == clean || clean.contains(s.toLowerCase()) || s.toLowerCase().contains(clean)) {
        return s;
      }
    }
    return _indianStates.contains(stateName.trim()) ? stateName.trim() : null;
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String get _displayPhone {
    if (widget.phone != null && widget.phone!.isNotEmpty) return widget.phone!;
    return AuthController.currentPhone ?? "";
  }

  Future<void> _fetchPincodeData(String pincode) async {
    if (pincode.length != 6) return;
    setState(() => _isPinLoading = true);
    try {
      final res = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List && data.isNotEmpty) {
          final postOffice = data[0];
          if (postOffice['Status'] == 'Success' &&
              postOffice['PostOffice'] != null &&
              (postOffice['PostOffice'] as List).isNotEmpty) {
            final po = postOffice['PostOffice'][0];
            if (mounted) {
              setState(() {
                final district = po['District']?.toString() ?? '';
                final state = po['State']?.toString() ?? '';
                if (district.isNotEmpty && _cityController.text.isEmpty) {
                  _cityController.text = district;
                }
                if (state.isNotEmpty) {
                  _selectedState = _matchState(state) ?? _selectedState;
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Pincode fetch error: $e');
    } finally {
      if (mounted) setState(() => _isPinLoading = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _isFetchingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationSnackBar("Location services disabled. Please enable GPS.", isError: true);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationSnackBar("Location permission denied.", isError: true);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationSnackBar("Location permissions permanently denied.", isError: true);
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;

        setState(() {
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            _pincodeController.text = place.postalCode!;
          }

          final locality = place.locality ?? place.subAdministrativeArea ?? place.subLocality ?? '';
          if (locality.isNotEmpty) {
            _cityController.text = locality;
          }

          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            _selectedState = _matchState(place.administrativeArea!);
          }

          final streetParts = [
            place.street,
            place.subLocality,
            place.thoroughfare,
          ].where((s) => s != null && s.isNotEmpty && s != place.postalCode).toSet().toList();

          if (streetParts.isNotEmpty && _addressController.text.isEmpty) {
            _addressController.text = streetParts.join(', ');
          }
        });

        _showLocationSnackBar(
          "Auto-detected: ${_cityController.text.isNotEmpty ? '${_cityController.text}, ' : ''}${_selectedState ?? 'Location'}",
          isError: false,
        );
      }
    } catch (e) {
      debugPrint("Auto location error: $e");
      if (mounted) {
        _showLocationSnackBar("Could not fetch location. Please enter manually.", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _showLocationSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.location_off_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleSaveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedState == null || _selectedState!.isEmpty) {
      _showLocationSnackBar("Please select your State", isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final phone = _displayPhone;
      final address = _addressController.text.trim();
      final pincode = _pincodeController.text.trim();
      final city = _cityController.text.trim();
      final state = _selectedState!;

      // 1. Save customer name & sync profile
      await AuthController.updateCustomerName(name);
      await AuthController.syncCustomer(phone, name);

      // 2. Save primary address for instant delivery calculation & orders
      await AuthController.saveAddress(
        pincode: pincode,
        address1: address,
        address2: '',
        city: city,
        state: state,
        name: name,
        phone: phone,
      );

      // 3. Mark profile as completed
      await AuthController.setProfileCompleted(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? "Profile updated successfully!"
                  : "Welcome, $name! 🌱 Profile complete.",
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        if (widget.isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MyHomePage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("CompleteProfile: Save error: $e");
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MyHomePage()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: widget.isEditing
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1E293B), size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          widget.isEditing ? "Edit Delivery Profile" : "Complete Profile",
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_displayPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 4),
                      Text(
                        "+91 $_displayPhone",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // --- Main Scrollable Form Body ---
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [


                              // --- Section 1: Farmer Profile ---
                              _buildSectionTitle("Personal Details", Icons.person_rounded),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel("Farmer Full Name *"),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _nameController,
                                      textCapitalization: TextCapitalization.words,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      decoration: _buildInputDecoration(
                                        hintText: "e.g. Ramesh Kumar",
                                        prefixIcon: Icons.person_outline_rounded,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return "Please enter your full name";
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // --- Section 2: Delivery Location ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildSectionTitle("Delivery Address", Icons.location_on_rounded),
                                  InkWell(
                                    onTap: _isFetchingLocation ? null : _fetchCurrentLocation,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_isFetchingLocation)
                                            const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                color: Color(0xFF2E7D32),
                                              ),
                                            )
                                          else
                                            const Icon(
                                              Icons.my_location_rounded,
                                              size: 13,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isFetchingLocation ? "Locating..." : "Auto Detect GPS",
                                            style: GoogleFonts.outfit(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Street / Village
                                    _buildLabel("House No. / Village / Street / Landmark *"),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _addressController,
                                      textCapitalization: TextCapitalization.words,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      decoration: _buildInputDecoration(
                                        hintText: "Enter house, street, landmark or village",
                                        prefixIcon: Icons.home_outlined,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return "Please enter your street or village address";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Pincode & City (Spacious 2-column)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Pincode
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildLabel("Pincode (6 Digits) *"),
                                              const SizedBox(height: 6),
                                              TextFormField(
                                                controller: _pincodeController,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(6),
                                                ],
                                                onChanged: (v) {
                                                  if (v.length == 6) {
                                                    _fetchPincodeData(v);
                                                  }
                                                },
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.0,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                decoration: _buildInputDecoration(
                                                  hintText: "e.g. 560038",
                                                  prefixIcon: Icons.pin_drop_outlined,
                                                  suffixWidget: _isPinLoading
                                                      ? const Padding(
                                                          padding: EdgeInsets.all(12),
                                                          child: SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                validator: (v) {
                                                  if (v == null || v.trim().length != 6) {
                                                    return "6 digits";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // City / District
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildLabel("City / District *"),
                                              const SizedBox(height: 6),
                                              TextFormField(
                                                controller: _cityController,
                                                textCapitalization: TextCapitalization.words,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                                decoration: _buildInputDecoration(
                                                  hintText: "City / Tehsil",
                                                  prefixIcon: Icons.location_city_outlined,
                                                ),
                                                validator: (v) {
                                                  if (v == null || v.trim().isEmpty) {
                                                    return "Enter city";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // State Dropdown
                                    _buildLabel("State *"),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedState,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2E7D32)),
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      decoration: _buildInputDecoration(
                                        hintText: "Select State",
                                        prefixIcon: Icons.map_outlined,
                                      ),
                                      items: _indianStates.map((state) {
                                        return DropdownMenuItem<String>(
                                          value: state,
                                          child: Text(state, overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() => _selectedState = val);
                                      },
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return "Please select your state";
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- Sticky Bottom Action Bar ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        top: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2E7D32),
                                    Color(0xFF1B5E20),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _handleSaveProfile,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            widget.isEditing ? "Update Delivery Address" : "Save & Start Shopping",
                                            style: GoogleFonts.outfit(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, size: 16),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "256-bit Encrypted • Direct Brand Dispatch",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF334155),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(
        color: const Color(0xFF94A3B8),
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
      ),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF2E7D32), size: 18),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.8),
      ),
    );
  }
}
