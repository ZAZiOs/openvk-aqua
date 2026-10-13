import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/auth_handler.dart';
import '../../widgets/retro_loading_indicator.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({super.key, required this.text, required this.onPressed});

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 25),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isPressed
                  ? const [Color(0xFF305D88), Color(0xFF15447C)]
                  : const [Color(0xFF4983BA), Color(0xFF1E62B3)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 50),
            child: Text(
              widget.text,
              style: const TextStyle(
                color: Color(0xFFDFDFDF),
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginView extends StatefulWidget {
  final AuthHandler authHandler;
  final VoidCallback onLoginSuccess;

  const LoginView({
    super.key,
    required this.authHandler,
    required this.onLoginSuccess,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _isLoading = false;
  bool _isSheetExpanded = false;
  double _initialFraction = 0.12;
  static const double _maxFraction = 0.65;

  String? _errorMessage;
  List<OpenVkInstance> _instances = [];
  OpenVkInstance? _selectedInstance;

  @override
  void initState() {
    super.initState();
    _loadInstances();
    _sheetController.addListener(_onSheetScroll);
  }

  void _onSheetScroll() {
    if (!_sheetController.isAttached) return;
    final isExpanded =
        _sheetController.size > ((_initialFraction + _maxFraction) / 2);
    if (isExpanded != _isSheetExpanded) {
      setState(() => _isSheetExpanded = isExpanded);
    }
  }

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;
    if (_isSheetExpanded) {
      _sheetController.animateTo(
        _initialFraction,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _sheetController.animateTo(
        _maxFraction,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _loadInstances() async {
    final list = await widget.authHandler.getInstances();
    if (!mounted) return;
    setState(() {
      _instances = list;
      if (list.isNotEmpty) {
        _selectedInstance = list.firstWhere(
          (i) => i.isActive,
          orElse: () => list.first,
        );
      }
    });
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetScroll);
    _sheetController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _doLogin({String? twoFactorCode}) async {
    final username = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Введите логин и пароль');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final instanceUrl = _selectedInstance?.baseUrl ?? 'https://api.openvk.org';
    final result = await widget.authHandler.login(
      username: username,
      password: password,
      instanceBaseUrl: instanceUrl,
      code: twoFactorCode,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _isLoading = false);
      widget.onLoginSuccess();
    } else {
      final err = result.errorOrNull?.message;
      if (err == 'need_2fa') {
        setState(() => _isLoading = false);
        _showTwoFactorDialog();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = err ?? 'Ошибка авторизации';
        });
      }
    }
  }

  Future<void> _launchRestorePassword() async {
    try {
      final baseUrl = _selectedInstance?.baseUrl ?? 'https://api.openvk.org';
      final webBaseUrl = baseUrl.replaceFirst('api.', '');
      final Uri url = Uri.parse('$webBaseUrl/restore');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Restore password launch error: $e');
    }
  }

  Future<void> _deleteInstance(OpenVkInstance inst) async {
    await widget.authHandler.deleteInstance(inst.id);
    await _loadInstances();
  }

  void _showAddInstanceDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => _AddInstanceDialogContent(
        onAdd: (name, url) async {
          final newInst = await widget.authHandler.addInstance(
            name: name,
            url: url,
          );
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
          if (mounted) {
            await _loadInstances();
            setState(() => _selectedInstance = newInst);
          }
        },
      ),
    );
  }

  void _showTwoFactorDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => _TwoFactorDialogContent(
        onSubmit: (code) async {
          Navigator.pop(ctx);
          await _doLogin(twoFactorCode: code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 720;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E1E1E), Color(0xFF0B0B0B)],
              ),
            ),
            child: isWide
                ? _buildWideLayout(constraints)
                : _buildMobileLayout(constraints),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Stack(
      children: [
        Row(
          children: [
            _buildSidebar(constraints.maxHeight),
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: _buildLoginForm(),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildMobileLayout(BoxConstraints constraints) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double navbar = MediaQuery.of(context).padding.bottom;
    final double screenHeight = constraints.maxHeight;
    final double headerPx = 75.0 + navbar;
    _initialFraction = (headerPx / screenHeight).clamp(0.08, 0.85);

    return Stack(
      children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: headerPx + 16,
              ),
              child: AnimatedPadding(
                padding: EdgeInsets.only(bottom: keyboardHeight),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),

        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _initialFraction,
          minChildSize: _initialFraction,
          maxChildSize: _maxFraction,
          snap: true,
          snapSizes: [_initialFraction, _maxFraction],
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 20,
                        top: 0,
                      ),
                      children: [
                        _buildMobileHeader(
                          _selectedInstance?.name ?? 'OpenVK',
                          _selectedInstance?.domain ?? 'api.openvk.org',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildInstancesCard(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: navbar,
            color: const Color(0xFF000000),
            width: double.infinity,
          ),
        ),

        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildSidebar(double height) {
    return Container(
      width: 330,
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(right: BorderSide(color: Color(0xFF222222), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedInstance?.name ?? 'OpenVK',
                    style: const TextStyle(
                      color: Color(0xFFAEAEAE),
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(${_selectedInstance?.domain ?? 'api.openvk.org'})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildInstancesCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              'assets/img/logo_full.png',
              width: 250,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'OpenVK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 35),

          _buildTextField('Телефон или e-mail', controller: _loginController),
          const SizedBox(height: 14),

          _buildTextField(
            'Пароль',
            isPassword: true,
            controller: _passwordController,
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFC53535),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            const SizedBox(height: 28),

          Center(
            child: CustomButton(text: 'Войти', onPressed: _doLogin),
          ),
          const SizedBox(height: 24),

          Center(child: _buildForgotPassword()),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(String instanceName, String instanceDomain) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      instanceName,
                      style: const TextStyle(
                        color: Color(0xFFAEAEAE),
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '($instanceDomain)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isSheetExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              color: const Color(0xFF515151),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstancesCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0F0F0F),
        border: Border.all(color: const Color(0xFF1E1E1E), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_instances.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Нет доступных инстансов',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    ..._instances.asMap().entries.map((entry) {
                      final index = entry.key;
                      final inst = entry.value;
                      final isSelected = _selectedInstance?.id == inst.id;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index > 0)
                            const Divider(
                              color: Color(0xFF181818),
                              height: 1,
                              thickness: 1,
                            ),
                          InkWell(
                            onTap: () {
                              setState(() => _selectedInstance = inst);
                              widget.authHandler.selectInstance(inst.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      inst.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFFB0B0B0),
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  Flexible(
                                    child: Text(
                                      inst.domain,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  if (isSelected) ...[
                                    const Icon(
                                      Icons.check,
                                      color: Color(0xFF4983BA),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                  ],

                                  if (_instances.length > 1 &&
                                      inst.baseUrl != 'https://api.openvk.org')
                                    InkWell(
                                      onTap: () => _deleteInstance(inst),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Icon(
                                          Icons.more_horiz,
                                          color: Color(0xFF555555),
                                          size: 20,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.more_horiz,
                                      color: Color(0xFF383838),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  const Divider(
                    color: Color(0xFF181818),
                    height: 1,
                    thickness: 1,
                  ),
                  InkWell(
                    onTap: _showAddInstanceDialog,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Color(0xFF4983BA), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Добавить инстанс',
                              style: TextStyle(
                                color: Color(0xFF4983BA),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return GestureDetector(
      onTap: _launchRestorePassword,
      child: Text(
        'Забыли пароль?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 16,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: const Center(
          child: RetroLoadingIndicator(size: 38),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint, {
    bool isPassword = false,
    TextEditingController? controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECECEC), Color(0xFFFEFEFE)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, -10),
                    ),
                    const BoxShadow(
                      color: Color(0xFFECECEC),
                      spreadRadius: -2.0,
                      blurRadius: 8.0,
                    ),
                  ],
                ),
              ),
            ),
            TextField(
              controller: controller,
              obscureText: isPassword,
              style: const TextStyle(color: Color(0xFF1E1E1E), fontSize: 18),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF757575)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetroModalDialog extends StatelessWidget {
  final Widget child;
  final VoidCallback onClose;
  final double width;

  const _RetroModalDialog({
    required this.child,
    required this.onClose,
    this.width = 300,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: SizedBox(
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                child: child,
              ),

              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE24343), Color(0xFFA61E1E)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 15, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetroSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RetroSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: value ? const Color(0xFF439E38) : const Color(0xFF202020),
          border: Border.all(
            color: value ? const Color(0xFF337E2A) : const Color(0xFF383838),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? const Color(0xFFE8E8E8) : const Color(0xFF5A5A5A),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildModalTextField(
  String hint, {
  required TextEditingController controller,
  bool isPassword = false,
  TextInputType? keyboardType,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(7),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFECECEC), Color(0xFFFEFEFE)],
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, -10),
                  ),
                  const BoxShadow(
                    color: Color(0xFFECECEC),
                    spreadRadius: -2.0,
                    blurRadius: 8.0,
                  ),
                ],
              ),
            ),
          ),
          TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(color: Color(0xFF1E1E1E), fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildModalButton({
  required String text,
  required VoidCallback onTap,
  bool isLoading = false,
}) {
  return Center(
    child: SizedBox(
      width: 140,
      height: 38,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1B416C), width: 1),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2F6399), Color(0xFF1D4777)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: isLoading ? null : onTap,
            child: Center(
              child: isLoading
                  ? const RetroLoadingIndicator(size: 18)
                  : Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AddInstanceDialogContent extends StatefulWidget {
  final Future<void> Function(String name, String url) onAdd;

  const _AddInstanceDialogContent({required this.onAdd});

  @override
  State<_AddInstanceDialogContent> createState() =>
      _AddInstanceDialogContentState();
}

class _AddInstanceDialogContentState extends State<_AddInstanceDialogContent> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isHttps = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (url.startsWith('https://')) {
      url = url.substring('https://'.length);
    } else if (url.startsWith('http://')) {
      url = url.substring('http://'.length);
    }
    url = url.replaceAll(RegExp(r'/+$'), '');

    final fullUrl = '${_isHttps ? 'https://' : 'http://'}$url';
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : url;

    setState(() => _isSubmitting = true);
    try {
      await widget.onAdd(name, fullUrl);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RetroModalDialog(
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/login/connect-icon.png',
            height: 58,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),

          const Text(
            'Введите данные искомого\nинстанса.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),

          _buildModalTextField(
            'Название инстанса',
            controller: _nameController,
          ),
          const SizedBox(height: 10),

          _buildModalTextField(
            'Ссылка на инстанс',
            controller: _urlController,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Text(
                'Подключение через HTTPS',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _RetroSwitch(
                value: _isHttps,
                onChanged: (val) => setState(() => _isHttps = val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildModalButton(
            text: 'Далее',
            isLoading: _isSubmitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

class _TwoFactorDialogContent extends StatefulWidget {
  final Future<void> Function(String code) onSubmit;

  const _TwoFactorDialogContent({required this.onSubmit});

  @override
  State<_TwoFactorDialogContent> createState() =>
      _TwoFactorDialogContentState();
}

class _TwoFactorDialogContentState extends State<_TwoFactorDialogContent> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(code);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RetroModalDialog(
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/login/shield-icon.png',
            height: 64,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),

          const Text(
            'Введите код двухфакторной\nаутентификации.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),

          _buildModalTextField(
            'Код 2FA',
            controller: _codeController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          _buildModalButton(
            text: 'Далее',
            isLoading: _isSubmitting,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
