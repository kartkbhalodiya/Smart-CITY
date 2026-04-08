import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/app_bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFFFF6B35);
  static const _dark = Color(0xFF1A1A1A);

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadhaarController = TextEditingController();

  String? _selectedState;
  String? _selectedCity;
  String _selectedLanguage = 'en';

  List<String> _states = [];
  List<String> _cities = [];
  Map<String, List<String>> _citiesByState = {};
  bool _loadingStates = true;
  bool _isLoading = false;

  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();

    _fetchStatesCities();
    _loadProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      final user = auth.user;
      _fullNameController.text = user?.fullName ?? '';
      _emailController.text = user?.email ?? '';
      _selectedLanguage = localeProvider.locale.languageCode;
    });
  }

  Future<void> _fetchStatesCities() async {
    setState(() => _loadingStates = true);
    try {
      final response =
          await ApiService.get(ApiConfig.statesCities, includeAuth: false);
      if (!mounted || response['success'] != true) return;

      final payload = (response['data'] is Map<String, dynamic>)
          ? response['data'] as Map<String, dynamic>
          : response;

      final rawStates = (payload['states'] as List?) ?? [];
      final parsedStates = rawStates
          .map((item) => item.toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final rawCitiesByState = payload['cities_by_state'];
      final parsedCitiesByState = <String, List<String>>{};
      if (rawCitiesByState is Map) {
        for (final entry in rawCitiesByState.entries) {
          final stateName = entry.key.toString().trim();
          final value = entry.value;
          if (stateName.isEmpty || value is! List) continue;
          parsedCitiesByState[stateName] = value
              .map((city) => city.toString().trim())
              .where((city) => city.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
        }
      }

      setState(() {
        _states = parsedStates;
        _citiesByState = parsedCitiesByState;
        if (_selectedState != null) {
          _cities = _citiesByState[_selectedState!] ?? [];
          if (_selectedCity != null && !_cities.contains(_selectedCity)) {
            _selectedCity = null;
          }
        }
      });
    } finally {
      if (mounted) setState(() => _loadingStates = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService.get(ApiConfig.userProfile);
      if (!mounted || response['success'] != true) return;

      final payload = (response['data'] is Map<String, dynamic>)
          ? response['data'] as Map<String, dynamic>
          : response;
      final profile = payload['profile'];
      if (profile is! Map<String, dynamic>) return;
      final user = profile['user'] is Map<String, dynamic>
          ? profile['user'] as Map<String, dynamic>
          : const <String, dynamic>{};

      String clean(dynamic value) {
        final text = (value ?? '').toString().trim();
        if (text.toLowerCase() == 'not provided' ||
            text.toLowerCase() == 'not specified' ||
            text.toLowerCase() == 'null' ||
            text.toLowerCase() == 'none') {
          return '';
        }
        return text;
      }

      final serverState = clean(profile['state']);
      final serverCity = clean(profile['city']);
      final firstName = clean(user['first_name']);
      final lastName = clean(user['last_name']);
      final fullName = '$firstName $lastName'.trim();

      setState(() {
        _fullNameController.text = fullName;
        _emailController.text = clean(user['email']);
        _mobileController.text = clean(profile['mobile_no']);
        _addressController.text = clean(profile['address']);
        _aadhaarController.text = clean(profile['aadhaar_number']);
        _selectedState = serverState.isEmpty ? null : serverState;
        _selectedCity = serverCity.isEmpty ? null : serverCity;
        if (_selectedState != null) {
          _cities = _citiesByState[_selectedState!] ?? [];
          if (_selectedCity != null && !_cities.contains(_selectedCity)) {
            _selectedCity = null;
          }
        }
      });
    } catch (_) {
      // Keep form usable even if profile fetch fails.
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Consumer<AuthProvider>(builder: (context, auth, _) {
                  final user = auth.user;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSummaryCard(user),
                        const SizedBox(height: 16),
                        _buildSectionContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(
                                  AppStrings.t(context, 'Personal Information'),
                                  Icons.person),
                              const SizedBox(height: 16),
                              _inputField(
                                  AppStrings.t(context, 'Full Name'),
                                  Icons.person,
                                  _fullNameController,
                                  TextInputType.name),
                              const SizedBox(height: 14),
                              _inputField(
                                  AppStrings.t(context, 'Email'),
                                  Icons.email,
                                  _emailController,
                                  TextInputType.emailAddress),
                              const SizedBox(height: 14),
                              _inputField(
                                  AppStrings.t(context, 'Mobile'),
                                  Icons.phone_android,
                                  _mobileController,
                                  TextInputType.phone),
                              const SizedBox(height: 14),
                              _dropdownMap(
                                AppStrings.t(context, 'State'),
                                Icons.map,
                                _states,
                                _selectedState,
                                (v) {
                                  setState(() {
                                    _selectedState = v;
                                    _selectedCity = null;
                                    _cities = v == null ? [] : (_citiesByState[v] ?? []);
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              _dropdownMap(
                                AppStrings.t(context, 'City'),
                                Icons.location_city,
                                _cities,
                                _selectedCity,
                                (v) => setState(() => _selectedCity = v),
                              ),
                              const SizedBox(height: 14),
                              _textAreaField(AppStrings.t(context, 'Address'),
                                  Icons.home, _addressController),
                              const SizedBox(height: 14),
                              _inputField(
                                  AppStrings.t(
                                      context, 'Aadhaar Number (Optional)'),
                                  Icons.credit_card,
                                  _aadhaarController,
                                  TextInputType.number),
                              const SizedBox(height: 14),
                              _infoField(
                                  AppStrings.t(context, 'Member Since'),
                                  Icons.calendar_today,
                                  user?.email != null ? 'Jan 15, 2024' : 'N/A'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(
                                  AppStrings.t(context, 'Language Settings'),
                                  Icons.language),
                              const SizedBox(height: 16),
                              _languageSelector(),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(child: _saveButton()),
                                  const SizedBox(width: 10),
                                  Expanded(child: _logoutButton(auth)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Center(
                                child: Text(
                                  AppStrings.t(
                                      context, 'Designed by Kartik Bhalodiya.'),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748b),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              AppStrings.t(context, 'Profile'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileSummaryCard(user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 30, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'User Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'user@example.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'CITIZEN',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFB088),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
        ),
      ],
    );
  }

  Widget _inputField(String label, IconData icon, TextEditingController controller,
      TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: _accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECECEC), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: GoogleFonts.inter(fontSize: 13, color: _dark),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _textAreaField(
      String label, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: _accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECECEC), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 13, color: _dark),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdownMap(String label, IconData icon, List<String> items,
      String? value, ValueChanged<String?> onChanged) {
    final isStateDropdown = label == AppStrings.t(context, 'State');
    final isLoading = isStateDropdown && _loadingStates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: _accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECECEC), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              hint: Text(
                isLoading
                    ? AppStrings.t(context, 'Loading...')
                    : '${AppStrings.t(context, 'Select ')}$label',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF64748b)),
              ),
              isExpanded: true,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: Color(0xFF64748b)),
              style: GoogleFonts.inter(
                  fontSize: 13, color: _dark, fontWeight: FontWeight.w500),
              dropdownColor: Colors.white,
              items: items
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (items.isEmpty || isLoading) ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoField(String label, IconData icon, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: _accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECECEC), width: 1.5),
          ),
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13, color: _dark, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _languageSelector() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EB).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.25), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _accent),
          style: GoogleFonts.inter(
              fontSize: 13, color: _dark, fontWeight: FontWeight.w500),
          dropdownColor: Colors.white,
          items: [
            DropdownMenuItem(
                value: 'en', child: Text(AppStrings.t(context, 'English'))),
            DropdownMenuItem(
                value: 'hi', child: Text(AppStrings.t(context, 'Hindi'))),
            DropdownMenuItem(
                value: 'gu', child: Text(AppStrings.t(context, 'Gujarati'))),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => _selectedLanguage = value);
            await localeProvider.setLocale(value);
          },
        ),
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _saveProfile,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A1A), Color(0xFFFF6B35)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: const Color(0x331A1A1A),
                blurRadius: 16,
                offset: const Offset(0, 8))
          ],
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppStrings.t(context, 'SAVE'),
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ],
              ),
      ),
    );
  }

  Widget _logoutButton(auth) {
    return GestureDetector(
      onTap: () async {
        await auth.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFfecaca), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 16, color: Color(0xFFdc2626)),
            const SizedBox(width: 8),
            Text(AppStrings.t(context, 'LOGOUT'),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFdc2626),
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Map<String, String> _splitName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return {'first': '', 'last': ''};
    if (parts.length == 1) return {'first': parts.first, 'last': ''};
    return {'first': parts.first, 'last': parts.sublist(1).join(' ')};
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final names = _splitName(_fullNameController.text);
      final body = {
        'first_name': names['first'] ?? '',
        'last_name': names['last'] ?? '',
        'email': _emailController.text.trim(),
        'surname': names['last'] ?? '',
        'mobile_no': _mobileController.text.trim(),
        'state': (_selectedState ?? '').trim(),
        'district': '',
        'city': (_selectedCity ?? '').trim(),
        'address': _addressController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim(),
      };

      final response = await ApiService.put(ApiConfig.userProfile, body);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response['success'] == true) {
        // Sync local auth user with the new profile data (which now includes user and mobile/aadhaar)
        final profileData = response['profile'];
        if (profileData != null) {
          // User.fromJson can now handle this full profile object correctly
          await StorageService.saveUserData(jsonEncode(profileData));
        }
        await Provider.of<AuthProvider>(context, listen: false).loadUser();
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppStrings.t(context, 'Profile updated successfully!')),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ??
                AppStrings.t(context, 'Unable to save profile')),
            backgroundColor: const Color(0xFFE74C3C),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.t(context, 'Network error, try again')),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
