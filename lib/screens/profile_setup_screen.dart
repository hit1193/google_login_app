// lib/screens/profile_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final profile = authService.profile;
    final user = authService.user;

    if (profile != null) {
      // 기존 프로필 정보로 폼 초기화
      _fullNameController.text = profile['full_name'] ?? '';
      _phoneController.text = profile['phone'] ?? '';
      _ageController.text = profile['age']?.toString() ?? '';
      _jobTitleController.text = profile['job_title'] ?? '';
      _departmentController.text = profile['department'] ?? '';
      _bioController.text = profile['bio'] ?? '';
    } else if (user != null) {
      // 사용자 메타데이터에서 이름 가져오기
      final userMeta = user.userMetadata;
      if (userMeta != null) {
        _fullNameController.text = userMeta['full_name'] ?? userMeta['name'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // 프로필 데이터 준비
      final profileData = {
        'fullName': _fullNameController.text,
        'phone': _phoneController.text,
        'age': _ageController.text.isNotEmpty ? int.parse(_ageController.text) : null,
        'jobTitle': _jobTitleController.text,
        'department': _departmentController.text,
        'bio': _bioController.text,
      };

      // 프로필 생성 또는 업데이트
      await authService.createOrUpdateProfile(profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 저장되었습니다')),
        );

        // 프로필 설정 완료 후 메인 화면으로 이동
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 설정'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '프로필 정보를 입력해주세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: '이름 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이름을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: '나이',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(
                  labelText: '직함/직위',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: '부서',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: '자기소개',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('저장하기', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
