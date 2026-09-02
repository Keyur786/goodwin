import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:goodwin/core/services/firestore_user_repository.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/profile_avatar_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum _AuthStep { phone, otp, profile }

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthStep _currentStep = _AuthStep.phone;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isExistingUser = false;
  String? _verificationId;
  String? _errorMessage;
  String? _authenticatedUserId;
  String? _selectedPhotoUrl;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_currentStep == _AuthStep.profile) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _openPhotoPickerSheet() async {
    await showProfilePhotoPickerSheet(
      context: context,
      currentPhotoUrl: _selectedPhotoUrl,
      onPhotoSelected: (url) {
        setState(() => _selectedPhotoUrl = url);
      },
    );
  }

  // Step 1: Send OTP to 10-digit number & check registration status
  Future<void> _sendOtp() async {
    final rawNumber = _phoneController.text.trim();
    if (rawNumber.length != 10 || !RegExp(r'^\d{10}$').hasMatch(rawNumber)) {
      setState(
        () => _errorMessage = 'Please enter a valid 10-digit mobile number',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formattedNumber = '+91$rawNumber';

    try {
      // Check if user is already registered in Firestore
      final userRepo = FirestoreUserRepository();
      final phoneUser = await userRepo.getUserByPhone(rawNumber);
      final isAlreadyRegistered =
          phoneUser != null &&
          (phoneUser.isProfileComplete ||
              (phoneUser.name.isNotEmpty &&
                  !phoneUser.name.startsWith('Reseller ')));

      _isExistingUser = isAlreadyRegistered;

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedNumber,
        verificationCompleted: (credential) async {
          final userCred = await FirebaseAuth.instance.signInWithCredential(
            credential,
          );
          if (userCred.user != null) {
            _authenticatedUserId = userCred.user!.uid;
            final isPresent = await userRepo.isUserAlreadyPresent(
              userId: userCred.user!.uid,
              phone: rawNumber,
            );

            if (isPresent || _isExistingUser) {
              await userRepo.getOrCreateUser(userCred.user!);
              if (mounted) {
                setState(() => _isLoading = false);
                widget.onLoginSuccess();
              }
              return;
            }

            final user = await userRepo.getOrCreateUser(userCred.user!);
            if (user.name.isNotEmpty && !user.name.startsWith('Reseller ')) {
              _nameController.text = user.name;
            }
            if (user.email != null && user.email!.isNotEmpty) {
              _emailController.text = user.email!;
            }
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentStep = _AuthStep.profile;
            });
          }
        },
        verificationFailed: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage =
                  error.message ?? 'Could not send verification code.';
            });
          }
        },
        codeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
              _currentStep = _AuthStep.otp;
            });
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message ?? 'Authentication error.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  // Step 2: Verify OTP & Direct Route if User Already Present
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(
        () => _errorMessage = 'Please enter the 6-digit verification code',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      User? firebaseUser;
      if (_verificationId != null) {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        final userCred = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        firebaseUser = userCred.user;
      } else {
        final userCred = await FirebaseAuth.instance.signInAnonymously();
        firebaseUser = userCred.user;
      }

      if (firebaseUser != null) {
        _authenticatedUserId = firebaseUser.uid;
        final rawPhone = _phoneController.text.trim();
        final userRepo = FirestoreUserRepository();

        // Check if user is already present and completed setup
        final isPresent = await userRepo.isUserAlreadyPresent(
          userId: firebaseUser.uid,
          phone: rawPhone,
        );

        if (isPresent) {
          // Finish setup at step 2 and take user directly to the home screen
          await userRepo.getOrCreateUser(firebaseUser);
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onLoginSuccess();
          }
          return;
        }

        // New user: proceed to step 3 (Profile Setup)
        final user = await userRepo.getOrCreateUser(firebaseUser);
        if (user.name.isNotEmpty && !user.name.startsWith('Reseller ')) {
          _nameController.text = user.name;
        }
        if (user.email != null && user.email!.isNotEmpty) {
          _emailController.text = user.email!;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = _AuthStep.profile;
          });
        }
        return;
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message ?? 'Invalid verification code.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification error: $e';
        });
      }
    }
  }

  // Step 3: Complete Profile Name & Optional Email
  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(
        () => _errorMessage = 'Please enter your name (at least 2 characters)',
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
      setState(
        () => _errorMessage =
            'Please enter a valid email address or leave it blank',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid =
          _authenticatedUserId ?? FirebaseAuth.instance.currentUser?.uid;
      final phone = _phoneController.text.trim();
      final isSpecialAdmin = FirestoreUserRepository.isSuperAdminPhone(phone);
      if (uid != null) {
        await FirestoreUserRepository().updateUser(
          userId: uid,
          data: {
            'name': name,
            if (phone.isNotEmpty) 'phone': phone,
            if (isSpecialAdmin) 'role': UserRole.superAdmin.name,
            if (email.isNotEmpty) 'email': email,
            if (_selectedPhotoUrl != null) 'photoUrl': _selectedPhotoUrl,
            'isProfileComplete': true,
          },
        );
      }
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        widget.onLoginSuccess();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Quick Demo Login bypass
  Future<void> _handleDemoLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userCred = await FirebaseAuth.instance.signInAnonymously();
      if (userCred.user != null) {
        _authenticatedUserId = userCred.user!.uid;
        final userRepo = FirestoreUserRepository();
        final isPresent = await userRepo.isUserAlreadyPresent(
          userId: userCred.user!.uid,
        );

        if (isPresent) {
          await userRepo.getOrCreateUser(userCred.user!);
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onLoginSuccess();
          }
          return;
        }

        final user = await userRepo.getOrCreateUser(userCred.user!);
        if (user.name.isNotEmpty && !user.name.startsWith('Reseller ')) {
          _nameController.text = user.name;
        } else {
          _nameController.text = 'Demo Reseller';
        }
        if (user.email != null && user.email!.isNotEmpty) {
          _emailController.text = user.email!;
        }
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = _AuthStep.profile;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = _AuthStep.profile;
        });
      }
    }
  }

  Widget _buildStepIndicator() {
    // If registered user on OTP verification step, only display 2 steps (Phone & Code)
    if (_isExistingUser && _currentStep == _AuthStep.otp) {
      return Row(
        children: [
          _buildStepBadge(
            stepNumber: 1,
            title: 'Phone',
            isActive: false,
            isDone: true,
          ),
          Expanded(child: Container(height: 2, color: const Color(0xFF2563EB))),
          _buildStepBadge(
            stepNumber: 2,
            title: 'Code',
            isActive: true,
            isDone: false,
          ),
        ],
      );
    }

    // Default / New user flow: 3 steps (Phone -> Code -> Profile)
    return Row(
      children: [
        _buildStepBadge(
          stepNumber: 1,
          title: 'Phone',
          isActive: _currentStep == _AuthStep.phone,
          isDone: _currentStep != _AuthStep.phone,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep != _AuthStep.phone
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
        ),
        _buildStepBadge(
          stepNumber: 2,
          title: 'Code',
          isActive: _currentStep == _AuthStep.otp,
          isDone: _currentStep == _AuthStep.profile,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep == _AuthStep.profile
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
        ),
        _buildStepBadge(
          stepNumber: 3,
          title: 'Profile',
          isActive: _currentStep == _AuthStep.profile,
          isDone: false,
        ),
      ],
    );
  }

  Widget _buildStepBadge({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    final color = isDone || isActive
        ? const Color(0xFF2563EB)
        : const Color(0xFF94A3B8);
    final bgColor = isDone
        ? const Color(0xFF2563EB)
        : (isActive
              ? const Color(0xFF2563EB).withAlpha(25)
              : const Color(0xFFF1F5F9));

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isActive ? 2 : 1),
          ),
          child: Center(
            child: isDone
                ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildStepIndicator(),
              const SizedBox(height: 36),
              if (_currentStep == _AuthStep.phone) _buildPhoneStep(),
              if (_currentStep == _AuthStep.otp) _buildOtpStep(),
              if (_currentStep == _AuthStep.profile) _buildProfileStep(),
            ],
          ),
        ),
      ),
    );
  }

  // Page 1: 10-digit mobile number input
  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 20),
        const Text(
          'Welcome to Goodwin',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your 10-digit mobile number to access wholesale prices and orders.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 32),
        const Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          enabled: !_isLoading,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            hintText: '10-digit mobile number',
            prefixIcon: const Icon(
              LucideIcons.smartphone,
              color: Color(0xFF2563EB),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: !_isLoading ? _sendOtp : null,
            icon: const Icon(LucideIcons.arrowRight, size: 18),
            label: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send Verification Code'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: !_isLoading ? _handleDemoLogin : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Quick Demo Sign In (Skip SMS)'),
          ),
        ),
      ],
    );
  }

  // Page 2: Verification Code (OTP)
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoading
              ? null
              : () => setState(() {
                  _currentStep = _AuthStep.phone;
                  _isExistingUser = false;
                  _errorMessage = null;
                }),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.arrowLeft,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                Text(
                  'Change Number (${_phoneController.text})',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Enter Verification Code',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We have sent a 6-digit verification code to +91 ${_phoneController.text}.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          '6-Digit Code',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          enabled: !_isLoading,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: '••••••',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: !_isLoading ? _verifyOtp : null,
            icon: const Icon(LucideIcons.circleCheck, size: 18),
            label: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verify Code'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: !_isLoading ? _sendOtp : null,
              child: const Text('Resend Code'),
            ),
            TextButton(
              onPressed: !_isLoading
                  ? () {
                      _otpController.text = '123456';
                      _verifyOtp();
                    }
                  : null,
              child: const Text('Demo Auto-Fill'),
            ),
          ],
        ),
      ],
    );
  }

  // Page 3: Profile Name & Picture Setup
  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set your profile picture and name to personalize your wholesale account.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              ProfileAvatarWidget(
                radius: 48,
                photoUrl: _selectedPhotoUrl,
                name: _nameController.text,
                showCameraBadge: true,
                onTap: _openPhotoPickerSheet,
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _openPhotoPickerSheet,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedPhotoUrl != null
                            ? LucideIcons.pencil
                            : LucideIcons.camera,
                        size: 15,
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedPhotoUrl != null
                            ? 'Change Profile Picture'
                            : 'Add Profile Picture',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Your Full Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          enabled: !_isLoading,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. First and Lastname',
            prefixIcon: const Icon(
              LucideIcons.user,
              color: Color(0xFF2563EB),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'e.g. abc@gmail.com (optional)',
            prefixIcon: const Icon(
              LucideIcons.mail,
              color: Color(0xFF2563EB),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
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
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: !_isLoading ? _completeProfile : null,
            icon: const Icon(LucideIcons.arrowRight, size: 18),
            label: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Start Wholesale Shopping'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

