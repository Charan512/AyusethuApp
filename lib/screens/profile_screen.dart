import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/farmer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _farmSizeController = TextEditingController();
  final _locationController = TextEditingController();
  final _nameController = TextEditingController();

  String _irrigationType = 'Rain-fed';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMsg;
  String? _successMsg;

  final FarmerService _farmerService = FarmerService();

  final List<String> _irrigationOptions = [
    'Rain-fed',
    'Drip Irrigation',
    'Canal',
    'Borewell',
    'Sprinkler',
    'Flood Irrigation',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _farmerService.getProfile();
      final profile = data['profile'] ?? {};
      final farmerProfile = data['farmerProfile'];

      setState(() {
        _nameController.text = profile['name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _emailController.text = profile['email'] ?? '';
        if (farmerProfile != null) {
          _farmSizeController.text = farmerProfile['farmSize'] ?? '';
          _locationController.text = farmerProfile['location'] ?? '';
          final irrigation = farmerProfile['irrigationType'] ?? '';
          if (_irrigationOptions.contains(irrigation)) {
            _irrigationType = irrigation;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Failed to load profile: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMsg = null;
      _successMsg = null;
    });

    try {
      await _farmerService.updateProfile(
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        farmSize: _farmSizeController.text.trim(),
        irrigationType: _irrigationType,
        location: _locationController.text.trim(),
      );

      setState(() {
        _isSaving = false;
        _successMsg = 'Profile updated successfully!';
      });

      // Clear success after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _successMsg = null);
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMsg = 'Failed to save changes';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _farmSizeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Avatar header ─────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (_nameController.text.isNotEmpty)
                                    ? _nameController.text[0].toUpperCase()
                                    : 'F',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _nameController.text,
                            style:
                                Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🌱 Farmer',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Name (Read-only) ──────────────
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name (cannot be changed)',
                      prefixIcon: Icons.person_outline,
                      readOnly: true,
                    ),

                    // ── Editable fields ───────────────
                    CustomTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Phone is required';
                        }
                        if (v.length < 10) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    CustomTextField(
                      controller: _farmSizeController,
                      label: 'Farm Size (acres)',
                      prefixIcon: Icons.landscape_outlined,
                      keyboardType: TextInputType.number,
                    ),

                    // Irrigation dropdown
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _irrigationType,
                        decoration: InputDecoration(
                          labelText: 'Irrigation Type',
                          prefixIcon: const Icon(Icons.water_drop_outlined,
                              color: AppColors.primary, size: 22),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: _irrigationOptions
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _irrigationType = value);
                          }
                        },
                      ),
                    ),

                    CustomTextField(
                      controller: _locationController,
                      label: 'Location',
                      prefixIcon: Icons.location_on_outlined,
                    ),

                    const SizedBox(height: 8),

                    // ── Success message ────────────────
                    if (_successMsg != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _successMsg!,
                              style: const TextStyle(
                                  color: AppColors.success, fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                    // ── Error message ──────────────────
                    if (_errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _errorMsg!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                      label: const Text(
                        'Logout Account',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
