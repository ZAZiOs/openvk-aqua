import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RetroTheme {
  const RetroTheme._();

  static const Color headerBlueTop = Color(0xFF3B6799);
  static const Color headerBlueBottom = Color(0xFF23446D);
  static const Color headerBorder = Color(0xFF1B3251);

  static const Color vkBlue = Color(0xFF4983BA);
  static const Color vkBlueDark = Color(0xFF1E62B3);
  static const Color vkBluePressedTop = Color(0xFF305D88);
  static const Color vkBluePressedBottom = Color(0xFF15447C);

  static const Color scaffoldBackground = Color(0xFFF0F2F5);
  static const Color cardBackground = Colors.white;
  static const Color itemDivider = Color(0xFFE3E5E8);

  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF656565);
  static const Color textMuted = Color(0xFF909399);
  static const Color textLink = Color(0xFF2B587A);

  static const Color msgInBubble = Color(0xFFFFFFFF);
  static const Color msgInBorder = Color(0xFFD6D9DE);
  static const Color msgOutBubble = Color(0xFFEBF2FA);
  static const Color msgOutBorder = Color(0xFFC7D7E8);

  static const Color navBarTop = Color(0xFF262626);
  static const Color navBarBottom = Color(0xFF121212);
  static const Color navBarBorder = Color(0xFF363636);
  static const Color navBarActiveGlow = Color(0xFF2688E6);

  static const Color badgeBlue = Color(0xFF4C75A3);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [headerBlueTop, headerBlueBottom],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [vkBlue, vkBlueDark],
  );

  static const LinearGradient buttonPressedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [vkBluePressedTop, vkBluePressedBottom],
  );

  static const LinearGradient navBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navBarTop, navBarBottom],
  );

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: vkBlue,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: vkBlue,
        secondary: vkBlueDark,
        surface: cardBackground,
      ),
      dividerColor: itemDivider,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF121212),
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Color(0xFF000000),
        ),
      ),
    );
  }
}
