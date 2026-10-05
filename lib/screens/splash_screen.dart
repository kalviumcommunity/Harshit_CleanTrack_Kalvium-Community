import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget{
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();

}

class _SplashScreenState extends State<SplashScreen>{
  @override
  void initState(){
    super.initState();

    // wait for 3 second, then move to next screen
    Future.delayed(const Duration(seconds: 3,), (){
      //The screen may have been removed before the dlay finished
      if(!mounted) return;

      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (context) => const LoginPlaceholderScreen(),
        ),
      );
    });
  }  

@override
Widget build(BuildContext context){
  return Scaffold(
    backgroundColor: const Color(0xFFFFFFFF),

    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // logo
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF172B4D),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 42,
            )
          ),

          const SizedBox(height: 20,),

          // App title
          const Text(
            'CleanTrack',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF172B4D),
            )
          ),

          const SizedBox(height: 8),

          // App subtitle
          const Text(
            'Hospital Housekeeping Management',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
          )

        ],
      )
    )
  );
}

}

class LoginPlaceholderScreen extends StatelessWidget{
  const LoginPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context){
    return const Scaffold(
      body: Center(
        child: Text(
          'Login Screen',
          style: TextStyle(fontSize: 24),
        )
      )
    );
  }
}