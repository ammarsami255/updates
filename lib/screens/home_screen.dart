import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_moza3/core/constants/app_constants.dart';
import 'package:el_moza3/infrastructure/di/injection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:el_moza3/features/chat/domain/repositories/chat_repository.dart';
import 'package:el_moza3/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:el_moza3/features/auth/presentation/bloc/auth_state_event.dart';
import 'package:el_moza3/screens/services_screen.dart';
import 'package:el_moza3/screens/search_screen.dart';
import 'package:el_moza3/screens/add_service_screen.dart';
import 'package:el_moza3/screens/chat_screen.dart';
import 'package:el_moza3/screens/profile_screen.dart';
import 'package:el_moza3/screens/otp_verification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  late Stream<int> _unreadChatsStream;

  @override
  void initState() {
    super.initState();
    _unreadChatsStream = getIt<ChatRepository>().getUnreadChatsCountStream();
    _initialize();
    _checkVerificationOnInit();
  }

  /// Check verification status on app start
  Future<void> _checkVerificationOnInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified && mounted) {
      final email = user.email;
      if (email != null && email.isNotEmpty) {
        // Auto-navigate to verification screen for unverified users
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // FIXED: Clean up resources to prevent memory leaks
    // presence handled elsewhere
    // presence handled elsewhere
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requireLogin() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showAuthBottomSheet();
      return;
    }

    final isVerified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!isVerified && mounted) {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
        if (mounted) setState(() {});
      }
    }
  }

  void _showAuthBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: BlocProvider.of<AuthBloc>(this.context),
        child: const AuthBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background2,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogo(),
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background2,
      body: _buildCurrentPage(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return SearchScreen(onRequireLogin: _requireLogin);
      case 2:
        return AddServiceScreen(
          onClose: () => setState(() => _currentIndex = 0),
        );
      case 3:
        return const ChatScreen();
      case 4:
        return ProfileScreen(
          onRequireLogin: _requireLogin,
          hasVerifiedSession: true,
        );
      case 0:
      default:
        return ServicesScreen(onRequireLogin: _requireLogin);
    }
  }

  Widget _buildLogo() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppBorders.radiusMedium,
      ),
      child: const Icon(Icons.storefront, color: Colors.white, size: 32),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, "رئيسية"),
              _buildNavItem(1, Icons.search_rounded, "بحث"),
              const SizedBox(width: 60), // Space for FAB
              _buildNavItem(
                3,
                Icons.chat_bubble_outline_rounded,
                "رسائل",
                showBadge: true,
              ),
              _buildNavItem(4, Icons.person_outline_rounded, "حسابي"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool showBadge = false,
  }) {
    final selected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () async {
          if (index == 2 || index == 3) {
            await _requireLogin();
            final isVerified =
                FirebaseAuth.instance.currentUser?.emailVerified ?? false;
            if (!isVerified) return;
          }
          setState(() => _currentIndex = index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 24,
                ),
                if (showBadge && index == 3)
                  StreamBuilder<int>(
                    stream: _unreadChatsStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            count > 9 ? '9+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await _requireLogin();
            final isVerified =
                FirebaseAuth.instance.currentUser?.emailVerified ?? false;
            if (isVerified && mounted) {
              setState(() => _currentIndex = 2);
            }
          },
          borderRadius: BorderRadius.circular(28),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// Auth Bottom Sheet for login/register
class AuthBottomSheet extends StatelessWidget {
  const AuthBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'مرحباً بك',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سجل دخولك أو أنشئ حساب جديد',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildAuthButton(context, 'تسجيل الدخول', Icons.login_rounded, () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/login');
          }),
          const SizedBox(height: 12),
          _buildGoogleButton(context),
          const SizedBox(height: 12),
          _buildAuthButton(context, 'إنشاء حساب', Icons.person_add_rounded, () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/register');
          }, isPrimary: false),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ربما لاحقاً',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildAuthButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isPrimary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorders.radiusMedium,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorders.radiusMedium,
                ),
              ),
            ),
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          Navigator.pop(context);
          context.read<AuthBloc>().add(AuthSignInWithGoogleRequested());
        },
        icon: const Icon(Icons.g_mobiledata, size: 24),
        label: const Text('Continue with Google'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: AppBorders.radiusMedium),
        ),
      ),
    );
  }
}
