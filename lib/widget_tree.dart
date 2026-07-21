import 'package:ride_sharing_app/widgets/auth.dart';
import 'screens/nav_bar_screen.dart';
import 'package:ride_sharing_app/screens/login_screen.dart';
import 'package:flutter/material.dart';

class WidgetTree extends StatefulWidget{
  const WidgetTree({Key? key}) : super(key:key);

  @override
  State<WidgetTree> createState() => _WidgetTreeState();

}

class _WidgetTreeState extends State<WidgetTree>{
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Auth.instance.authStateChanges,
      builder: (context,snapshot){
        if(snapshot.hasData){
          return HamburgerMenuScreen();
        }
        else{
          return const LoginPage();
          //return HamburgerMenuScreen();

        }
      },
    );
  }

}
