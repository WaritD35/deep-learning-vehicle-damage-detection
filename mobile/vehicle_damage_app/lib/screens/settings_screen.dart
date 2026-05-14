// Settings screen - configure app settings

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _serverUrl = 'http://localhost:8000';
  double _confidenceThreshold = 0.25;
  bool _returnAnnotatedImage = true;
  bool _includeLabor = true;
  String _currency = 'AUD';
  bool _isSavePressed = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
      _confidenceThreshold = prefs.getDouble('confidence_threshold') ?? 0.25;
      _returnAnnotatedImage = prefs.getBool('return_annotated') ?? true;
      _includeLabor = prefs.getBool('include_labor') ?? true;
      _currency = prefs.getString('currency') ?? 'AUD';
    });
  }

  Future<void> _saveSettings() async {
    final api = context.read<ApiService>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverUrl);
    await prefs.setDouble('confidence_threshold', _confidenceThreshold);
    await prefs.setBool('return_annotated', _returnAnnotatedImage);
    await prefs.setBool('include_labor', _includeLabor);
    await prefs.setString('currency', _currency);
    
    // Update API service base URL
    api.baseUrl = _serverUrl;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSaveTap() async {
    if (_isSavePressed) return;
    setState(() => _isSavePressed = true);
    await Future.wait<void>([
      _saveSettings(),
      Future<void>.delayed(const Duration(milliseconds: 170)),
    ]);
    if (mounted) {
      setState(() => _isSavePressed = false);
    }
  }

  Future<void> _testConnection() async {
    final api = context.read<ApiService>();
    final originalUrl = api.baseUrl;
    
    // Temporarily set URL to test
    api.baseUrl = _serverUrl;
    final isConnected = await api.healthCheck();
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(isConnected ? 'Connection successful!' : 'Connection failed'),
          ],
        ),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
    );
    
    // Restore original URL if test failed
    if (!isConnected) {
      api.baseUrl = originalUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : const Color(0xFFEAF3FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 124,
              color: const Color(0xFF5061C8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _handleSaveTap,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isSavePressed
                            ? Colors.white.withValues(alpha: 0.34)
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isSavePressed
                              ? Colors.white.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: const Icon(Icons.save_outlined, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131D33) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                    children: [
                    _SectionHeader(title: 'Server Configuration'),
                    _SoftBlock(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _testConnection,
                          icon: const Icon(Icons.network_check),
                          label: const Text('Test Connection'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'Detection Settings'),
                    _SoftBlock(
                      child: Column(
                        children: [
                          _LineItem(
                            icon: Icons.tune,
                            title: 'Confidence Threshold',
                            subtitle: '${(_confidenceThreshold * 100).toInt()}%',
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Slider(
                              value: _confidenceThreshold,
                              min: 0.1,
                              max: 0.9,
                              divisions: 16,
                              onChanged: (value) => setState(() => _confidenceThreshold = value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LineItem(
                            icon: Icons.image_outlined,
                            title: 'Return Annotated Image',
                            subtitle: 'Show bounding boxes on image',
                            trailing: Switch(
                              value: _returnAnnotatedImage,
                              onChanged: (value) => setState(() => _returnAnnotatedImage = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'Cost Estimation'),
                    _SoftBlock(
                      child: Column(
                        children: [
                          _LineItem(
                            icon: Icons.engineering_outlined,
                            title: 'Include Labor Costs',
                            subtitle: 'Add labor costs to estimates',
                            trailing: Switch(
                              value: _includeLabor,
                              onChanged: (value) => setState(() => _includeLabor = value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _LineItem(
                            icon: Icons.attach_money,
                            title: 'Currency',
                            trailing: DropdownButton<String>(
                              value: _currency,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                                DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                                DropdownMenuItem(value: 'AUD', child: Text('AUD (A\$)')),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => _currency = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'Appearance'),
                    _SoftBlock(
                      child: _LineItem(
                        icon: Icons.dark_mode_outlined,
                        title: 'Dark Mode',
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) => themeProvider.setDarkMode(value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(title: 'About'),
                    _SoftBlock(
                      child: const Column(
                        children: [
                          _LineItem(
                            icon: Icons.info_outline,
                            title: 'Version',
                            trailing: Text('1.0.0'),
                          ),
                          SizedBox(height: 10),
                          _LineItem(
                            icon: Icons.code_outlined,
                            title: 'Model',
                            subtitle: 'YOLO / Faster R-CNN',
                          ),
                          SizedBox(height: 10),
                          _LineItem(
                            icon: Icons.category_outlined,
                            title: 'Damage Categories',
                            subtitle: 'Dent, Scratch, Crack, Glass Shatter, Lamp Broken, Tire Flat',
                          ),
                        ],
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: isDark ? Colors.white70 : const Color(0xFF1E2430),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SoftBlock extends StatelessWidget {
  final Widget child;

  const _SoftBlock({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A3D) : const Color(0xFFF4F3FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _LineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _LineItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: const Color(0xFF5061C8)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E2430),
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}
