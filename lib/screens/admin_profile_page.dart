import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_styles.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../services/db_service.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  // Dark mode kontrolü
  bool get _isDarkMode {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      if (!themeProvider.isInitialized) {
        return false;
      }
      return themeProvider.isDarkMode;
    } catch (e) {
      return false;
    }
  }

  // İşletme bilgileri
  Map<String, dynamic>? _isletme;
  String? _isletmeId;

  @override
  void initState() {
    super.initState();
    _loadIsletme();
  }

  Future<void> _loadIsletme() async {
    try {
      // İşletme ID'sini çözümle
      _isletmeId = await DbService.resolveIsletmeId();
      if (_isletmeId == null) return;

      final isletme = await DbService.getIsletmeById(_isletmeId!);
      if (mounted) {
        setState(() {
          _isletme = isletme;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('İşletme bilgileri yüklenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).iconTheme.color ?? Colors.black87,
          ),
        ),
        title: Text(
          'İşletme Bilgileri',
          style: TextStyle(
            color:
                Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isDarkMode
                ? [Colors.grey[900]!, Colors.black]
                : [const Color(0xFFE5E2DB), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: currentUser != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık Kartı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isDarkMode
                                ? [Colors.blueGrey[800]!, Colors.blueGrey[700]!]
                                : [Colors.blue[400]!, Colors.blue[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'İşletme Bilgileri',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Hesap ve İşletme Bilgileri',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Hesap Bilgileri
                      _buildSectionCard(
                        title: lang.t('account_info'),
                        icon: Icons.account_circle,
                        children: [
                          _buildInfoRow(
                            lang.t('email'),
                            currentUser.email ?? 'N/A',
                          ),
                          _buildInfoRow('Kullanıcı ID', currentUser.id),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // İşletme Bilgileri
                      if (_isletme != null) ...[
                        _buildSectionCard(
                          title: lang.t('business_info'),
                          icon: Icons.business,
                          children: [
                            _buildInfoRow(
                              lang.t('business_name'),
                              _isletme!['isim'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('business_type'),
                              _isletme!['tip'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('description'),
                              _isletme!['aciklama'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              'Hero Tagline',
                              _isletme!['hero_tagline'] ?? 'N/A',
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // İletişim Bilgileri
                        _buildSectionCard(
                          title: lang.t('contact_info'),
                          icon: Icons.contact_phone,
                          children: [
                            _buildInfoRow(
                              lang.t('phone'),
                              _isletme!['telefon'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('email'),
                              _isletme!['email'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('website'),
                              _isletme!['web_site'] ?? 'N/A',
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Adres Bilgileri
                        _buildSectionCard(
                          title: lang.t('address_details'),
                          icon: Icons.location_on,
                          children: [
                            _buildInfoRow(
                              lang.t('address'),
                              _isletme!['adres'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('city'),
                              _isletme!['sehir'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('district'),
                              _isletme!['ilce'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              lang.t('postal_code'),
                              _isletme!['posta_kodu'] ?? 'N/A',
                            ),
                          ],
                        ),
                      ] else
                        Center(
                          child: CircularProgressIndicator(
                            color: SiriusColors.accent,
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Text(
                      'Kullanıcı bilgileri yüklenemedi',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.grey[800]!.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.1,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SiriusColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: SiriusColors.accent, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
