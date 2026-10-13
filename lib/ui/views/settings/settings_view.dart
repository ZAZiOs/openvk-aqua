import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  final VoidCallback? onLogout;

  const SettingsView({
    super.key,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC3D1E0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLogout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        size: 20,
                        color: Color(0xFFD33A3A),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Выход',
                          style: TextStyle(
                            fontSize: 15.5,
                            color: Color(0xFFD33A3A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFFB0BDCB),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
