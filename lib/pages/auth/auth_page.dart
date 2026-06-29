import 'package:flutter/material.dart';
import '../../widgets/auth/login_form.dart';
import '../../widgets/auth/signup_form.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Text(
              'Welcome to PureSip',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700]),
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabController,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green,
              tabs: const [
                Tab(text: 'Login'),
                Tab(text: 'Sign Up'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  LoginForm(),
                  SignupForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
