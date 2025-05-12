import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  var _emailController = TextEditingController();
  var _auth = FirebaseAuth.instance;
  String message = '';
  bool isLoading = false; // Track loading state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: Text('Reset Password'),
        backgroundColor: Colors.deepPurple,

        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: Colors.white, size: 25),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
            child: Column(

              children: [
                Container(height: 160,width: 160,child: Image.asset('assets/logo.png'),),
                SizedBox(height: 50,),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Enter Your Email to send you Reset Link',style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black87),),
                ),
                SizedBox(height: 20),
                TextField(
                  style: TextStyle(color: Colors.black54),
                  controller: _emailController,
                  obscureText: false,
                  decoration: const InputDecoration(
                    labelText: 'Enter your registered E-Mail',
                    labelStyle: TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 20),
                isLoading
                    ? CircularProgressIndicator() // Show loading indicator when isLoading is true
                    : InkWell(
                  onTap: () async {
                    setState(() {
                      isLoading = true; // Start loading
                    });

                    try {
                      await _auth.sendPasswordResetEmail(email: _emailController.text.trim().toString());

                      // Show pop-up dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false, // Prevent dismissing by tapping outside
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Password Reset'),
                            content: Text('Email will be sent if it is registered.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close the dialog
                                  Navigator.pop(context); // Navigate to the previous screen
                                },
                                child: Text('Okay'),
                              ),
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      setState(() {
                        print(e.toString());
                        message = e.toString();
                      });
                    } finally {
                      setState(() {
                        isLoading = false; // Stop loading
                      });
                    }
                  },
                  child: Container(
                    height: 60,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.lightBlueAccent,
                          blurStyle: BlurStyle.outer,
                          blurRadius: 2,
                          spreadRadius: 0.5,
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Send Email',
                        style: TextStyle(
                            color: Colors.white, fontSize: 25, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
