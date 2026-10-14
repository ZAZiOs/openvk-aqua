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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: RetroZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: RetroZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: RetroZoomPageTransitionsBuilder(),
          TargetPlatform.windows: RetroZoomPageTransitionsBuilder(),
          TargetPlatform.linux: RetroZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: RetroZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Retro iOS-style zoom transition from center with depth.
class RetroZoomPageTransitionsBuilder extends PageTransitionsBuilder {
  const RetroZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Primary animation: zoom in from center (0.85 -> 1.0) and fade in
    final primaryScale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseCurve: Curves.easeInCubic,
      ),
    );

    final primaryFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
        reverseCurve: const Interval(0.35, 1.0, curve: Curves.easeIn),
      ),
    );

    // Secondary animation: when a new route is pushed on top of this one,
    // this route scales down slightly (1.0 -> 0.94) and subtly dims.
    final secondaryScale = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
        reverseCurve: Curves.easeInCubic,
      ),
    );

    final secondaryFade = Tween<double>(
      begin: 1.0,
      end: 0.70,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    final Widget incomingChild = FadeTransition(
      opacity: primaryFade,
      child: ScaleTransition(
        scale: primaryScale,
        alignment: Alignment.center,
        child: child,
      ),
    );

    return FadeTransition(
      opacity: secondaryFade,
      child: ScaleTransition(
        scale: secondaryScale,
        alignment: Alignment.center,
        child: incomingChild,
      ),
    );
  }
}
