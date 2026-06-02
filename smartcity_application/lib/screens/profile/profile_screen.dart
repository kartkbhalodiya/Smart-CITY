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
  static const _accent = Color(0xFF2F80ED);
  static const _dark = Color(0xFF0B1020);
  static const _textMuted = Color(0xFFA3A7B4);

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
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();

    _fetchStatesCities();
    _loadProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final localeProvider =
          Provider.of<LocaleProvider>(context, listen: false);
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
      backgroundColor: const Color(0xFFF7F8FA),
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
                                    _cities = v == null
                                        ? []
                                        : (_citiesByState[v] ?? []);
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
                const Icon(Icons.arrow_back_rounded, color: Color(0xFF0B1020)),
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
          colors: [Color(0xFF0B1020), Color(0xFF2F80ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1020).withValues(alpha: 0.22),
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
                      color: const Color(0xFF5BC7FF),
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

  Widget _inputField(String label, IconData icon,
      TextEditingController controller, TextInputType type) {
    return _fieldShell(
      child: TextField(
        controller: controller,
        keyboardType: type,
        cursorColor: _dark,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _dark,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textMuted,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF8B90A0), size: 22),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _fieldShell({required Widget child, double radius = 20}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.35,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }

  Widget _textAreaField(
      String label, IconData icon, TextEditingController controller) {
    return _fieldShell(
      child: TextField(
        controller: controller,
        maxLines: 3,
        cursorColor: _dark,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _dark,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _textMuted,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: Icon(icon, color: const Color(0xFF8B90A0), size: 22),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        ),
      ),
    );
  }

  Widget _dropdownMap(String label, IconData icon, List<String> items,
      String? value, ValueChanged<String?> onChanged) {
    final isStateDropdown = label == AppStrings.t(context, 'State');
    final isLoading = isStateDropdown && _loadingStates;

    return _fieldShell(
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF8B90A0), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    hint: Text(
                      isLoading
                          ? AppStrings.t(context, 'Loading...')
                          : '${AppStrings.t(context, 'Select ')}$label',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textMuted,
                      ),
                    ),
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(18),
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 21,
                            color: _dark,
                          ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _dark,
                      fontWeight: FontWeight.w700,
                    ),
                    dropdownColor: Colors.white,
                    items: items
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (items.isEmpty || isLoading) ? null : onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoField(String label, IconData icon, String value) {
    return _fieldShell(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        color: Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF8B90A0), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: _textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: _dark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageSelector() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    return _fieldShell(
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.language_rounded,
                  color: Color(0xFF8B90A0), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(18),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 21, color: _dark),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _dark,
                      fontWeight: FontWeight.w700,
                    ),
                    dropdownColor: Colors.white,
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(AppStrings.t(context, 'English')),
                      ),
                      DropdownMenuItem(
                        value: 'hi',
                        child: Text(AppStrings.t(context, 'Hindi')),
                      ),
                      DropdownMenuItem(
                        value: 'gu',
                        child: Text(AppStrings.t(context, 'Gujarati')),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedLanguage = value);
                      await localeProvider.setLocale(value);
                    },
                  ),
                ),
              ),
            ],
          ),
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
            colors: [Color(0xFF0B1020), Color(0xFF2F80ED)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Color(0x331A1A1A), blurRadius: 16, offset: Offset(0, 8))
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
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (_) => false);
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final successMessage =
        AppStrings.t(context, 'Profile updated successfully!');
    final unableMessage = AppStrings.t(context, 'Unable to save profile');
    final networkMessage = AppStrings.t(context, 'Network error, try again');

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
        if (!mounted) return;
        await authProvider.loadUser();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ?? unableMessage),
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
          content: Text(networkMessage),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
