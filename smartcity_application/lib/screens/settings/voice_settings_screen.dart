import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/voice_config_service.dart';
import '../../services/speech_service.dart';

class VoiceSettingsScreen extends StatefulWidget {
  @override
  _VoiceSettingsScreenState createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final SpeechService _speechService = SpeechService();
  Map<String, dynamic> _currentConfig = {};
  String _selectedPersonality = 'maya_caring';
  String _selectedQuality = 'balanced';
  bool _isElevenLabsEnabled = false;
  bool _isTesting = false;
  
  // Voice parameter sliders
  double _stability = 0.8;
  double _similarityBoost = 0.8;
  double _style = 0.5;
  bool _useSpeakerBoost = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final config = await VoiceConfigService.getVoiceConfig();
    final isEnabled = await VoiceConfigService.isElevenLabsEnabled();
    
    setState(() {
      _currentConfig = config;
      _isElevenLabsEnabled = isEnabled;
      _stability = config['stability']?.toDouble() ?? 0.8;
      _similarityBoost = config['similarity_boost']?.toDouble() ?? 0.8;
      _style = config['style']?.toDouble() ?? 0.5;
      _useSpeakerBoost = config['use_speaker_boost'] ?? true;
    });
  }

  Future<void> _testVoice() async {
    setState(() => _isTesting = true);
    
    try {
      await _speechService.speak(
        VoiceConfigService.getTestPhrase(),
        mood: 'happy'
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice test failed: $e')),
      );
    }
    
    setState(() => _isTesting = false);
  }

  Future<void> _saveSettings() async {
    await VoiceConfigService.updateVoiceSettings(
      stability: _stability,
      similarityBoost: _similarityBoost,
      style: _style,
      useSpeakerBoost: _useSpeakerBoost,
    );
    
    await VoiceConfigService.setVoicePersonality(_selectedPersonality);
    await VoiceConfigService.setQualityPreset(_selectedQuality);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Voice Settings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0f172a),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0f172a)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E66F5),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVoiceProviderSection(),
            const SizedBox(height: 24),
            if (_isElevenLabsEnabled) ...[
              _buildPersonalitySection(),
              const SizedBox(height: 24),
              _buildQualitySection(),
              const SizedBox(height: 24),
              _buildAdvancedSettings(),
              const SizedBox(height: 24),
            ],
            _buildTestSection(),
            const SizedBox(height: 24),
            _buildResetSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceProviderSection() {
    return _buildSection(
      title: 'Voice Provider',
      icon: Icons.record_voice_over,
      child: Column(
        children: [
          _buildProviderTile(
            title: 'ElevenLabs AI Voice',
            subtitle: 'Premium human-like voice synthesis',
            value: 'elevenlabs',
            isSelected: _isElevenLabsEnabled,
            onTap: () => _showApiKeyDialog(),
          ),
          const SizedBox(height: 12),
          _buildProviderTile(
            title: 'Flutter TTS',
            subtitle: 'Built-in text-to-speech engine',
            value: 'flutter_tts',
            isSelected: !_isElevenLabsEnabled,
            onTap: () async {
              await VoiceConfigService.setVoiceProvider('flutter_tts');
              _loadCurrentConfig();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalitySection() {
    return _buildSection(
      title: 'Voice Personality',
      icon: Icons.psychology,
      child: Column(
        children: VoiceConfigService.getAvailableVoices().map((voice) {
          return _buildPersonalityTile(voice);
        }).toList(),
      ),
    );
  }

  Widget _buildPersonalityTile(Map<String, dynamic> voice) {
    final isSelected = _selectedPersonality == voice['key'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E66F5).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E66F5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        title: Text(
          voice['name'],
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0f172a),
          ),
        ),
        subtitle: Text(
          voice['description'],
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748b),
          ),
        ),
        trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFF1E66F5))
          : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1)),
        onTap: () {
          setState(() => _selectedPersonality = voice['key']);
        },
      ),
    );
  }

  Widget _buildQualitySection() {
    return _buildSection(
      title: 'Voice Quality',
      icon: Icons.high_quality,
      child: Column(
        children: [
          _buildQualityTile('High Quality', 'Best quality, slower generation', 'high_quality'),
          _buildQualityTile('Balanced', 'Good quality, moderate speed', 'balanced'),
          _buildQualityTile('Fast', 'Lower quality, fastest generation', 'fast'),
        ],
      ),
    );
  }

  Widget _buildQualityTile(String title, String subtitle, String value) {
    final isSelected = _selectedQuality == value;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E66F5).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E66F5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 13)),
        trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFF1E66F5))
          : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1)),
        onTap: () => setState(() => _selectedQuality = value),
      ),
    );
  }

  Widget _buildAdvancedSettings() {
    return _buildSection(
      title: 'Advanced Voice Settings',
      icon: Icons.tune,
      child: Column(
        children: [
          _buildSlider(
            'Voice Stability',
            'Higher values make voice more consistent',
            _stability,
            (value) => setState(() => _stability = value),
          ),
          _buildSlider(
            'Similarity Boost',
            'Higher values make voice more similar to original',
            _similarityBoost,
            (value) => setState(() => _similarityBoost = value),
          ),
          _buildSlider(
            'Style Exaggeration',
            'Higher values make voice more expressive',
            _style,
            (value) => setState(() => _style = value),
          ),
          SwitchListTile(
            title: Text('Speaker Boost', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            subtitle: Text('Enhance voice clarity and volume', style: GoogleFonts.inter(fontSize: 13)),
            value: _useSpeakerBoost,
            onChanged: (value) => setState(() => _useSpeakerBoost = value),
            activeColor: const Color(0xFF1E66F5),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String title, String subtitle, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b))),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF1E66F5),
          inactiveColor: const Color(0xFFE2E8F0),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTestSection() {
    return _buildSection(
      title: 'Test Voice',
      icon: Icons.play_circle,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              VoiceConfigService.getTestPhrase(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748b),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _testVoice,
              icon: _isTesting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow),
              label: Text(_isTesting ? 'Testing...' : 'Test Voice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSection() {
    return _buildSection(
      title: 'Reset Settings',
      icon: Icons.restore,
      child: Column(
        children: [
          Text(
            'Reset all voice settings to default values',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748b),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showResetDialog(),
              icon: const Icon(Icons.restore, color: Color(0xFFEF4444)),
              label: const Text('Reset to Defaults'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1E66F5), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0f172a),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildProviderTile({
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E66F5).withOpacity(0.1) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E66F5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 13)),
        trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFF1E66F5))
          : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1)),
        onTap: onTap,
      ),
    );
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ElevenLabs API Key', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your ElevenLabs API key to enable premium voice synthesis.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await VoiceConfigService.setElevenLabsApiKey(controller.text);
                await VoiceConfigService.setVoiceProvider('elevenlabs');
                _loadCurrentConfig();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to reset all voice settings to default values?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await VoiceConfigService.resetToDefaults();
              _loadCurrentConfig();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}