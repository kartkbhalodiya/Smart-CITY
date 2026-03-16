import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadhaarController = TextEditingController();
  
  String? _selectedState;
  String? _selectedCity;
  String _selectedLanguage = 'English';
  
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  bool _loadingStates = true;
  bool _isLoading = false;
  
  late AnimationController _ac;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();
    
    _fetchStatesCities();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      _fullNameController.text = user?.fullName ?? '';
      _emailController.text = user?.email ?? '';
    });
  }
  
  Future<void> _fetchStatesCities() async {
    setState(() => _loadingStates = true);
    try {
      final response = await ApiService.get(ApiConfig.statesCities, includeAuth: false);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _states = List<Map<String, dynamic>>.from(response['data']['states'] ?? []);
          _loadingStates = false;
        });
      } else {
        setState(() => _loadingStates = false);
      }
    } catch (e) {
      setState(() => _loadingStates = false);
    }
  }
  
  Future<void> _fetchCities(String stateId) async {
    try {
      final response = await ApiService.get('${ApiConfig.statesCities}?state_id=$stateId', includeAuth: false);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _cities = List<Map<String, dynamic>>.from(response['data']['cities'] ?? []);
        });
      }
    } catch (e) {
      // Handle error
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
      body: Stack(children: [
        // Background image
        Positioned.fill(
          child: Image.network(
            'https://res.cloudinary.com/dk1q50evg/image/upload/login-bg-mobile',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
              ),
            ),
          ),
        ),
        // Blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E66F5).withOpacity(0.2),
                    const Color(0xFF667EEA).withOpacity(0.15),
                    const Color(0xFF764BA2).withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: SlideTransition(
            position: _slide,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
              ),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: Colors.white.withOpacity(0.4),
                    child: Consumer<AuthProvider>(builder: (context, auth, _) {
                      final user = auth.user;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Back button
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF1E66F5).withOpacity(0.2), width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_back, size: 16, color: Color(0xFF1E66F5)),
                                      const SizedBox(width: 6),
                                      Text('Back', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E66F5))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                                // Header
                                _buildHeader(user),
                                const SizedBox(height: 25),
                                
                                // Personal Information Section
                                _sectionTitle('Personal Information', Icons.person),
                                const SizedBox(height: 16),
                                _inputField('Full Name', Icons.person, _fullNameController, TextInputType.name),
                                const SizedBox(height: 14),
                                _inputField('Email', Icons.email, _emailController, TextInputType.emailAddress),
                                const SizedBox(height: 14),
                                _inputField('Mobile', Icons.phone_android, _mobileController, TextInputType.phone),
                                const SizedBox(height: 14),
                                _dropdownMap('State', Icons.map, _states, _selectedState, (v) {
                                  setState(() {
                                    _selectedState = v;
                                    _selectedCity = null;
                                    _cities = [];
                                  });
                                  if (v != null) _fetchCities(v);
                                }),
                                const SizedBox(height: 14),
                                _dropdownMap('City', Icons.location_city, _cities, _selectedCity, (v) {
                                  setState(() => _selectedCity = v);
                                }),
                                const SizedBox(height: 14),
                                _textAreaField('Address', Icons.home, _addressController),
                                const SizedBox(height: 14),
                                _inputField('Aadhaar Number (Optional)', Icons.credit_card, _aadhaarController, TextInputType.number),
                                const SizedBox(height: 14),
                                _infoField('Member Since', Icons.calendar_today, user?.email != null ? 'Jan 15, 2024' : 'N/A'),
                                
                                // Language Settings Section
                                const SizedBox(height: 24),
                                _sectionTitle('Language Settings', Icons.language),
                                const SizedBox(height: 16),
                                _languageSelector(),
                                
                                // Buttons
                                const SizedBox(height: 24),
                                Row(children: [
                                  Expanded(child: _saveButton()),
                                  const SizedBox(width: 10),
                                  Expanded(child: _logoutButton(auth)),
                                ]),
                                
                            // Footer
                            const SizedBox(height: 16),
                            Text(
                              'Designed by Kartik Bhalodiya.',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748b), fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(user) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E66F5), Color(0xFF154ec7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: const Color(0x401E66F5), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.person, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 15),
        // Name
        Text(
          user?.fullName ?? 'User Name',
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a)),
        ),
        const SizedBox(height: 6),
        // Email
        Text(
          user?.email ?? 'user@example.com',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
        ),
        const SizedBox(height: 8),
        // Role Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E66F5), Color(0xFF154ec7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0x331E66F5), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Text(
            'CITIZEN',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1E66F5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0f172a)),
        ),
      ],
    );
  }

  Widget _inputField(String label, IconData icon, TextEditingController controller, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: const Color(0xFF1E66F5)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a)),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _textAreaField(String label, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: const Color(0xFF1E66F5)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a)),
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

  Widget _dropdownMap(String label, IconData icon, List<Map<String, dynamic>> items, String? value, ValueChanged<String?> onChanged) {
    // Find the selected item name
    String? displayValue;
    if (value != null) {
      final selectedItem = items.firstWhere(
        (item) => item['id'].toString() == value,
        orElse: () => {},
      );
      displayValue = selectedItem['name'];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: const Color(0xFF1E66F5)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.any((item) => item['id'].toString() == value) ? value : null,
              hint: Text('Select $label', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF64748b)),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a), fontWeight: FontWeight.w500),
              dropdownColor: Colors.white,
              items: items.isEmpty
                  ? null
                  : items.map((item) => DropdownMenuItem(
                      value: item['id'].toString(),
                      child: Text(item['name'] ?? ''),
                    )).toList(),
              onChanged: items.isEmpty ? null : onChanged,
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
            Icon(icon, size: 11, color: const Color(0xFF1E66F5)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
          ),
          child: Text(value, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a), fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _languageSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFeff6ff).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E66F5).withOpacity(0.15), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF1E66F5)),
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0f172a), fontWeight: FontWeight.w500),
          dropdownColor: Colors.white,
          items: ['English', 'हिंदी (Hindi)', 'ગુજરાતી (Gujarati)']
              .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
              .toList(),
          onChanged: (value) => setState(() => _selectedLanguage = value!),
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
            colors: [Color(0xFF1E66F5), Color(0xFF154ec7)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0x331E66F5), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: _isLoading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('SAVE', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
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
            Text('LOGOUT', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFdc2626), letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile updated successfully!'),
        backgroundColor: const Color(0xFF2ECC71),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


}