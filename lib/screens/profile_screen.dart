import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _curPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _updatingPwd = false;
  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _obscureConf = true;

  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _curPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final data = await ApiService().getMyProfile();
    if (mounted) {
      setState(() {
        _profile = data;
        _firstCtrl.text = data['firstName'] ?? '';
        _lastCtrl.text = data['lastName'] ?? '';
        _phoneCtrl.text = data['phone'] ?? data['contactNumber'] ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await ApiService().updateMyProfile({
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      _snack('Profile updated successfully', Colors.green);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
      _snack('New passwords do not match', Colors.red);
      return;
    }
    if (_newPwdCtrl.text.length < 6) {
      _snack('Password must be at least 6 characters', Colors.red);
      return;
    }
    setState(() => _updatingPwd = true);
    try {
      await ApiService().changeMyPassword(
        _curPwdCtrl.text, _newPwdCtrl.text, _confirmPwdCtrl.text);
      _curPwdCtrl.clear();
      _newPwdCtrl.clear();
      _confirmPwdCtrl.clear();
      _snack('Password updated successfully', Colors.green);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _updatingPwd = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final fullName = '${user?.fullName ?? _profile['firstName'] ?? 'User'}';
    final role = user?.role ?? _profile['role'] ?? '';
    final email = user?.email ?? _profile['email'] ?? '';
    final dept = _profile['department']?['name'] ?? _profile['departmentName'] ?? '';
    final memberSince = _profile['createdAt'] ?? '';
    final lastUpdated = _profile['updatedAt'] ?? '';
    final initials = fullName.isNotEmpty
        ? fullName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
        ),
        title: const Text('My Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Information ─────────────────────────────────────────
            _section('Profile Information', [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          child: Text(initials,
                              style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24)),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF1E293B), width: 2),
                            ),
                            child: const Icon(Icons.upload, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(fullName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(role.toString().replaceAll('_', ' '),
                          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    if (memberSince.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Member since ${_formatDate(memberSince)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _formField('First Name', _firstCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _formField('Last Name', _lastCtrl)),
                ],
              ),
              const SizedBox(height: 10),
              _formField('Phone', _phoneCtrl, keyboard: TextInputType.phone),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _savingProfile ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _savingProfile
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Change Password ─────────────────────────────────────────────
            _section('Change Password', [
              _pwdField('Current Password', _curPwdCtrl, _obscureCur,
                  () => setState(() => _obscureCur = !_obscureCur)),
              const SizedBox(height: 10),
              _pwdField('New Password', _newPwdCtrl, _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew)),
              const SizedBox(height: 10),
              _pwdField('Confirm Password', _confirmPwdCtrl, _obscureConf,
                  () => setState(() => _obscureConf = !_obscureConf)),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _updatingPwd ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _updatingPwd
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Update Password',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Account Information ─────────────────────────────────────────
            _section('Account Information', [
              Row(
                children: [
                  Expanded(child: _infoRow('Email', email)),
                  Expanded(child: _infoRow('Role', role.toString().replaceAll('_', ' '))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _infoRow('Department', dept.isNotEmpty ? dept : '—')),
                  Expanded(child: _infoRow('Account Created', _formatDate(memberSince))),
                ],
              ),
              if (lastUpdated.isNotEmpty) ...[
                const SizedBox(height: 10),
                _infoRow('Last Updated', _formatDate(lastUpdated)),
              ],
            ]),
            const SizedBox(height: 16),

            // ── Appearance ──────────────────────────────────────────────────
            _section('Appearance', [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.themeNotifier,
                builder: (_, mode, __) {
                  final isDark = mode == ThemeMode.dark;
                  return Row(children: [
                    Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isDark ? 'Dark Mode' : 'Light Mode',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(isDark ? 'Switch to light theme' : 'Switch to dark theme',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ])),
                    Switch(
                      value: isDark,
                      onChanged: (v) => ThemeService.setMode(v ? ThemeMode.dark : ThemeMode.light),
                      activeColor: const Color(0xFF3B82F6),
                    ),
                  ]);
                },
              ),
            ]),
            const SizedBox(height: 20),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _formField(String label, TextEditingController ctrl, {TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          keyboardType: keyboard,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
          ),
        ),
      ],
    );
  }

  Widget _pwdField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white38, size: 18),
              onPressed: toggle,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value.isNotEmpty ? value : '—',
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return iso; }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}
