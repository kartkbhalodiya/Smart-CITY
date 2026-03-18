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
  final TextEditingController _customVoiceIdController =
      TextEditingController();
  Map<String, dynamic> _currentConfig = {};
  String _selectedPersonality = 'janhelp_caring';
  String _selectedQuality = 'balanced';
  bool _isElevenLabsSelected = false;
  bool _isElevenLabsReady = false;
  bool _isTesting = false;
  bool _isSaving = false;

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

  @override
  void dispose() {
    _customVoiceIdController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    final config = await VoiceConfigService.getVoiceConfig();
    var provider = (config['provider']?.toString() ?? 'elevenlabs').trim();
    if (provider != 'elevenlabs') {
      await VoiceConfigService.setVoiceProvider('elevenlabs');
      config['provider'] = 'elevenlabs';
      provider = 'elevenlabs';
    }
    final apiKey = await VoiceConfigService.getElevenLabsApiKey();
    final isReady = provider == 'elevenlabs' &&
        apiKey != null &&
        apiKey.trim().isNotEmpty &&
        apiKey.trim() != 'YOUR_ELEVENLABS_API_KEY';
    final configuredVoiceId = config['voice_id']?.toString() ?? '';

    setState(() {
      _currentConfig = config;
      _isElevenLabsSelected = provider == 'elevenlabs';
      _isElevenLabsReady = isReady;
      _stability = config['stability']?.toDouble() ?? 0.8;
      _similarityBoost = config['similarity_boost']?.toDouble() ?? 0.8;
      _style = config['style']?.toDouble() ?? 0.5;
      _useSpeakerBoost = config['use_speaker_boost'] ?? true;
    });

    if (_customVoiceIdController.text != configuredVoiceId) {
      _customVoiceIdController.text = configuredVoiceId;
    }
  }

  Future<void> _testVoice() async {
    setState(() => _isTesting = true);

    try {
      await _speechService.speak(VoiceConfigService.getTestPhrase(),
          mood: 'happy');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice test failed: $e')),
      );
    }

    setState(() => _isTesting = false);
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await VoiceConfigService.updateVoiceSettings(
        stability: _stability,
        similarityBoost: _similarityBoost,
        style: _style,
        useSpeakerBoost: _useSpeakerBoost,
      );

      if (_isElevenLabsSelected) {
        await VoiceConfigService.setVoicePersonality(_selectedPersonality);
        await VoiceConfigService.setCustomVoiceId(
            _customVoiceIdController.text);
        await VoiceConfigService.setQualityPreset(_selectedQuality);
      }

      await _loadCurrentConfig();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
            onPressed: _isSaving ? null : _saveSettings,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
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
            if (_isElevenLabsSelected) ...[
              if (!_isElevenLabsReady)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'ElevenLabs selected, but API key is missing. Voice output is disabled until key is set.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              _buildPersonalitySection(),
              const SizedBox(height: 24),
              _buildCustomVoiceIdSection(),
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
            subtitle: _isElevenLabsReady
                ? 'Premium human-like voice synthesis'
                : 'Tap to add API key and voice ID',
            value: 'elevenlabs',
            isSelected: _isElevenLabsSelected,
            onTap: () {
              _showApiKeyDialog();
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

  Widget _buildCustomVoiceIdSection() {
    return _buildSection(
      title: 'Custom Voice ID',
      icon: Icons.mic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the exact ElevenLabs voice ID to use for all personalities.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748b),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customVoiceIdController,
            decoration: const InputDecoration(
              hintText: 'e.g. QZlSvAAnrDxLbn7n3NqM',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityTile(Map<String, dynamic> voice) {
    final isSelected = _selectedPersonality == voice['key'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E66F5).withOpacity(0.1)
            : Colors.white,
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
            : const Icon(Icons.radio_button_unchecked,
                color: Color(0xFFCBD5E1)),
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
          _buildQualityTile('High Quality', 'Best quality, slower generation',
              'high_quality'),
          _buildQualityTile(
              'Balanced', 'Good quality, moderate speed', 'balanced'),
          _buildQualityTile(
              'Fast', 'Lower quality, fastest generation', 'fast'),
        ],
      ),
    );
  }

  Widget _buildQualityTile(String title, String subtitle, String value) {
    final isSelected = _selectedQuality == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E66F5).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E66F5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 13)),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF1E66F5))
            : const Icon(Icons.radio_button_unchecked,
                color: Color(0xFFCBD5E1)),
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
            title: Text('Speaker Boost',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            subtitle: Text('Enhance voice clarity and volume',
                style: GoogleFonts.inter(fontSize: 13)),
            value: _useSpeakerBoost,
            onChanged: (value) => setState(() => _useSpeakerBoost = value),
            activeColor: const Color(0xFF1E66F5),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
      String title, String subtitle, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF64748b))),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isTesting ? 'Testing...' : 'Test Voice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E66F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required IconData icon, required Widget child}) {
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
        color: isSelected
            ? const Color(0xFF1E66F5).withOpacity(0.1)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E66F5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 13)),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF1E66F5))
            : const Icon(Icons.radio_button_unchecked,
                color: Color(0xFFCBD5E1)),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showApiKeyDialog() async {
    final existingApiKey = await VoiceConfigService.getElevenLabsApiKey() ?? '';
    final controller = TextEditingController(text: existingApiKey);
    final voiceIdController = TextEditingController(
      text: _currentConfig['voice_id']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ElevenLabs API Key',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your own ElevenLabs API key and optional Voice ID.',
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
            const SizedBox(height: 12),
            TextField(
              controller: voiceIdController,
              decoration: const InputDecoration(
                hintText: 'Voice ID (optional)',
                border: OutlineInputBorder(),
              ),
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
              final enteredApiKey = controller.text.trim();
              final enteredVoiceId = voiceIdController.text.trim();

              if (enteredApiKey.isEmpty && enteredVoiceId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter API key or Voice ID to save.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final existingApiKey =
                  await VoiceConfigService.getElevenLabsApiKey();

              if (enteredApiKey.isNotEmpty) {
                await VoiceConfigService.setElevenLabsApiKey(enteredApiKey);
              }
              if (enteredVoiceId.isNotEmpty) {
                await VoiceConfigService.setCustomVoiceId(enteredVoiceId);
              }

              await VoiceConfigService.setVoiceProvider('elevenlabs');

              final effectiveApiKey = enteredApiKey.isNotEmpty
                  ? enteredApiKey
                  : (existingApiKey ?? '');
              final hasApiKey = effectiveApiKey.trim().isNotEmpty;

              await _loadCurrentConfig();
              if (!mounted) return;

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(hasApiKey
                      ? 'ElevenLabs settings saved and enabled.'
                      : 'Saved, but add API key to enable ElevenLabs audio.'),
                  backgroundColor: hasApiKey ? Colors.green : Colors.orange,
                ),
              );
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
        title: Text('Reset Settings',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
