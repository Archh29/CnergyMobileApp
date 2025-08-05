import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../models/onboarding_model.dart';
import '../services/onboarding_service.dart';

class FirstTimeSetupScreen extends StatefulWidget {
  final int? userId; // For existing users
  final String? email; // For new registrations
  
  const FirstTimeSetupScreen({
    super.key,
    this.userId,
    this.email,
  });

  @override
  _FirstTimeSetupScreenState createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late AnimationController _progressController;
  late AnimationController _cardController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  
  int currentPage = 0;
  final int totalPages = 4;
  
  // Services
  final OnboardingService _onboardingService = OnboardingService();
  
  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  
  // User selections
  String selectedGender = '';
  String selectedFitnessLevel = '';
  List<String> selectedGoals = [];
  String selectedActivityLevel = '';
  DateTime? selectedBirthdate;
  int? selectedWorkoutDays;
  
  // Dynamic data from backend
  List<OnboardingGoal> fitnessGoals = [];
  List<ActivityLevelOption> activityLevels = [];
  
  // Loading states
  bool isLoading = false;
  bool isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _cardController.forward();
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check if user is eligible for setup (only for existing users)
      if (widget.userId != null) {
        final eligibilityResponse = await _onboardingService.checkUserEligibility(widget.userId!);
        if (!eligibilityResponse.success || !eligibilityResponse.data!) {
          _showErrorAndNavigateBack('Profile setup not available for this user');
          return;
        }
      }

      // Load fitness goals and activity levels
      final goalsResponse = await _onboardingService.getFitnessGoals();
      final levelsResponse = await _onboardingService.getActivityLevels();

      if (goalsResponse.success && levelsResponse.success) {
        setState(() {
          fitnessGoals = goalsResponse.data!;
          activityLevels = levelsResponse.data!;
          isDataLoaded = true;
        });
      } else {
        _showErrorAndNavigateBack('Failed to load setup data');
      }
    } catch (e) {
      _showErrorAndNavigateBack('Network error: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }

    // Pre-fill email if provided
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }
  }

  void _showErrorAndNavigateBack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _progressController.dispose();
    _cardController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (currentPage < totalPages - 1) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeSetup();
    }
  }

  void _previousPage() {
    if (currentPage > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool _canProceed() {
    switch (currentPage) {
      case 0:
        if (widget.userId != null) {
          // Existing user - only need basic info
          return _firstNameController.text.isNotEmpty &&
              _lastNameController.text.isNotEmpty &&
              selectedBirthdate != null &&
              selectedGender.isNotEmpty;
        } else {
          // New user - need email and password too
          return _firstNameController.text.isNotEmpty &&
              _lastNameController.text.isNotEmpty &&
              selectedBirthdate != null &&
              selectedGender.isNotEmpty &&
              _emailController.text.isNotEmpty &&
              _passwordController.text.isNotEmpty &&
              _onboardingService.isValidEmail(_emailController.text) &&
              _onboardingService.isValidPassword(_passwordController.text);
        }
      case 1:
        return _heightController.text.isNotEmpty &&
            _weightController.text.isNotEmpty;
      case 2:
        return selectedGoals.isNotEmpty;
      case 3:
        return selectedFitnessLevel.isNotEmpty &&
            selectedActivityLevel.isNotEmpty &&
            selectedWorkoutDays != null;
      default:
        return false;
    }
  }

  Future<void> _completeSetup() async {
    try {
      HapticFeedback.mediumImpact();
      
      // Show loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const ModernLoadingDialog(),
      );

      setState(() {
        isLoading = true;
      });

      if (widget.userId != null) {
        // Update existing user profile
        final profile = MemberProfileDetails(
          userId: widget.userId!,
          fitnessLevel: selectedFitnessLevel,
          fitnessGoals: selectedGoals,
          genderId: _onboardingService.getGenderId(selectedGender),
          birthdate: selectedBirthdate!,
          heightCm: double.parse(_heightController.text),
          weightKg: double.parse(_weightController.text),
          targetWeight: _targetWeightController.text.isNotEmpty 
              ? double.parse(_targetWeightController.text) 
              : null,
          activityLevel: selectedActivityLevel,
          workoutDaysPerWeek: selectedWorkoutDays!,
          profileCompleted: true,
          profileCompletedAt: DateTime.now(),
          onboardingCompletedAt: DateTime.now(),
        );

        final response = await _onboardingService.updateUserProfile(widget.userId!, profile);
        
        if (response.success) {
          await _handleSuccessfulSetup(widget.userId!, 'customer');
        } else {
          throw Exception(response.message);
        }
      } else {
        // Complete onboarding for new user
        final user = User(
          email: _emailController.text,
          password: _passwordController.text,
          userTypeId: 4, // Customer
          genderId: _onboardingService.getGenderId(selectedGender),
          fname: _firstNameController.text,
          mname: _middleNameController.text,
          lname: _lastNameController.text,
          bday: selectedBirthdate!,
        );

        final profile = MemberProfileDetails(
          userId: 0, // Will be set by backend
          fitnessLevel: selectedFitnessLevel,
          fitnessGoals: selectedGoals,
          genderId: _onboardingService.getGenderId(selectedGender),
          birthdate: selectedBirthdate!,
          heightCm: double.parse(_heightController.text),
          weightKg: double.parse(_weightController.text),
          targetWeight: _targetWeightController.text.isNotEmpty 
              ? double.parse(_targetWeightController.text) 
              : null,
          activityLevel: selectedActivityLevel,
          workoutDaysPerWeek: selectedWorkoutDays!,
          profileCompleted: true,
          profileCompletedAt: DateTime.now(),
          onboardingCompletedAt: DateTime.now(),
        );

        final onboardingData = OnboardingData(user: user, profile: profile);
        final response = await _onboardingService.completeOnboarding(onboardingData);
        
        if (response.success) {
          final userId = response.data!['user_id'];
          await _handleSuccessfulSetup(userId, 'customer');
        } else {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _handleSuccessfulSetup(int userId, String userType) async {
    // Save user session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', userId);
    await prefs.setString('userType', userType);
    await prefs.setBool('profileCompleted', true);

    Navigator.of(context).pop(); // Close loading dialog
    
    // Show success animation
    await _showSuccessDialog();
    
    // Navigate to appropriate dashboard
    if (userType.toLowerCase() == 'coach') {
      Navigator.pushReplacementNamed(context, '/coachDashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/userDashboard');
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SuccessDialog(),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF4ECDC4),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedBirthdate) {
      setState(() {
        selectedBirthdate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && !isDataLoaded) {
      return Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: ModernLoadingDialog(),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 375 || screenHeight < 667;
    
    return Scaffold(
      backgroundColor: Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(isSmallScreen),
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                  _animationController.reset();
                  _animationController.forward();
                  _progressController.animateTo((index + 1) / totalPages);
                },
                children: [
                  _buildModernBasicInfoPage(isSmallScreen),
                  _buildModernPhysicalInfoPage(isSmallScreen),
                  _buildModernGoalsPage(isSmallScreen),
                  _buildModernFitnessLevelPage(isSmallScreen),
                ],
              ),
            ),
            _buildModernNavigationButtons(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBasicInfoPage(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              _buildPageTitle(
                "Let's get to know you! 👋",
                "Tell us about yourself to personalize your fitness journey",
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 24 : 40),
              
              // Show email and password fields only for new users
              if (widget.userId == null) ...[
                _buildModernTextField(
                  controller: _emailController,
                  hintText: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: _passwordController,
                  hintText: "Password (min 8 characters)",
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
              ],
              
              _buildModernTextField(
                controller: _firstNameController,
                hintText: "First Name",
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _middleNameController,
                hintText: "Middle Name (Optional)",
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 16),
              _buildModernTextField(
                controller: _lastNameController,
                hintText: "Last Name",
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 20),
              
              // Birthdate Selector
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: Colors.white.withOpacity(0.8)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          selectedBirthdate != null
                              ? "${selectedBirthdate!.day}/${selectedBirthdate!.month}/${selectedBirthdate!.year}"
                              : "Select your birthdate",
                          style: GoogleFonts.poppins(
                            color: selectedBirthdate != null ? Colors.white : Colors.white.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.6)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              Text(
                "Gender",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildModernGenderOption("Male", Icons.male, Color(0xFF45B7D1))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernGenderOption("Female", Icons.female, Color(0xFFE74C3C))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernGoalsPage(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              _buildPageTitle(
                "What are your goals? 🎯",
                "Select all that apply to personalize your workout plan",
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 24 : 40),
              
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isSmallScreen ? 1 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isSmallScreen ? 3.5 : 1.1,
                  ),
                  itemCount: fitnessGoals.length,
                  itemBuilder: (context, index) {
                    final goal = fitnessGoals[index];
                    final isSelected = selectedGoals.contains(goal.title);
                    final color = Color(int.parse('0x${goal.colorHex}'));
                    
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            selectedGoals.remove(goal.title);
                          } else {
                            selectedGoals.add(goal.title);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.1) : Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : Colors.white.withOpacity(0.1),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: isSmallScreen
                            ? Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getIconFromName(goal.iconName),
                                      color: color,
                                      size: 24,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          goal.title,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          goal.description,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getIconFromName(goal.iconName),
                                    color: color,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    goal.title,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    goal.description,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernFitnessLevelPage(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              _buildPageTitle(
                "Fitness Level 💪",
                "Help us tailor the perfect workout intensity for you",
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 24 : 40),
              
              Text(
                "Current Fitness Level",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              ...['Beginner', 'Intermediate', 'Advanced'].map((level) {
                final isSelected = selectedFitnessLevel == level;
                return _buildModernSelectionCard(
                  title: level,
                  subtitle: _getFitnessLevelDescription(level),
                  icon: _getFitnessLevelIcon(level),
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      selectedFitnessLevel = level;
                    });
                  },
                );
              }).toList(),
              
              const SizedBox(height: 30),
              
              Text(
                "Activity Level",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              ...activityLevels.map((level) {
                final isSelected = selectedActivityLevel == level.title;
                return _buildModernSelectionCard(
                  title: level.title,
                  subtitle: level.description,
                  icon: _getIconFromName(level.iconName),
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      selectedActivityLevel = level.title;
                    });
                  },
                );
              }).toList(),
              
              const SizedBox(height: 30),
              
              Text(
                "Workout Days Per Week",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final days = index + 1;
                  final isSelected = selectedWorkoutDays == days;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        selectedWorkoutDays = days;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: isSmallScreen ? 35 : 40,
                      height: isSmallScreen ? 35 : 40,
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF4ECDC4) : Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Color(0xFF4ECDC4) : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          days.toString(),
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for UI components
  Widget _buildModernHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currentPage > 0)
            GestureDetector(
              onTap: _previousPage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            )
          else
            const SizedBox(width: 44),
          
          Column(
            children: [
              Text(
                "Profile Setup",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 18 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Step ${currentPage + 1} of $totalPages",
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFF4ECDC4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF4ECDC4).withOpacity(0.3)),
            ),
            child: Text(
              "${((currentPage + 1) / totalPages * 100).round()}%",
              style: GoogleFonts.poppins(
                color: Color(0xFF4ECDC4),
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 6,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(3),
      ),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (currentPage + 1) / totalPages,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4ECDC4).withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernPhysicalInfoPage(bool isSmallScreen) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              _buildPageTitle(
                "Physical Stats 📏",
                "Help us calculate your fitness metrics accurately",
                isSmallScreen,
              ),
              SizedBox(height: isSmallScreen ? 24 : 40),
              
              Row(
                children: [
                  Expanded(
                    child: _buildModernTextField(
                      controller: _heightController,
                      hintText: "Height",
                      icon: Icons.height,
                      keyboardType: TextInputType.number,
                      suffix: "cm",
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildModernTextField(
                      controller: _weightController,
                      hintText: "Weight",
                      icon: Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                      suffix: "kg",
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              _buildModernTextField(
                controller: _targetWeightController,
                hintText: "Target Weight (Optional)",
                icon: Icons.flag_outlined,
                keyboardType: TextInputType.number,
                suffix: "kg",
              ),
              
              const SizedBox(height: 30),
              
              if (_heightController.text.isNotEmpty && _weightController.text.isNotEmpty)
                _buildBMICard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageTitle(String title, String subtitle, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isSmallScreen ? 24 : 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.8),
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
          suffixText: suffix,
          suffixStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8)),
          filled: true,
          fillColor: Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Color(0xFF4ECDC4), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildModernGenderOption(String gender, IconData icon, Color color) {
    final isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          selectedGender = gender;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white.withOpacity(0.7), size: 28),
            const SizedBox(height: 8),
            Text(
              gender,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF4ECDC4).withOpacity(0.1) : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Color(0xFF4ECDC4) : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF4ECDC4).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color(0xFF4ECDC4).withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Color(0xFF4ECDC4) : Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Color(0xFF4ECDC4),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNavigationButtons(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: Row(
        children: [
          if (currentPage > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF4ECDC4), width: 2),
                  foregroundColor: Color(0xFF4ECDC4),
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  "BACK",
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: currentPage > 0 ? 1 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton(
                onPressed: _canProceed() ? _nextPage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: Colors.white.withOpacity(0.1),
                  elevation: _canProceed() ? 8 : 0,
                  shadowColor: Color(0xFF4ECDC4).withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentPage == totalPages - 1 ? "COMPLETE SETUP" : "CONTINUE",
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      currentPage == totalPages - 1 ? Icons.check : Icons.arrow_forward,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMICard() {
    final bmi = _calculateBMI();
    final bmiCategory = _getBMICategory(double.tryParse(bmi) ?? 0);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF4ECDC4).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF4ECDC4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calculate,
                  color: Color(0xFF4ECDC4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your BMI",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      bmi,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bmiCategory['color'],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  bmiCategory['category'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _calculateBMI() {
    try {
      final height = double.parse(_heightController.text) / 100;
      final weight = double.parse(_weightController.text);
      final bmi = weight / (height * height);
      return bmi.toStringAsFixed(1);
    } catch (e) {
      return "0.0";
    }
  }

  Map<String, dynamic> _getBMICategory(double bmi) {
    if (bmi < 18.5) {
      return {'category': 'Underweight', 'color': Color(0xFF45B7D1)};
    } else if (bmi < 25) {
      return {'category': 'Normal', 'color': Color(0xFF96CEB4)};
    } else if (bmi < 30) {
      return {'category': 'Overweight', 'color': Color(0xFFFFD700)};
    } else {
      return {'category': 'Obese', 'color': Color(0xFFE74C3C)};
    }
  }

  String _getFitnessLevelDescription(String level) {
    switch (level) {
      case 'Beginner':
        return 'New to fitness or returning after a break';
      case 'Intermediate':
        return 'Regular exercise routine for 6+ months';
      case 'Advanced':
        return 'Consistent training for 2+ years';
      default:
        return '';
    }
  }

  IconData _getFitnessLevelIcon(String level) {
    switch (level) {
      case 'Beginner':
        return Icons.looks_one;
      case 'Intermediate':
        return Icons.looks_two;
      case 'Advanced':
        return Icons.looks_3;
      default:
        return Icons.fitness_center;
    }
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'trending_down':
        return Icons.trending_down;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'directions_run':
        return Icons.directions_run;
      case 'sports_gymnastics':
        return Icons.sports_gymnastics;
      case 'favorite':
        return Icons.favorite;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'weekend':
        return Icons.weekend;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'directions_bike':
        return Icons.directions_bike;
      default:
        return Icons.fitness_center;
    }
  }
}

// Modern Loading Dialog
class ModernLoadingDialog extends StatefulWidget {
  const ModernLoadingDialog({Key? key}) : super(key: key);

  @override
  _ModernLoadingDialogState createState() => _ModernLoadingDialogState();
}

class _ModernLoadingDialogState extends State<ModernLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFF4ECDC4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              "Setting up your profile...",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This will only take a moment",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Success Dialog
class SuccessDialog extends StatefulWidget {
  const SuccessDialog({Key? key}) : super(key: key);

  @override
  _SuccessDialogState createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
    
    // Auto close after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xFF4ECDC4),
                      shape: BoxShape.circle,
                    ),
                    child: Transform.scale(
                      scale: _checkAnimation.value,
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Profile Complete! 🎉",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome to your fitness journey!",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
