import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:pigcare/core/views/dashboard/dashboard_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Pigpen Management",
      description: "Track all your pigpens and their populations at a glance",
      icon: Icons.home_work,
      color: Colors.green.shade100,
      features: [
        "View total pigpen count",
        "See pigs per pen",
        "Quick status overview"
      ],
    ),
    OnboardingPage(
      title: "Pig Tracking",
      description: "Monitor individual pigs with detailed records",
      icon: Icons.pets,
      color: Colors.blue.shade100,
      features: [
        "Track growth and health",
        "Manage breeding",
        "Individual ID system"
      ],
    ),
    OnboardingPage(
      title: "Farm Operations",
      description: "Complete farm management solution",
      icon: Icons.agriculture,
      color: Colors.orange.shade100,
      features: [
        "Feed management",
        "Event tracking",
        "Expenses & sales",
        "Reports generation"
      ],
    ),
  ];

  void _completeOnboarding() async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('introCompleted', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const DashboardScreen(
                allPigs: [],
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _pages[_currentPage].color,
                  Colors.white,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button (top-right)
                if (_currentPage != _pages.length - 1)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      return OnboardingPageContent(page: _pages[index]);
                    },
                  ),
                ),

                // Page indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: Colors.green,
                      dotColor: Colors.grey,
                      spacing: 10,
                      expansionFactor: 3,
                    ),
                  ),
                ),

                // Next/Get Started button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        elevation: 2,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? "Get Started"
                            : "Next",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageContent extends StatelessWidget {
  final OnboardingPage page;

  const OnboardingPageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon illustration
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: Colors.green[800],
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Feature list
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: page.features
                .map((feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}
