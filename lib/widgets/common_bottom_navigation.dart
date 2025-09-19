// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// Ortak Bottom Navigation Bar Widget'ı - Güçlü camsı efekt ve floating tasarım
class CommonBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onRandevuTap;

  const CommonBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onRandevuTap,
  });

  @override
  Widget build(BuildContext context) {
    // Web'de navbar'ı gizle
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Sadece desktop ekranlarda navbar'ı gizle (mobil ve tablet'te göster)
    if (screenWidth > 1200) {
      return const SizedBox.shrink();
    }

    // Tablet'te de mobil boyutları kullan (overflow önlemek için)
    final isTablet = screenWidth > 600;
    // Bottom overflow hatasını önlemek için yükseklik artırıldı
    final navbarHeight =
        90.0; // 1px overflow hatasını önlemek için daha da artırıldı
    final fabSize = 56.0; // Hem mobil hem tablet için aynı
    final itemSize = 40.0; // Home/Profile ikon kapsayıcı biraz büyütüldü
    final iconSize = 22.0; // Home/Profile ikon boyutu bir tık artırıldı
    final fontSize = 9.0; // (Kullanılmıyor) Önceden metin için

    final lang = Provider.of<LanguageProvider>(context);
    return Container(
      height: navbarHeight, // Tablet için daha büyük
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ana bottom navigation bar - camsız, tamamen şeffaf overlay
          Positioned(
            bottom: 15, // 1px overflow hatasını önlemek için daha da artırıldı
            left: 16,
            right: 16,
            child: Container(
              height:
                  65, // 1px overflow hatasını önlemek için daha da artırıldı
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          0,
                          Icons.home_rounded,
                          lang.t('home_title'),
                          isDarkMode,
                          itemSize: itemSize,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        const SizedBox(
                          width: 52,
                        ), // Orta boşluk (FAB için) - Hem mobil hem tablet için aynı
                        _buildNavItem(
                          1,
                          Icons.person_rounded,
                          lang.t('profile_title'),
                          isDarkMode,
                          itemSize: itemSize,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // FAB - Randevu butonu (Profesyonel gradient)
          Positioned(
            top: 14, // Orta hizalama için ayarlandı (daha önce -4 idi)
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onRandevuTap,
                child: Container(
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [SiriusColors.accent, SiriusColors.accent2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 22, // Hem mobil hem tablet için aynı
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isDarkMode, {
    double itemSize = 34.0,
    double iconSize = 18.0,
    double fontSize = 8.5,
  }) {
    final isActive = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // İkon container - Profesyonel aktif durum
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  width: itemSize,
                  height: itemSize,
                  decoration: BoxDecoration(
                    color: isActive
                        ? SiriusColors.accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(itemSize / 2),
                    border: Border.all(
                      color: isActive
                          ? SiriusColors.accent.withValues(alpha: 0.4)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: SiriusColors.accent.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: isActive ? 1.08 : 1.0,
                    child: Icon(
                      icon,
                      color: isDarkMode
                          ? Colors.white
                          : Colors.black, // Light mod: siyah, Dark mod: beyaz
                      size: iconSize,
                    ),
                  ),
                ),
                // Label kaldırıldı (Home/Profile yazıları gizlendi)
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Ortak AppBar - Mobilde sağda hamburger, büyük ekranda solda; dil/tema ikonları içermez
class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkMode;
  final String? logoUrl;
  final String businessName;
  final VoidCallback onMenuPressed;
  final Color? backgroundColor;
  final List<Widget>? rightActionsWeb;
  final Widget? leadingOverride;
  final Function(String)? onNavigationTap; // Navigation callback'i eklendi
  final Widget? leading; // Leading widget eklendi
  final bool showDefaultNavButtons; // Varsayılan web nav butonlarını göster

  const CommonAppBar({
    super.key,
    required this.isDarkMode,
    required this.logoUrl,
    required this.businessName,
    required this.onMenuPressed,
    this.backgroundColor,
    this.rightActionsWeb,
    this.leadingOverride,
    this.onNavigationTap, // Navigation callback parametresi
    this.leading, // Leading widget parametresi
    this.showDefaultNavButtons = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  // Ortak navigation butonlarını oluştur
  List<Widget> _buildCommonNavigationButtons(BuildContext context) {
    return [
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: () {
          if (onNavigationTap != null) {
            onNavigationTap!('home');
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        child: Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('navbar_home'),
          style: const TextStyle(
            fontFamily: 'Cormorant',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: () {
          if (onNavigationTap != null) {
            onNavigationTap!('about');
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        child: Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('navbar_about'),
          style: const TextStyle(
            fontFamily: 'Cormorant',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: () {
          if (onNavigationTap != null) {
            onNavigationTap!('menu');
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        child: Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('navbar_menu'),
          style: const TextStyle(
            fontFamily: 'Cormorant',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: () {
          if (onNavigationTap != null) {
            onNavigationTap!('team');
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        child: Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('navbar_team'),
          style: const TextStyle(
            fontFamily: 'Cormorant',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: () {
          if (onNavigationTap != null) {
            onNavigationTap!('contact');
          } else {
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        child: Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('navbar_contact'),
          style: const TextStyle(
            fontFamily: 'Cormorant',
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Tablet boyutlarında da mobil görünümü kullan (web görünümü sadece >1200px)
    final bool isMobile = MediaQuery.of(context).size.width < 1200;
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.transparent,
      elevation: 0,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.3),
                border: Border(
                  bottom: BorderSide(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading:
          leading ?? // Önce leading parametresi kontrol et
          leadingOverride ?? // Sonra leadingOverride kontrol et
          (isMobile
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.menu,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  onPressed: onMenuPressed,
                )),
      title: Row(
        children: [
          if (logoUrl != null && logoUrl!.isNotEmpty)
            (logoUrl!.startsWith('http')
                ? Image.network(
                    logoUrl!,
                    height: 40,
                    width: 40,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.storefront_rounded, size: 32),
                  )
                : const Icon(Icons.storefront_rounded, size: 32))
          else
            const Icon(Icons.storefront_rounded, size: 32),
          const SizedBox(width: 12),
          Text(
            businessName,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.normal,
              fontFamily: 'Cormorant',
            ),
          ),
        ],
      ),
      actions: [
        // Önce ortak navigation butonları (isteğe bağlı)
        if (!isMobile && showDefaultNavButtons)
          ..._buildCommonNavigationButtons(context),
        // Sonra ekstra sağ aksiyonlar (varsa)
        if (!isMobile && (rightActionsWeb?.isNotEmpty ?? false))
          ...rightActionsWeb!,
        // Mobilde hamburger menü gizlendi
        // if (isMobile && leadingOverride == null)
        //   IconButton(
        //     icon: Icon(
        //       Icons.menu,
        //       color: isDarkMode ? Colors.white : Colors.black87,
        //     ),
        //     onPressed: onMenuPressed,
        //   ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.0),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
