import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/txa_language.dart';
import 'screens/tv_splash_screen.dart';

class DongPhimTvApp extends StatelessWidget {
  const DongPhimTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TxaLanguage>(
      builder: (context, lang, child) {
        return MaterialApp(
          title: 'DongMePhim TV',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF090A0F),
            primaryColor: const Color(0xFF737DFD),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF737DFD),
              secondary: Color(0xFFA855F7),
              surface: Color(0xFF111827),
            ),
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          ),
          home: const TvSplashScreen(),
        );
      },
    );
  }
}

