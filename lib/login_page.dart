import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
//import 'my_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> writeCache() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');

    print("📦 PREF LOADED:");
    print("Username: $savedUser");
    print("Password: $savedPass");

    if (_usernameController.text == savedUser &&
        _passwordController.text == savedPass) {
      print("✅ Login successful!");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeTest()),
      );
    } else {
      print("❌ Wrong username or password!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sai tài khoản hoặc mật khẩu!')),
      );
    }
  }

  Future<void> _signUp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _usernameController.text);
    await prefs.setString('password', _passwordController.text);

    print("🔥 PREF IS SAVED!");
    print("Username: ${_usernameController.text}");
    print("Password: ${_passwordController.text}");

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tạo tài khoản thành công!')));
  }

  Future<void> _forgotPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final pass = prefs.getString('password') ?? 'Chưa có mật khẩu nào được lưu';
    print("🔍 Forgot password requested → $pass");

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Mật khẩu của bạn: $pass')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min, // Giúp căn giữa icon + text
          children: const [
            Icon(FontAwesomeIcons.lock, size: 24, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'LOGIN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 450, // chiều rộng form  login
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, // nền trắng
                borderRadius: BorderRadius.circular(12), // bo góc
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 10,
                    offset: const Offset(2, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.black, // màu viền
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    FontAwesomeIcons.userLock,
                    size: 45,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Đăng nhập",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "Tài khoản",
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Mật khẩu",
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: writeCache,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),

                      child: const Text("Đăng nhập"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _signUp,
                    child: const Text("Tạo tài khoản mới"),
                  ),
                  TextButton(
                    onPressed: _forgotPassword,
                    child: const Text("Quên mật khẩu"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
