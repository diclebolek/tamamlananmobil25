// ignore_for_file: duplicate_import, unused_field, unnecessary_import, deprecated_member_use, avoid_print
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter/rendering.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
// duplicate import removed
import '../constants/app_styles.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';
// import '../widgets/common_bottom_navigation.dart';
import '../providers/language_provider.dart';
import '../constants/app_styles.dart';
import '../providers/language_provider.dart' show AppLanguage;
import '../models/appointment.dart';
// import '../models/service.dart';
// import '../models/employee.dart';
import '../services/db_service.dart';
import 'home_screen.dart' as home show CommonAppBar;
import 'package:image_picker/image_picker.dart';
import 'dart:ui'; // Added for ImageFilter

// Lightweight local holder for story button config
class _StoryBtn {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  _StoryBtn(this.title, this.color, this.icon, this.onTap);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Dark mode ve dil seçenekleri
  bool _isDarkMode = false;
  String _activeStory = '';
  final TextEditingController _contactSubjectController =
      TextEditingController();
  final TextEditingController _contactMessageController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Dinamik işletme bilgileri
  Map<String, dynamic>? _isletme;
  Map<String, dynamic>? _supaCustomer;

  // Randevu listesi için
  List<Appointment> _userAppointments = [];
  bool _isLoadingAppointments = true;
  // Randevu filtre/sıralama durumları
  String _appointmentsFilter = 'ALL'; // ALL, PAST, PENDING, APPROVED, CANCELED
  bool _sortDesc = true; // true: Yeniden eskiye

  // Servis ve çalışan listeleri için (gerektiğinde kullanılır)
  // List<Service> _services = [];
  // List<Employee> _employees = [];

  // Drawer kontrolü için Scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Müşteri bilgileri için controller'lar
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserAppointments();
    _loadServicesAndEmployees();
    _loadIsletme();
    _loadSupabaseCustomer();
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _contactSubjectController.dispose();
    _contactMessageController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Durum çevirisi için yardımcı fonksiyon
  String _getTranslatedStatus(String status) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    switch (status.toLowerCase()) {
      case 'approved':
        return lang.t('approved');
      case 'pending':
        return lang.t('pending');
      case 'canceled':
      case 'cancelled':
        return lang.t('canceled');
      default:
        return status; // Bilinmeyen durumlar için orijinal metni döndür
    }
  }

  // Web sağ panel içerikleri
  Widget _buildProfileEditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('profile_info'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildProfileCard(),
      ],
    );
  }

  Widget _buildContactSection() {
    return _buildContactCard();
  }

  Widget _buildQuickAppointmentSection() {
    return _buildQuickAppointmentCard();
  }

  // Basit içerik kartları (web sağ panel)
  Widget _buildProfileCard() {
    // Inline profil düzenleme formu (dialog yerine sağ panelde)
    return _buildProfileSettingsFormInline();
  }

  Widget _buildContactCard() {
    return _buildContactFormInline();
  }

  Widget _buildQuickAppointmentCard() {
    return _buildQuickAppointmentInline();
  }

  Widget _buildProfileSettingsFormInline() {
    // Inline olarak basit profil düzenleme alanı (isim/soyisim/telefon/email/şifre)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('name'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('surname'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('phone'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('email'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('new_password'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('confirm_password'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SiriusColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Şifre eşleşme kontrolü
              if (_newPasswordController.text.isNotEmpty &&
                  _newPasswordController.text !=
                      _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t('passwords_do_not_match')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              _saveProfileChanges();
            },
            icon: const Icon(Icons.save),
            label: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('save'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactFormInline() {
    final Map<String, dynamic>? biz = _isletme is Map<String, dynamic>
        ? _isletme as Map<String, dynamic>
        : null;
    final String tel = (biz?['telefon'] ?? biz?['phone'] ?? '-').toString();
    final String mail = (biz?['email'] ?? '-').toString();

    // Çalışma saatlerini başlangıç ve bitiş saatlerinden oluştur
    String calisma = '-';
    if (biz != null) {
      final baslangic = biz['calisma_saati_baslangic']?.toString();
      final bitis = biz['calisma_saati_bitis']?.toString();

      if (baslangic != null &&
          bitis != null &&
          baslangic.isNotEmpty &&
          bitis.isNotEmpty) {
        // Saat formatını düzenle (HH:MM:SS -> HH:MM)
        final baslangicFormatted = baslangic.length >= 5
            ? baslangic.substring(0, 5)
            : baslangic;
        final bitisFormatted = bitis.length >= 5
            ? bitis.substring(0, 5)
            : bitis;
        calisma =
            'Pazartesi - Cumartesi: $baslangicFormatted - $bitisFormatted';
      } else {
        // Fallback: eski alanları kontrol et
        calisma = (biz['contact_open'] ?? biz['calisma_saatleri'] ?? '-')
            .toString();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // İletişim bilgileri
        Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('contact_info'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 12),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('phone_label'),
          tel,
        ),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('email_label'),
          mail,
        ),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('working_hours_label'),
          calisma,
        ),
        const SizedBox(height: 16),
        const Divider(),
        // Soru Sormak İstiyorum bölümü kaldırıldı (yalnızca iletişim bilgileri gösterilir)
        const SizedBox(height: 0),
      ],
    );
  }

  Widget _buildContactInfoRowInline(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAppointmentInline() {
    return SizedBox(
      width: double.infinity,
      height: 200, // Sabit yükseklik ver
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/appointment'),
            icon: const Icon(Icons.add_circle),
            label: Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('profile_create_appointment'),
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                fontFamily: 'Cormorant',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: SiriusColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(0, 52),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                fontFamily: 'Cormorant',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsInline() {
    final Map<String, dynamic>? biz = _isletme is Map<String, dynamic>
        ? _isletme as Map<String, dynamic>
        : null;
    final String adres = (biz?['adres'] ?? '-').toString();
    final String ilce = (biz?['ilce'] ?? '-').toString();
    final String sehir = (biz?['sehir'] ?? '-').toString();
    final String postaKodu = (biz?['posta_kodu'] ?? '-').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('directions_dialog_title'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 12),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('address_label'),
          adres,
        ),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('district_label'),
          ilce,
        ),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(context, listen: false).t('city_label'),
          sehir,
        ),
        _buildContactInfoRowInline(
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('postal_code_label'),
          postaKodu,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SiriusColors.accent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 20,
                vertical: MediaQuery.of(context).size.width < 600 ? 8 : 12,
              ),
            ),
            onPressed: () {
              final fullAddress = '$adres, $ilce, $sehir $postaKodu';
              if (fullAddress != '-, -, - -') {
                // ignore: unused_local_variable
                final url =
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fullAddress)}';
                // launchUrl yerine basit bir snackbar göster
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Harita: $fullAddress')));
              }
            },
            icon: Icon(
              Icons.map,
              size: MediaQuery.of(context).size.width < 600 ? 16 : 20,
            ),
            label: Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('open_on_map'),
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                fontFamily: 'PlayfairDisplay',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalStoryMenu() {
    final items = [
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('edit_profile_info'),
        const Color(0xFFD2A6F5),
        Icons.edit,
        () {
          setState(() => _activeStory = 'edit');
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('profile_contact_us'),
        const Color(0xFF9EF7BF),
        Icons.chat_bubble,
        () {
          setState(() => _activeStory = 'contact');
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('profile_create_appointment'),
        const Color(0xFFFAA940),
        Icons.add_circle,
        () {
          setState(() => _activeStory = 'appointment');
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('get_directions'),
        const Color(0xFFF5928E),
        Icons.map,
        () {
          setState(() => _activeStory = 'directions');
        },
      ),
    ];

    Widget buildTile(_StoryBtn it, String key) {
      final bool active = _activeStory == key;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          onTap: it.onTap,
          leading: CircleAvatar(
            radius: 32,
            backgroundColor: active
                ? SiriusColors.accent
                : it.color.withValues(alpha: 0.6),
            child: Icon(it.icon, color: Colors.white),
          ),
          title: Text(
            it.title,
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              fontFamily: 'PlayfairDisplay',
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: active
              ? SiriusColors.accent.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildTile(items[0], 'edit'),
        buildTile(items[1], 'contact'),
        buildTile(items[2], 'appointment'),
        buildTile(items[3], 'directions'),
      ],
    );
  }

  Widget _buildStoryContentPane() {
    // ignore: unused_element
    Widget buildContainer(Widget child) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isDarkMode
              ? const Color(0xFF202020)
              : const Color(0xFFF7F5F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isDarkMode
                ? SiriusColors.accent.withValues(alpha: 0.35)
                : Colors.black,
          ),
        ),
        child: child,
      );
    }

    switch (_activeStory) {
      case 'edit':
        return _buildProfileEditSection();
      case 'contact':
        return _buildContactSection();
      case 'appointment':
        return _buildQuickAppointmentSection();
      case 'directions':
        return _buildDirectionsInline();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (_isDarkMode != themeProvider.isDarkMode) {
      setState(() {
        _isDarkMode = themeProvider.isDarkMode;
      });
    }
  }

  // Güvenli setState çağrısı için helper method
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // Navigation helpers to avoid triggering navigation during pointer/mouse updates

  // İşletme bilgilerini Supabase'den yükle
  Future<void> _loadIsletme() async {
    if (!mounted) return;

    try {
      final resolvedIsletmeId = await DbService.resolveIsletmeId(tip: 'gym');
      if (resolvedIsletmeId != null) {
        final isletme = await DbService.getIsletmeById(resolvedIsletmeId);
        if (mounted) {
          _safeSetState(() {
            _isletme = isletme;
          });
        }
      }
    } catch (_) {
      // Sessizce fallback'e bırak
    }
  }

  // Müşteri bilgilerini Supabase'den yükle
  Future<void> _loadSupabaseCustomer() async {
    if (!mounted) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null && user.email != null) {
        // Müşteri bilgilerini musteriler tablosundan getir
        final customerData = await client
            .from('musteriler')
            .select('*')
            .eq('email', user.email!)
            .maybeSingle();

        if (customerData != null) {
          _safeSetState(() {
            _supaCustomer = customerData;
            // Controller'ları doldur
            _firstNameController.text = (customerData['firstname'] ?? '')
                .toString();
            _lastNameController.text = (customerData['lastname'] ?? '')
                .toString();
            _emailController.text = (customerData['email'] ?? '').toString();
            _phoneController.text = (customerData['phone'] ?? '').toString();
          });
        }
      }
    } catch (e) {
      // Müşteri bilgileri yüklenirken hata oluştu
    }
  }

  // Profil fotoğrafını değiştir
  Future<void> _changeProfilePhoto() async {
    if (!mounted) return;

    try {
      // Galeri'den fotoğraf seç
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        // Yükleme göstergesi
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('photo_uploading')),
            backgroundColor: Colors.blue,
          ),
        );

        // Supabase Storage'a yükle
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;

        if (user != null && user.email != null) {
          final fileName =
              'profile_${user.email}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'profile_images/$fileName';

          // Dosyayı oku
          final bytes = await image.readAsBytes();

          // Storage'a yükle
          await client.storage.from('profiles').uploadBinary(filePath, bytes);

          // Public URL al
          final imageUrl = client.storage
              .from('profiles')
              .getPublicUrl(filePath);

          // Veritabanında profil fotoğrafı URL'ini güncelle
          await client
              .from('musteriler')
              .update({
                'profil_fotografi': imageUrl,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('email', user.email!);

          // Local state'i güncelle
          _safeSetState(() {
            if (_supaCustomer != null) {
              _supaCustomer!['profil_fotografi'] = imageUrl;
            }
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('profile_photo_updated_success')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('photo_upload_error')} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _updateCustomerProfile() async {
    if (!mounted) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user != null && _supaCustomer != null && user.email != null) {
        await client
            .from('musteriler')
            .update({
              'firstname': _firstNameController.text.trim(),
              'lastname': _lastNameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('email', user.email!);

        _safeSetState(() {
          _isEditingProfile = false;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.t('profile_updated_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('profile_update_error')} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadServicesAndEmployees() async {
    if (!mounted) return;

    // Servisler ve çalışanlar şu anda kullanılmıyor
    // try {
    //   final services = await DbService.getServices();
    //   final employees = await DbService.getEmployees();
    //   // _services = services;
    //   // _employees = employees;
    // } catch (e) {
    //   // Hata durumunda örnek veriler kullan
    // }
  }

  Future<void> _loadUserAppointments() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final customer = authProvider.currentCustomer;

    if (customer == null) {
      if (mounted) {
        setState(() {
          _userAppointments = [];
          _isLoadingAppointments = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAppointments = true;
      });
    }

    // Timeout ekle - 10 saniye sonra loading'i durdur
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoadingAppointments) {
        setState(() {
          _isLoadingAppointments = false;
        });
      }
    });

    try {
      List<Appointment> userAppointments = [];

      // Önce Supabase'den randevuları getirmeye çalış
      try {
        final client = Supabase.instance.client;
        final isletmeId = await DbService.resolveIsletmeId();

        int? effectiveCustomerId;
        // Supabase müşteri ID'si öncelikli
        final dynamic supaIdRaw = _supaCustomer?['customerid'];
        if (supaIdRaw != null) {
          effectiveCustomerId = int.tryParse(supaIdRaw.toString());
        }
        // AuthProvider'dan gelirse ikinci öncelik
        effectiveCustomerId ??= customer.customerId;
        // Hâlâ yoksa email ile musteriler tablosundan bul
        if (effectiveCustomerId == null &&
            client.auth.currentUser?.email != null) {
          try {
            final musteri = await client
                .from('musteriler')
                .select('customerid')
                .eq('email', client.auth.currentUser!.email!)
                .maybeSingle();
            if (musteri != null && musteri['customerid'] != null) {
              effectiveCustomerId = int.tryParse(
                musteri['customerid'].toString(),
              );
            }
          } catch (_) {}
        }

        if (effectiveCustomerId != null) {
          Future<List<dynamic>> fetchWith({bool withIsletme = true}) async {
            final int customerId = effectiveCustomerId!;

            var query = client
                .from('randevu')
                .select(
                  'randevu_id, customerid, calisan_id, hizmet_id, appointment_datetime, process, total_price, approval_status, notes, rating, rating_comment',
                )
                .eq('customerid', customerId);
            if (withIsletme && isletmeId != null) {
              query = query.eq('isletme_id', isletmeId);
            }
            return await query.order('appointment_datetime', ascending: false);
          }

          List<dynamic> rows = [];
          try {
            rows = await fetchWith(withIsletme: true);
          } catch (e) {
            // Sessiz geç: aşağıda isletme filtresi olmadan tekrar denenecek
          }
          if (rows.isEmpty) {
            try {
              rows = await fetchWith(withIsletme: false);
            } catch (e) {
              // Sessiz geç: Supabase randevu yükleme hatası durumunda legacy'e düşülecek
            }
          }

          if (rows.isNotEmpty) {
            final list = rows.cast<Map<String, dynamic>>();

            // İsim çözümleme için ID setleri
            final Set<String> hizmetIds = {
              for (final m in list)
                if (m['hizmet_id'] != null) m['hizmet_id'].toString(),
            };
            final Set<String> calisanIds = {
              for (final m in list)
                if (m['calisan_id'] != null) m['calisan_id'].toString(),
            };

            // Hizmet adlarını getir
            final Map<String, String> hizmetMap = {};
            if (hizmetIds.isNotEmpty) {
              try {
                final hRows = await client
                    .from('menu_hizmet_icerigi')
                    .select('menu_hizmet_icerigi_id, hizmet')
                    .inFilter('menu_hizmet_icerigi_id', hizmetIds.toList());
                for (final r in (hRows as List)) {
                  final rm = r as Map<String, dynamic>;
                  final key = rm['menu_hizmet_icerigi_id']?.toString();
                  final val = rm['hizmet']?.toString();
                  if (key != null && val != null) hizmetMap[key] = val;
                }
              } catch (_) {}
            }

            // Çalışan adlarını getir
            final Map<String, String> calisanMap = {};
            if (calisanIds.isNotEmpty) {
              try {
                final cRows = await client
                    .from('calisanlar')
                    .select('id, ad, soyad')
                    .inFilter('id', calisanIds.toList());
                for (final r in (cRows as List)) {
                  final rm = r as Map<String, dynamic>;
                  final key = rm['id']?.toString();
                  final ad = (rm['ad'] as String?) ?? '';
                  final soyad = (rm['soyad'] as String?) ?? '';
                  if (key != null) calisanMap[key] = '$ad $soyad'.trim();
                }
              } catch (_) {}
            }

            userAppointments = list.map((m) {
              final hizmetId = m['hizmet_id']?.toString();
              final calisanIdStr = m['calisan_id']?.toString();
              return Appointment(
                appointmentId: null,
                randevuId: (m['randevu_id'] ?? '').toString(),
                calisanId: int.tryParse(calisanIdStr ?? ''),
                customerName: '${customer.firstName} ${customer.lastName}',
                employeeName: calisanIdStr != null
                    ? (calisanMap[calisanIdStr] ?? '')
                    : '',
                serviceName: hizmetId != null
                    ? (hizmetMap[hizmetId] ?? '')
                    : '',
                process: _mapProcess(m['process'] as int?),
                totalPrice: (m['total_price'] as num?)?.toDouble() ?? 0.0,
                appointmentDateTime: DateTime.parse(
                  m['appointment_datetime'] as String,
                ),
                approvalStatus: (m['approval_status'] as String?) ?? 'Pending',
                rating: (m['rating'] as int?),
                ratingComment: (m['rating_comment'] as String?),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                notes: (m['notes'] as String?) ?? '',
                customerPhone: '',
                customerEmail: customer.email,
              );
            }).toList();
          }
        } else {}
      } catch (e) {
        // Supabase randevu yükleme hatası
        userAppointments = [];
      }

      // Supabase'den veri gelmezse legacy veritabanından dene
      if (userAppointments.isEmpty) {
        if (customer.customerId != null) {
          userAppointments = await DbService.getAppointmentsByCustomerId(
            customer.customerId!,
          );
        }
        if (userAppointments.isEmpty) {
          userAppointments = await DbService.getAppointmentsByCustomerEmail(
            customer.email,
          );
        }
      } else {}

      if (mounted) {
        timeoutTimer.cancel();
        setState(() {
          _userAppointments = userAppointments;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        timeoutTimer.cancel();
        setState(() {
          _isLoadingAppointments = false;
          _userAppointments = [];
        });
      }
    }
  }

  String _mapProcess(int? value) {
    switch (value) {
      case 0:
        return Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('waiting');
      case 1:
        return Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('in_progress');
      case 2:
        return Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('completed');
      default:
        return Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isDesktop = MediaQuery.of(context).size.width > 600;

    assert(() {
      _buildQuickAccessCard('', '', Icons.info, () {});
      return true;
    }());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFE5E2DB),
      extendBodyBehindAppBar: true,
      drawerEnableOpenDragGesture: false,
      appBar: home.CommonAppBar(
        isDarkMode: _isDarkMode,
        logoUrl: _isletme?['logo_url'] as String?,
        businessName: _isletme != null && (_isletme!['isim'] as String?) != null
            ? _isletme!['isim'] as String
            : 'Sirius Hair Salon',
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onNavigationTap: (section) {
          // Profile screen'de navigation yok, sadece home'a yönlendir
          if (section == 'home') {
            Navigator.pushNamed(context, '/');
          } else if (section == 'profile') {
            // zaten bu sayfadayız
          } else if (section == 'appointment') {
            // Randevu sayfasına yönlendir
            Navigator.pushReplacementNamed(context, '/appointment');
          }
        },
        activeSection: 'profile', // Profile screen'de aktif bölüm
      ),
      drawer: _buildSidebarDrawer(),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Navbar'dan sonra yeterli boşluk
                        const SizedBox(height: 64),
                        // Ana profil kartı - Admin screen tarzında ince tasarım
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.width < 600
                                ? 140
                                : 160,
                          ),
                          padding: EdgeInsets.fromLTRB(
                            MediaQuery.of(context).size.width < 600 ? 12 : 16,
                            MediaQuery.of(context).size.width < 600 ? 8 : 12,
                            MediaQuery.of(context).size.width < 600 ? 12 : 16,
                            MediaQuery.of(context).size.width < 600 ? 16 : 20,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                SiriusColors.accent,
                                SiriusColors.accent.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Üst satır: Ayarlar ve Çıkış ikonları
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _showPageSettingsDialog(),
                                        icon: Icon(
                                          Icons.settings,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        tooltip: 'Ayarlar',
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Transform.translate(
                                      offset: const Offset(10, 0),
                                      child: IconButton(
                                        onPressed: () {
                                          _showLogoutDialog();
                                        },
                                        icon: Icon(
                                          Icons.logout,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        tooltip: context.t('logout_tooltip'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Ortada: Hoş geldiniz yazısı (ayarlar ve çıkış butonlarıyla aynı hizada)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: Text(
                                      Provider.of<LanguageProvider>(
                                        context,
                                        listen: false,
                                      ).t('welcome'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'Cormorant',
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Alt satır: Yuvarlak ikon ve yazılar
                              Positioned(
                                top: 50,
                                left: 16,
                                right: 16,
                                child: Row(
                                  children: [
                                    // Sol: Yuvarlak profil ikonu
                                    Stack(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.2,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child:
                                              _supaCustomer != null &&
                                                  (_supaCustomer!['profil_fotografi']
                                                              as String?)
                                                          ?.isNotEmpty ==
                                                      true
                                              ? ClipOval(
                                                  child: Image.network(
                                                    _supaCustomer!['profil_fotografi'],
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) => Icon(
                                                          Icons.person,
                                                          size: 30,
                                                          color: SiriusColors
                                                              .accent,
                                                        ),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.person,
                                                  size: 30,
                                                  color: SiriusColors.accent,
                                                ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: SiriusColors.accent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: IconButton(
                                              onPressed: _changeProfilePhoto,
                                              icon: Icon(
                                                Icons.camera_alt,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(width: 12),

                                    // Sağ: Yazılar
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (_supaCustomer != null &&
                                                    ((_supaCustomer!['firstname']
                                                                    as String?)
                                                                ?.isNotEmpty ==
                                                            true ||
                                                        (_supaCustomer!['lastname']
                                                                    as String?)
                                                                ?.isNotEmpty ==
                                                            true))
                                                ? '${_supaCustomer!['firstname'] ?? ''} ${_supaCustomer!['lastname'] ?? ''}'
                                                      .trim()
                                                : 'Ad Soyad',
                                            style: TextStyle(
                                              color: SiriusColors.contrast
                                                  .withValues(alpha: 0.9),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (_supaCustomer != null &&
                                              ((_supaCustomer!['email']
                                                              as String?)
                                                          ?.isNotEmpty ==
                                                      true ||
                                                  (_supaCustomer!['phone']
                                                              as String?)
                                                          ?.isNotEmpty ==
                                                      true)) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              [
                                                    (_supaCustomer!['email']
                                                            as String?) ??
                                                        '',
                                                    (_supaCustomer!['phone']
                                                            as String?) ??
                                                        '',
                                                  ]
                                                  .where((e) => e.isNotEmpty)
                                                  .join(' • '),
                                              style: TextStyle(
                                                color: SiriusColors.contrast
                                                    .withValues(alpha: 0.8),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12), // Üst boşluk
                        // Web: sol dikey menü + sağ içerik; Mobil: eski yatay scroll menü
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final bool isDesktop = constraints.maxWidth >= 900;
                            if (!isDesktop) {
                              return Column(
                                children: [
                                  const SizedBox(height: 16), // Üst padding
                                  // admin_screen.dart'taki gri arka planlı container ile aynı stil
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical:
                                          6, // yükseklik bir tık azaltıldı (8 -> 6)
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (Theme.of(context).brightness ==
                                              Brightness.dark)
                                          ? const Color(
                                              0xFF1F1F1F,
                                            ) // dark modda koyu gri
                                          : const Color(
                                              0xFFFFFBF0,
                                            ), // light modda istenen renk
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: SiriusColors.accent.withValues(
                                          alpha: 0.8,
                                        ),
                                        width: 2,
                                      ),
                                      boxShadow:
                                          (Theme.of(context).brightness ==
                                              Brightness.dark)
                                          ? [
                                              BoxShadow(
                                                color: SiriusColors.accent
                                                    .withValues(alpha: 0.15),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: _buildStoryButtons(),
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ), // Alt padding (eşit)
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sol: Dikey story menüsü
                                SizedBox(
                                  width: 260,
                                  child: _buildVerticalStoryMenu(),
                                ),
                                const SizedBox(width: 24),
                                // Sağ: İçerik alanı
                                Expanded(child: _buildStoryContentPane()),
                              ],
                            );
                          },
                        ),

                        const SizedBox(
                          height: 8,
                        ), // Randevular bölümü için minimal boşluk
                        // Appointments section
                        _buildAppointmentsSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: null,
    );
  }

  Widget _buildAppointmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('appointment_title'),
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Cormorant',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _sortDesc = !_sortDesc;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: SiriusColors.accent,
                          size: 18,
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: SiriusColors.accent,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('refresh'),
                  icon: _isLoadingAppointments
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  color: Colors.green,
                  onPressed: _isLoadingAppointments
                      ? null
                      : () async {
                          await _loadUserAppointments();
                        },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 0.5,
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 6),
        // Filtre ve sıralama butonları (responsive)
        Row(
          children: [
            _buildFilterChip(_getFilterLabel('all'), 'ALL'),
            _buildFilterChip(_getFilterLabel('past'), 'PAST'),
            _buildFilterChip(_getFilterLabel('pending'), 'PENDING'),
            _buildFilterChip(_getFilterLabel('confirmed'), 'APPROVED'),
            _buildFilterChip(_getFilterLabel('cancelled'), 'CANCELED'),
          ],
        ),
        const SizedBox(height: 8),
        _isLoadingAppointments
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: SiriusColors.accent),
                    const SizedBox(height: 16),
                    Text(
                      context.t('appointments_loading'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : _userAppointments.isEmpty
            ? Center(
                child: Text(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('no_appointments'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: (() {
                  final now = DateTime.now();
                  List<Appointment> items = _userAppointments.where((a) {
                    switch (_appointmentsFilter) {
                      case 'PAST':
                        return a.appointmentDateTime.isBefore(now);
                      case 'PENDING':
                        return a.approvalStatus.toLowerCase() == 'pending' &&
                            a.appointmentDateTime.isAfter(now);
                      case 'APPROVED':
                        return a.approvalStatus.toLowerCase() == 'approved';
                      case 'CANCELED':
                        return a.approvalStatus.toLowerCase().startsWith(
                          'cancel',
                        );
                      default:
                        return true;
                    }
                  }).toList();
                  items.sort(
                    (a, b) => _sortDesc
                        ? b.appointmentDateTime.compareTo(a.appointmentDateTime)
                        : a.appointmentDateTime.compareTo(
                            b.appointmentDateTime,
                          ),
                  );
                  return items.length;
                })(),
                itemBuilder: (context, index) {
                  final now = DateTime.now();
                  List<Appointment> items = _userAppointments.where((a) {
                    switch (_appointmentsFilter) {
                      case 'PAST':
                        return a.appointmentDateTime.isBefore(now);
                      case 'PENDING':
                        return a.approvalStatus.toLowerCase() == 'pending' &&
                            a.appointmentDateTime.isAfter(now);
                      case 'APPROVED':
                        return a.approvalStatus.toLowerCase() == 'approved';
                      case 'CANCELED':
                        return a.approvalStatus.toLowerCase().startsWith(
                          'cancel',
                        );
                      default:
                        return true;
                    }
                  }).toList();
                  items.sort(
                    (a, b) => _sortDesc
                        ? b.appointmentDateTime.compareTo(a.appointmentDateTime)
                        : a.appointmentDateTime.compareTo(
                            b.appointmentDateTime,
                          ),
                  );
                  final appointment = items[index];
                  return _buildNotebookAppointmentCard(appointment);
                },
              ),
      ],
    );
  }

  // Mobilde kısaltılmış, web'de tam isimler
  String _getFilterLabel(String filterType) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      // Mobilde kısaltılmış isimler
      switch (filterType) {
        case 'all':
          return Provider.of<LanguageProvider>(context, listen: false).t('all');
        case 'past':
          return Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('past');
        case 'pending':
          {
            final s = Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('pending').substring(0, 3);
            return '$s..';
          }
        case 'confirmed':
          {
            final s = Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('confirmed').substring(0, 3);
            return '$s..';
          }
        case 'cancelled':
          return Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('cancelled');
        default:
          return lang.t(filterType);
      }
    } else {
      // Web'de tam isimler
      switch (filterType) {
        case 'all':
          return lang.t('all');
        case 'past':
          return lang.t('past');
        case 'pending':
          return lang.t('pending');
        case 'confirmed':
          return lang.t('confirmed');
        case 'cancelled':
          return lang.t('cancelled');
        default:
          return lang.t(filterType);
      }
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final bool selected = _appointmentsFilter == value;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Seçili olan için tam isim, diğerleri için kısaltılmış
    String displayLabel = label;
    if (isMobile && !selected) {
      // Mobilde seçili olmayan için daha kısa kısaltılmış isim
      switch (value) {
        case 'ALL':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('all').substring(0, 3);
          break;
        case 'PAST':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('past').substring(0, 3);
          break;
        case 'PENDING':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('pending').substring(0, 3);
          break;
        case 'APPROVED':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('confirmed').substring(0, 3);
          break;
        case 'CANCELED':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('cancelled').substring(0, 3);
          break;
      }
    } else if (isMobile && selected) {
      // Mobilde seçili olan için tam isim
      switch (value) {
        case 'ALL':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('all');
          break;
        case 'PAST':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('past');
          break;
        case 'PENDING':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('pending');
          break;
        case 'APPROVED':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('confirmed');
          break;
        case 'CANCELED':
          displayLabel = Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).t('cancelled');
          break;
      }
    }

    return Padding(
      padding: EdgeInsets.only(right: isMobile ? 6 : 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _appointmentsFilter = value;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 10,
            vertical: isMobile ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            displayLabel,
            style: TextStyle(
              color: selected
                  ? SiriusColors.accent
                  : (_isDarkMode ? Colors.white : Colors.black87),
              fontSize: isMobile ? 14 : 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontFamily: 'Cormorant',
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotebookAppointmentCard(Appointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? SiriusColors.surface : const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Çizgili kağıt efekti
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 44,
              ), // Çizgileri yazılarla hizala
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          // İçerik
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spiral delikleri
              Container(
                width: 44, // Çizgilerle hizalamak için genişlet
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? SiriusColors.defaultText
                              : Colors.black.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    8,
                    0,
                    4,
                  ), // Yazıları not defteri çizgilerine hizala
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst kısım - Başlık ve butonlar
                      Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      appointment.serviceName.isNotEmpty
                                          ? appointment.serviceName
                                          : 'Hizmet',
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? SiriusColors.heading
                                            : Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Cormorant',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Not defteri ikonu kaldırıldı
                                ],
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  height: 2,
                                  color: SiriusColors.accent,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            top: -10,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 14
                                          : 16,
                                    ),
                                    onPressed: () =>
                                        _showEditAppointmentDialog(appointment),
                                    tooltip: Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('edit'),
                                    color: SiriusColors.accent,
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.cancel,
                                      size:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 14
                                          : 16,
                                    ),
                                    onPressed: () =>
                                        _cancelAppointment(appointment),
                                    tooltip: Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('cancel_appointment'),
                                    color: Colors.red,
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Orta kısım - Tarih ve saat bilgileri
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 16,
                                color: _isDarkMode
                                    ? SiriusColors.defaultText
                                    : Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${appointment.appointmentDateTime.day}/${appointment.appointmentDateTime.month}/${appointment.appointmentDateTime.year}',
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // note icon removed
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: _isDarkMode
                                    ? SiriusColors.defaultText
                                    : Colors.black,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${appointment.appointmentDateTime.hour}:${appointment.appointmentDateTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? SiriusColors.defaultText
                                      : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Builder(
                                  builder: (context) {
                                    final bool canRateInline =
                                        appointment.appointmentDateTime
                                            .isBefore(DateTime.now()) &&
                                        appointment.approvalStatus
                                                .toLowerCase() ==
                                            'approved' &&
                                        appointment.rating == null &&
                                        (appointment.randevuId != null &&
                                            appointment.randevuId!.isNotEmpty);
                                    if (appointment.rating != null) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(5, (i) {
                                          final filled =
                                              i < (appointment.rating ?? 0);
                                          return Icon(
                                            filled
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 18,
                                            color: Colors.amber,
                                          );
                                        }),
                                      );
                                    }
                                    if (canRateInline) {
                                      final lang =
                                          Provider.of<LanguageProvider>(
                                            context,
                                            listen: false,
                                          );
                                      final val = lang.t('rate');
                                      final labelText = val == 'rate'
                                          ? 'Rate'
                                          : val;
                                      return TextButton.icon(
                                        icon: const Icon(
                                          Icons.star_rate_rounded,
                                          color: Colors.amber,
                                        ),
                                        label: Text(labelText),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          alignment: Alignment.centerRight,
                                        ),
                                        onPressed: () async {
                                          int selected = 5;
                                          await showDialog(
                                            context: context,
                                            builder: (ctx) {
                                              return AlertDialog(
                                                backgroundColor: _isDarkMode
                                                    ? Colors.black
                                                    : Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                titlePadding:
                                                    const EdgeInsets.only(
                                                      left: 20,
                                                      top: 16,
                                                      right: 8,
                                                      bottom: 0,
                                                    ),
                                                title: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Çalışanı Değerlendir',
                                                        style: TextStyle(
                                                          color: _isDarkMode
                                                              ? Colors.white
                                                              : Colors.black,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                    ),
                                                  ],
                                                ),
                                                content: StatefulBuilder(
                                                  builder: (ctx, setState) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: List.generate(
                                                            5,
                                                            (i) => IconButton(
                                                              icon: Icon(
                                                                i < selected
                                                                    ? Icons.star
                                                                    : Icons
                                                                          .star_border,
                                                                color: Colors
                                                                    .amber,
                                                              ),
                                                              onPressed: () {
                                                                setState(() {
                                                                  selected =
                                                                      i + 1;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                actions: [
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors.green,
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: TextButton(
                                                      onPressed: () async {
                                                        await DbService.saveAppointmentRating(
                                                          appointment
                                                              .randevuId!,
                                                          selected,
                                                          null,
                                                        );
                                                        if (!mounted) return;
                                                        setState(() {
                                                          final idx = _userAppointments
                                                              .indexWhere(
                                                                (a) =>
                                                                    a.randevuId ==
                                                                    appointment
                                                                        .randevuId,
                                                              );
                                                          if (idx != -1) {
                                                            _userAppointments[idx] =
                                                                _userAppointments[idx]
                                                                    .copyWith(
                                                                      rating:
                                                                          selected,
                                                                      ratingComment:
                                                                          null,
                                                                    );
                                                          }
                                                        });
                                                        if (!ctx.mounted) {
                                                          return;
                                                        }
                                                        Navigator.pop(ctx);
                                                      },
                                                      style:
                                                          TextButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                          ),
                                                      child: const Text(
                                                        'Gönder',
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: SiriusColors.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${Provider.of<LanguageProvider>(context, listen: false).t('status')}: ${_getTranslatedStatus(appointment.approvalStatus)}',
                                    style: TextStyle(
                                      color: SiriusColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Text(
                                  '₺${appointment.totalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: SiriusColors.accent,
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                        ? 14
                                        : 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDesktopSidebar() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        SiriusColors.accent,
                        SiriusColors.accent.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SiriusColors.accent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child:
                        (_isletme != null &&
                            (_isletme!['logo_url'] as String?)?.isNotEmpty ==
                                true)
                        ? Image.network(
                            _isletme!['logo_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.storefront_rounded, size: 40),
                          )
                        : const Icon(Icons.storefront_rounded, size: 40),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isletme != null && (_isletme!['isim'] as String?) != null
                      ? _isletme!['isim'] as String
                      : 'Sirius',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                Text(
                  'Beauty & Spa',
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.black87.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: _isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black87.withValues(alpha: 0.3),
            height: 1,
          ),
          _buildSidebarItem(
            icon: Icons.home,
            title: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('home_title'),
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/'),
          ),
          _buildSidebarItem(
            icon: Icons.person,
            title: Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('profile_title'),
            isSelected: true,
            onTap: () {},
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _isDarkMode
                ? null
                : BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
            child: ListTile(
              leading: Icon(Icons.settings, color: const Color(0xFFDEC41F)),
              title: Text(
                'Ayarlar',
                style: TextStyle(
                  color: const Color(0xFFDEC41F),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                _showProfileSettingsDialog();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: const Color(0xFFDEC41F).withValues(alpha: 0.1),
            ),
          ),

          const Spacer(),
          // Çıkış Yap butonu
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: _isDarkMode
                ? null
                : BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
            child: ElevatedButton.icon(
              onPressed: () {
                _showLogoutDialog();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('logout'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: SiriusColors.defaultText, height: 1),
          const SizedBox(height: 8),
          // Alt araçlar: Tema ve Dil ikonları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: _isDarkMode ? 'Light' : 'Dark',
                  icon: Icon(
                    _isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  onPressed: _toggleTheme,
                ),
                IconButton(
                  tooltip: Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('change_language'),
                  icon: Icon(
                    Icons.language,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  onPressed: () {
                    _showLanguageSelectionDialog(
                      context,
                      Provider.of<LanguageProvider>(context, listen: false),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarDrawer() {
    final lang = Provider.of<LanguageProvider>(context);
    return Drawer(
      backgroundColor: Colors.transparent,
      width: 250,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (_isDarkMode ? Colors.black : Colors.white).withValues(
                    alpha: 0.12,
                  ),
                  (_isDarkMode ? Colors.black : Colors.white).withValues(
                    alpha: 0.18,
                  ),
                  (_isDarkMode ? Colors.black : Colors.white).withValues(
                    alpha: 0.25,
                  ),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.15),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(8, 0),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: (_isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.08,
                  ),
                  blurRadius: 15,
                  offset: const Offset(4, 0),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                SiriusColors.accent,
                                SiriusColors.accent.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child:
                                (_isletme != null &&
                                    (_isletme!['logo_url'] as String?)
                                            ?.isNotEmpty ==
                                        true)
                                ? Image.network(
                                    _isletme!['logo_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.storefront_rounded,
                                      size: 40,
                                    ),
                                  )
                                : const Icon(
                                    Icons.storefront_rounded,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isletme != null &&
                                  (_isletme!['isim'] as String?) != null
                              ? _isletme!['isim'] as String
                              : 'Sirius',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                        Text(
                          'Beauty & Spa',
                          style: TextStyle(
                            color: _isDarkMode
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black87,
                            fontSize: 16,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: SiriusColors.defaultText, height: 1),
                  _buildSidebarItem(
                    icon: Icons.home,
                    title: lang.t('home_title'),
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/');
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.person,
                    title: lang.t('profile_title'),
                    isSelected: true,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  const Divider(color: SiriusColors.defaultText, height: 1),
                  const SizedBox(height: 8),
                  // Alt araçlar: Tema ve Dil ikonları (mobil taşma olmaz)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: _isDarkMode ? 'Light' : 'Dark',
                          icon: Icon(
                            _isDarkMode
                                ? Icons.wb_sunny
                                : Icons.nightlight_round,
                            color: SiriusColors.accent,
                          ),
                          onPressed: _toggleTheme,
                        ),
                        IconButton(
                          tooltip: lang.t('change_language'),
                          icon: Icon(
                            Icons.language,
                            color: SiriusColors.accent,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showLanguageSelectionDialog(context, lang);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: SiriusColors.defaultText, height: 1),
                  const SizedBox(height: 8),
                  // Çıkış Yap butonu - En alta taşındı
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showLogoutDialog();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(
                        lang.t('logout'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Colors.blue
              : (_isDarkMode ? Colors.white : Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.blue
                : (_isDarkMode ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? (_isDarkMode ? Colors.white : Colors.black87).withValues(
                alpha: 0.1,
              )
            : Colors.transparent,
      ),
    );
  }

  // _showAppointmentsDialog() kaldırıldı (kullanılmıyordu)

  // ignore: unused_element
  void _showSimpleAppointmentsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.t('my_appointments')),
          content: Text(context.t('appointment_loading_error')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  // Dil seçimi dialog'u
  void _showLanguageSelectionDialog(
    BuildContext context,
    LanguageProvider lang,
  ) {
    final isDarkMode = _isDarkMode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.language, color: SiriusColors.accent, size: 24),
              const SizedBox(width: 12),
              Text(
                lang.t('change_language'),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.red),
                  title: Text(lang.t('turkish')),
                  subtitle: const Text('Turkish'),
                  onTap: () {
                    lang.setLanguage(AppLanguage.tr);
                    Navigator.of(context).pop();
                  },
                  tileColor: lang.isTurkish
                      ? SiriusColors.accent.withValues(alpha: 0.1)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.blue),
                  title: const Text('English'),
                  subtitle: Text(lang.t('english')),
                  onTap: () {
                    lang.setLanguage(AppLanguage.en);
                    Navigator.of(context).pop();
                  },
                  tileColor: lang.isEnglish
                      ? SiriusColors.accent.withValues(alpha: 0.1)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SiriusColors.accent),
                foregroundColor: SiriusColors.accent,
              ),
              child: Text(lang.t('cancel')),
            ),
          ],
        );
      },
    );
  }

  // Sayfa ayarları dialog'u (tema, dil)
  void _showPageSettingsDialog() {
    if (!mounted) return;

    // Profil düzenleme için geçici controller'lar (pencereyi bozmadan üstte göstermek için)
    final tempFirstNameController = TextEditingController(
      text: _firstNameController.text,
    );
    final tempLastNameController = TextEditingController(
      text: _lastNameController.text,
    );
    final tempEmailController = TextEditingController(
      text: _emailController.text,
    );
    final tempPhoneController = TextEditingController(
      text: _phoneController.text,
    );
    bool isEditingProfile = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        final languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // Geniş ekranlarda (web) dialog genişliğini ekranın yaklaşık %45'i olacak şekilde sabitle
            final double screenWidth = MediaQuery.of(context).size.width;
            final double dialogWidth = screenWidth >= 900
                ? screenWidth * 0.45
                : (screenWidth < 600 ? screenWidth * 0.9 : 500);

            return AlertDialog(
              backgroundColor: themeProvider.isDarkMode
                  ? const Color(0xFF181818).withValues(alpha: 0.95)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/ikon/ayarlar-Photoroom.png',
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('profile_settings_dialog'),
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('close'),
                  ),
                ],
              ),
              content: Container(
                width: dialogWidth,
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alt taraftaki boş container kaldırıldı
                      if (isEditingProfile) ...[
                        _buildEditableField(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('name'),
                          tempFirstNameController,
                          Icons.edit,
                          themeProvider.isDarkMode,
                          iconColor: SiriusColors.accent,
                        ),
                        const SizedBox(height: 12),
                        _buildEditableField(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('surname'),
                          tempLastNameController,
                          Icons.edit,
                          themeProvider.isDarkMode,
                          iconColor: SiriusColors.accent,
                        ),
                        const SizedBox(height: 12),
                        _buildEditableField(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('email'),
                          tempEmailController,
                          Icons.email,
                          themeProvider.isDarkMode,
                          iconColor: SiriusColors.accent,
                        ),
                        const SizedBox(height: 12),
                        _buildEditableField(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('phone'),
                          tempPhoneController,
                          Icons.phone,
                          themeProvider.isDarkMode,
                          iconColor: SiriusColors.accent,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              _firstNameController.text =
                                  tempFirstNameController.text;
                              _lastNameController.text =
                                  tempLastNameController.text;
                              _emailController.text = tempEmailController.text;
                              _phoneController.text = tempPhoneController.text;
                              await _saveProfileChanges();
                              dialogSetState(() {
                                isEditingProfile = false;
                              });
                            },
                            icon: const Icon(Icons.save, size: 18),
                            label: Text(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('update'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SiriusColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              dialogSetState(() {
                                isEditingProfile = false;
                              });
                            },
                            icon: const Icon(Icons.cancel, size: 18),
                            label: Text(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('cancel'),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        if (_supaCustomer != null) ...[
                          _buildProfileInfoRowWithIcon(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('name'),
                            _supaCustomer!['firstname'] ?? '',
                            Icons.person,
                            themeProvider.isDarkMode,
                          ),
                          _buildProfileInfoRowWithIcon(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('surname'),
                            _supaCustomer!['lastname'] ?? '',
                            Icons.person,
                            themeProvider.isDarkMode,
                          ),
                          _buildProfileInfoRowWithIcon(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('email'),
                            _supaCustomer!['email'] ?? '',
                            Icons.email,
                            themeProvider.isDarkMode,
                          ),
                          _buildProfileInfoRowWithIcon(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('phone'),
                            _supaCustomer!['phone'] ?? '',
                            Icons.phone,
                            themeProvider.isDarkMode,
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showChangePasswordDialog(),
                                  icon: const Icon(Icons.lock),
                                  label: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('password'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              420
                                          ? 13
                                          : 14,
                                      fontFamily: 'Cormorant',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: SiriusColors.accent,
                                      width: 2,
                                    ),
                                    foregroundColor: SiriusColors.accent,
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    dialogSetState(() {
                                      isEditingProfile = true;
                                    });
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('edit'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              420
                                          ? 13
                                          : 14,
                                      fontFamily: 'Cormorant',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _isDarkMode
                                          ? Colors.yellow
                                          : const Color(0xFFFFA500),
                                      width: 2,
                                    ),
                                    foregroundColor: _isDarkMode
                                        ? Colors.yellow
                                        : const Color(0xFFFFA500),
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Text(
                        'Gelişmiş Ayarlar',
                        style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Sayfayı Düzenle Başlığı
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            // Dark/Light Mode Switch
                            Row(
                              children: [
                                Icon(
                                  themeProvider.isDarkMode
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  size: MediaQuery.of(context).size.width < 600
                                      ? 16
                                      : 20,
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width < 600
                                      ? 8
                                      : 12,
                                ),
                                Expanded(
                                  child: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('dark_mode'),
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 14
                                          : 16,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: 'Cormorant',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Switch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) {
                                    themeProvider.toggleTheme();
                                    dialogSetState(() {});
                                  },
                                  activeColor: SiriusColors.accent,
                                  activeTrackColor: SiriusColors.accent
                                      .withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Dil Seçimi
                            Row(
                              children: [
                                Icon(
                                  Icons.language,
                                  color: themeProvider.isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  size: MediaQuery.of(context).size.width < 600
                                      ? 16
                                      : 20,
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width < 600
                                      ? 8
                                      : 12,
                                ),
                                Expanded(
                                  child: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('language'),
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 14
                                          : 16,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: 'Cormorant',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        MediaQuery.of(context).size.width < 600
                                        ? 8
                                        : 12,
                                    vertical:
                                        MediaQuery.of(context).size.width < 600
                                        ? 4
                                        : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: themeProvider.isDarkMode
                                          ? Colors.white.withValues(alpha: 0.2)
                                          : Colors.black.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: DropdownButton<AppLanguage>(
                                    value: languageProvider.currentLanguage,
                                    underline: const SizedBox.shrink(),
                                    dropdownColor: themeProvider.isDarkMode
                                        ? const Color(0xFF181818)
                                        : const Color(0xFFEDECE8),
                                    style: TextStyle(
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 12
                                          : 14,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Cormorant',
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: AppLanguage.tr,
                                        child: Text(
                                          Provider.of<LanguageProvider>(
                                            context,
                                            listen: false,
                                          ).t('turkish'),
                                          style: TextStyle(
                                            fontSize:
                                                MediaQuery.of(
                                                      context,
                                                    ).size.width <
                                                    600
                                                ? 12
                                                : 14,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'PlayfairDisplay',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: AppLanguage.en,
                                        child: Text(
                                          Provider.of<LanguageProvider>(
                                            context,
                                            listen: false,
                                          ).t('english'),
                                          style: TextStyle(
                                            fontSize:
                                                MediaQuery.of(
                                                      context,
                                                    ).size.width <
                                                    600
                                                ? 12
                                                : 14,
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'PlayfairDisplay',
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (AppLanguage? newValue) {
                                      if (newValue != null) {
                                        languageProvider.setLanguage(newValue);
                                        dialogSetState(() {});
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [],
            );
          },
        );
      },
    ).then((_) {
      // Geçici controller'ları serbest bırak
      tempFirstNameController.dispose();
      tempLastNameController.dispose();
      tempEmailController.dispose();
      tempPhoneController.dispose();
    });
  }

  // Profil ayarları dialog'u (ad, soyad, email, telefon, şifre)
  void _showProfileSettingsDialog() {
    if (!mounted) return;

    // Dialog için geçici controller'lar oluştur
    final tempFirstNameController = TextEditingController(
      text: _firstNameController.text,
    );
    final tempLastNameController = TextEditingController(
      text: _lastNameController.text,
    );
    final tempEmailController = TextEditingController(
      text: _emailController.text,
    );
    final tempPhoneController = TextEditingController(
      text: _phoneController.text,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final fallbackAuth = Provider.of<AuthProvider>(context, listen: false);
        final fallbackCustomer = fallbackAuth.currentCustomer;
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // Geniş ekranlarda (web) dialog genişliği: ekranın yaklaşık %45'i
            final double screenWidth = MediaQuery.of(context).size.width;
            final double dialogWidth = screenWidth >= 900
                ? screenWidth * 0.45
                : (screenWidth < 600 ? screenWidth * 0.9 : 400);

            return AlertDialog(
              backgroundColor: themeProvider.isDarkMode
                  ? const Color(0xFF181818).withValues(alpha: 0.95)
                  : const Color(0xFFEDECE8).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).t('profile_settings_dialog'),
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 16
                            : 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cormorant',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('close'),
                  ),
                ],
              ),
              content: DefaultTextStyle.merge(
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Cormorant',
                ),
                child: Container(
                  width: dialogWidth,
                  constraints: const BoxConstraints(maxHeight: 600),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditingProfile) ...[
                          // Düzenleme modunda input alanları
                          _buildEditableField(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('name'),
                            tempFirstNameController,
                            Icons.edit,
                            themeProvider.isDarkMode,
                            iconColor: SiriusColors.accent,
                          ),
                          const SizedBox(height: 12),
                          _buildEditableField(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('surname'),
                            tempLastNameController,
                            Icons.edit,
                            themeProvider.isDarkMode,
                            iconColor: SiriusColors.accent,
                          ),
                          const SizedBox(height: 12),
                          _buildEditableField(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('email'),
                            tempEmailController,
                            Icons.email,
                            themeProvider.isDarkMode,
                            iconColor: SiriusColors.accent,
                          ),
                          const SizedBox(height: 12),
                          _buildEditableField(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('phone'),
                            tempPhoneController,
                            Icons.phone,
                            themeProvider.isDarkMode,
                            iconColor: SiriusColors.accent,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),
                          // Güncelleme Butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Geçici controller'lardan değerleri al ve ana controller'lara kopyala
                                _firstNameController.text =
                                    tempFirstNameController.text;
                                _lastNameController.text =
                                    tempLastNameController.text;
                                _emailController.text =
                                    tempEmailController.text;
                                _phoneController.text =
                                    tempPhoneController.text;

                                // Dialog'u kapat
                                Navigator.of(context).pop();

                                // Profil değişikliklerini kaydet
                                await _saveProfileChanges();
                              },
                              icon: const Icon(Icons.save, size: 18),
                              label: Text(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('update'),
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SiriusColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // İptal Butonu
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                dialogSetState(() {
                                  _isEditingProfile = false;
                                });
                              },
                              icon: const Icon(
                                Icons.cancel,
                                size: 18,
                                color: Colors.red,
                              ),
                              label: Text(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('cancel'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Görüntüleme modunda bilgi satırları
                          if (_supaCustomer != null) ...[
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('name'),
                              _supaCustomer!['firstname'] ?? '',
                              Icons.person,
                              themeProvider.isDarkMode,
                            ),
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('surname'),
                              _supaCustomer!['lastname'] ?? '',
                              Icons.person,
                              themeProvider.isDarkMode,
                            ),
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('email'),
                              _supaCustomer!['email'] ?? '',
                              Icons.email,
                              themeProvider.isDarkMode,
                            ),
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('phone'),
                              _supaCustomer!['phone'] ?? '',
                              Icons.phone,
                              themeProvider.isDarkMode,
                            ),
                          ] else if (fallbackCustomer != null) ...[
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('name'),
                              fallbackCustomer.firstName,
                              Icons.person,
                              themeProvider.isDarkMode,
                            ),
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('surname'),
                              fallbackCustomer.lastName,
                              Icons.person,
                              themeProvider.isDarkMode,
                            ),
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('email'),
                              fallbackCustomer.email,
                              Icons.email,
                              themeProvider.isDarkMode,
                            ),
                            _buildProfileInfoRowWithIcon(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('phone'),
                              fallbackCustomer.phone,
                              Icons.phone,
                              themeProvider.isDarkMode,
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: themeProvider.isDarkMode
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: themeProvider.isDarkMode
                                      ? Colors.red.withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Profil bilgileri yüklenemedi.',
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Aksiyon Butonları
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showChangePasswordDialog(),
                                  icon: Icon(
                                    Icons.lock,
                                    size:
                                        MediaQuery.of(context).size.width < 600
                                        ? 16
                                        : 18,
                                  ),
                                  label: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('change_password'),
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 11
                                          : 14,
                                    ),
                                    textAlign: TextAlign.left,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: SiriusColors.accent,
                                      width: 2,
                                    ),
                                    foregroundColor: SiriusColors.accent,
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 12
                                          : 14,
                                      horizontal:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 8
                                          : 16,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    dialogSetState(() {
                                      _isEditingProfile = true;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.edit,
                                    size:
                                        MediaQuery.of(context).size.width < 600
                                        ? 16
                                        : 18,
                                    color: _isDarkMode
                                        ? Colors.yellow
                                        : const Color(0xFFFFA500),
                                  ),
                                  label: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('edit'),
                                    style: TextStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 11
                                          : 14,
                                      color: _isDarkMode
                                          ? Colors.yellow
                                          : const Color(0xFFFFA500),
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: _isDarkMode
                                          ? Colors.yellow
                                          : const Color(0xFFFFA500),
                                      width: 2,
                                    ),
                                    foregroundColor: _isDarkMode
                                        ? Colors.yellow
                                        : const Color(0xFFFFA500),
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 12
                                          : 14,
                                      horizontal:
                                          MediaQuery.of(context).size.width <
                                              600
                                          ? 8
                                          : 16,
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: const [],
            );
          },
        );
      },
    ).then((_) {
      // Dialog kapandığında geçici controller'ları dispose et
      tempFirstNameController.dispose();
      tempLastNameController.dispose();
      tempEmailController.dispose();
      tempPhoneController.dispose();
    });
  }

  // Düzenlenebilir alan oluşturma metodu
  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDarkMode, {
    TextInputType? keyboardType,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : SiriusColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: iconColor),
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            fontFamily: 'PlayfairDisplay',
          ),
          filled: false,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
          fontFamily: 'PlayfairDisplay',
        ),
      ),
    );
  }

  // Profil bilgi satırı oluşturma metodu (ikon ile)
  Widget _buildProfileInfoRowWithIcon(
    String label,
    String value,
    IconData icon,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: SiriusColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Cormorant',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Cormorant',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Şifre değiştirme dialog'u
  void _showChangePasswordDialog() {
    if (!mounted) return;

    final TextEditingController currentController = TextEditingController();
    final TextEditingController newController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.black : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.lock,
                color: SiriusColors.accent,
                size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
              ),
              SizedBox(width: MediaQuery.of(context).size.width < 600 ? 6 : 8),
              Expanded(
                child: Text(
                  Provider.of<LanguageProvider>(
                    context,
                    listen: false,
                  ).t('change_password'),
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                    fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                ),
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('close'),
                color: Colors.red,
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 600
                ? MediaQuery.of(context).size.width * 0.9
                : 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('current_password'),
                    labelStyle: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.defaultText
                          : Colors.black54,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('new_password_min'),
                    labelStyle: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.defaultText
                          : Colors.black54,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('confirm_password'),
                    labelStyle: TextStyle(
                      color: _isDarkMode
                          ? SiriusColors.defaultText
                          : Colors.black54,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: SiriusColors.accent.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SiriusColors.accent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(
                    color: _isDarkMode ? SiriusColors.heading : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () async {
                final newPwd = newController.text.trim();
                final confirmPwd = confirmController.text.trim();
                final currentPwd = currentController.text.trim();

                if (newPwd.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('password_min_length')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newPwd != confirmPwd) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('new_passwords_do_not_match')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final client = Supabase.instance.client;
                  final user = client.auth.currentUser;
                  if (user == null || user.email == null) {
                    throw Exception(context.t('user_session_not_found'));
                  }

                  // Mevcut şifreyi doğrula
                  try {
                    await client.auth.signInWithPassword(
                      email: user.email!,
                      password: currentPwd,
                    );
                  } catch (_) {
                    if (!context.mounted) {
                      throw Exception('Current password incorrect');
                    }
                    throw Exception(context.t('current_password_incorrect'));
                  }

                  // Şifreyi güncelle
                  await client.auth.updateUser(
                    UserAttributes(password: newPwd),
                  );

                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('password_updated_success')),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.t('password_update_error')} $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SiriusColors.accent),
                foregroundColor: SiriusColors.accent,
              ),
              child: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('update'),
              ),
            ),
          ],
        );
      },
    );
  }

  // İletişim dialog'u
  void _showContactDialog() {
    if (!mounted) return;

    // ignore: unused_local_variable
    final TextEditingController questionController = TextEditingController();
    // ignore: unused_local_variable
    final TextEditingController emailController = TextEditingController();

    final Map<String, dynamic>? biz = _isletme is Map<String, dynamic>
        ? _isletme as Map<String, dynamic>
        : null;
    final String tel = (biz?['telefon'] ?? biz?['phone'] ?? '-').toString();
    final String mail = (biz?['email'] ?? '-').toString();

    // Çalışma saatlerini başlangıç ve bitiş saatlerinden oluştur
    String calisma = '-';
    if (biz != null) {
      final baslangic = biz['calisma_saati_baslangic']?.toString();
      final bitis = biz['calisma_saati_bitis']?.toString();

      if (baslangic != null &&
          bitis != null &&
          baslangic.isNotEmpty &&
          bitis.isNotEmpty) {
        // Saat formatını düzenle (HH:MM:SS -> HH:MM)
        final baslangicFormatted = baslangic.length >= 5
            ? baslangic.substring(0, 5)
            : baslangic;
        final bitisFormatted = bitis.length >= 5
            ? bitis.substring(0, 5)
            : bitis;
        calisma =
            'Pazartesi - Cumartesi: $baslangicFormatted - $bitisFormatted';
      } else {
        // Fallback: eski alanları kontrol et
        calisma = (biz['contact_open'] ?? biz['calisma_saatleri'] ?? '-')
            .toString();
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: SiriusColors.accent, width: 2),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/ikon/iletişim-Photoroom.png',
                    width: 28,
                    height: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Contact Us',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: Colors.red, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('close'),
              ),
            ],
          ),
          content: DefaultTextStyle.merge(
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontFamily: 'Cormorant',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('phone_label'),
                    tel,
                  ),
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('email_label'),
                    mail,
                  ),
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('working_hours_label'),
                    calisma,
                  ),
                  const SizedBox(height: 0),
                ],
              ),
            ),
          ),
          actions: const [],
        );
      },
    );
  }

  Widget _buildContactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontFamily: 'Cormorant',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
              fontFamily: 'Cormorant',
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? SiriusColors.heading : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : context.t('not_specified'),
              style: TextStyle(
                color: _isDarkMode ? SiriusColors.defaultText : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Randevu iptal etme
  void _cancelAppointment(Appointment appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button in top right
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('close'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Question text
              Text(
                context.t('cancel_appointment_confirm'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 24),
              // Cancel Appointment button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _performCancelAppointment(appointment);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 2),
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('cancel_appointment'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Supabase ile randevu silme (müşteri iptal ettiğinde hard delete)
  Future<void> _performCancelAppointment(Appointment appointment) async {
    try {
      final client = Supabase.instance.client;

      final dynamic custIdDyn = _supaCustomer != null
          ? (_supaCustomer as Map<String, dynamic>)['customerid']
          : null;
      final int? customerId = (custIdDyn is num) ? custIdDyn.toInt() : null;
      if (customerId == null) {
        throw Exception(context.t('customer_id_not_found'));
      }

      // Randevuyu tamamen sil (müşteri iptal ettiğinde hard delete)
      await client
          .from('randevu')
          .delete()
          .eq('customerid', customerId)
          .eq(
            'appointment_datetime',
            appointment.appointmentDateTime.toIso8601String(),
          );

      // Local listeyi güncelle (randevuyu listeden çıkar)
      _safeSetState(() {
        _userAppointments.removeWhere(
          (a) => a.appointmentDateTime == appointment.appointmentDateTime,
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('appointment_cancelled_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Randevu silinemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ignore: unused_element
  Future<void> _logout() async {
    try {
      final client = Supabase.instance.client;
      await client.auth.signOut();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('logout_error')} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Randevu düzenleme dialog'u
  void _showEditAppointmentDialog(Appointment appointment) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Dialog state: StatefulBuilder yeniden build edilse bile aynı referanslar kullanılsın
        bool isLoadingData = true;
        DateTime selectedDateTime = appointment.appointmentDateTime;
        String selectedService = appointment.serviceName;
        String selectedEmployee = appointment.employeeName;
        List<Map<String, dynamic>> services = [];
        List<Map<String, dynamic>> employees = [];

        // Dialog kapatıldığında iptal edilecek işlemler için flag
        bool isDialogClosed = false;
        bool isDisposed = false;
        bool dataLoaded = false;

        return StatefulBuilder(
          key: const ValueKey('edit_appointment_dialog'),
          builder: (context, setDialogState) {
            // Not: Durum değişkenleri üst scope'ta tanımlandı (reset olmaması için)

            // Hizmet ve çalışan verilerini yükle (tema bağımsız)
            Future<void> loadData() async {
              if (isDialogClosed ||
                  !mounted ||
                  isDisposed ||
                  !context.mounted) {
                return; // Dialog kapatıldıysa veya widget dispose edildiyse işlemi durdur
              }
              try {
                final client = Supabase.instance.client;

                // isletme_id belirle (varsa)
                final dynamic bizIdDyn = (_isletme is Map<String, dynamic>)
                    ? (_isletme as Map<String, dynamic>)['isletme_id']
                    : null;
                final String? bizId = bizIdDyn?.toString();

                // Servisleri menu_hizmet_icerigi tablosundan çek
                List<dynamic> servicesResult = [];
                try {
                  var svcQuery = client
                      .from('menu_hizmet_icerigi')
                      .select(
                        'hizmet, menu_hizmet_icerigi_id, isletme_id, aktif, sira',
                      )
                      .eq('aktif', true);
                  if (bizId != null && bizId.isNotEmpty) {
                    svcQuery = svcQuery.eq('isletme_id', bizId);
                  }
                  servicesResult = await svcQuery.order(
                    'sira',
                    ascending: true,
                  );
                } catch (e) {
                  // Sessiz geç: isletme filtresi olmadan tekrar denenecek
                }

                // Eğer sonuç gelmediyse isletme filtresi olmadan dene
                if (servicesResult.isEmpty) {
                  try {
                    final res = await client
                        .from('menu_hizmet_icerigi')
                        .select(
                          'hizmet, menu_hizmet_icerigi_id, isletme_id, aktif, sira',
                        )
                        .eq('aktif', true)
                        .order('sira', ascending: true);
                    servicesResult = res;
                  } catch (e) {
                    // Sessiz geç: alternatif sorgu başarısız olabilir, legacy akış devam eder
                  }
                }

                // Servisler yüklendi

                // Tüm çalışanları çek (servis seçimine göre filtreleme yapılacak)
                var empQuery = client
                    .from('calisanlar')
                    .select('id, ad, soyad, isletme_id, hizmet, aktif')
                    .eq('aktif', true);
                if (bizId != null && bizId.isNotEmpty) {
                  empQuery = empQuery.eq('isletme_id', bizId);
                }
                final employeesResult = await empQuery.order(
                  'sira',
                  ascending: true,
                );

                final loadedServices = List<Map<String, dynamic>>.from(
                  servicesResult,
                );
                final loadedEmployees = List<Map<String, dynamic>>.from(
                  employeesResult,
                );

                // Tekilleştir ve eksikse mevcut (appointment'tan gelen) değeri ekle
                final Map<String, Map<String, dynamic>> uniqueServices = {};
                for (final service in loadedServices) {
                  final serviceName = (service['hizmet'] ?? '')
                      .toString()
                      .trim();
                  if (serviceName.isNotEmpty &&
                      !uniqueServices.containsKey(serviceName)) {
                    uniqueServices[serviceName] = service;
                  }
                }
                if (selectedService.isNotEmpty &&
                    !uniqueServices.containsKey(selectedService.trim())) {
                  uniqueServices[selectedService.trim()] = {
                    'hizmet': selectedService.trim(),
                  };
                }
                final finalServices = uniqueServices.values.toList();

                // Debug: Tekrarlanan servisleri kontrol et

                // Servisler hazır

                // Debug: Servis sayısını yazdır

                // Dialog state'ini güncelle (seçimler sabit kalsın)
                if (context.mounted &&
                    mounted &&
                    !isDialogClosed &&
                    !isDisposed) {
                  setDialogState(() {
                    services = finalServices;
                    employees = loadedEmployees;
                    isLoadingData = false;
                  });
                }
              } catch (e) {
                if (context.mounted &&
                    mounted &&
                    !isDialogClosed &&
                    !isDisposed) {
                  setDialogState(() {
                    isLoadingData = false;
                  });
                }
              }
            }

            // Servis değiştiğinde çalışan listesini filtrele
            Future<void> loadEmployeesByService(String? serviceName) async {
              if (isDialogClosed ||
                  !mounted ||
                  isDisposed ||
                  !context.mounted) {
                return; // Dialog kapatıldıysa veya widget dispose edildiyse işlemi durdur
              }
              if (serviceName == null || serviceName.isEmpty) {
                if (context.mounted &&
                    mounted &&
                    !isDialogClosed &&
                    !isDisposed) {
                  setDialogState(() {
                    employees = [];
                  });
                }
                return;
              }

              try {
                final client = Supabase.instance.client;
                final dynamic bizIdDyn = (_isletme is Map<String, dynamic>)
                    ? (_isletme as Map<String, dynamic>)['isletme_id']
                    : null;
                final String? bizId = bizIdDyn?.toString();

                var empQuery = client
                    .from('calisanlar')
                    .select('id, ad, soyad, isletme_id, hizmet, aktif')
                    .eq('aktif', true);
                if (bizId != null && bizId.isNotEmpty) {
                  empQuery = empQuery.eq('isletme_id', bizId);
                }

                // Hizmete göre filtrele - çalışanın hizmet kolonu seçilen hizmeti içermeli
                // Virgülle ayrılmış hizmetler için tam eşleşme veya içerme kontrolü
                empQuery = empQuery.or(
                  'hizmet.eq.$serviceName,hizmet.ilike.%$serviceName%',
                );

                final employeesResult = await empQuery.order(
                  'sira',
                  ascending: true,
                );

                // Çalışanlar yüklendi

                final filteredEmployees = List<Map<String, dynamic>>.from(
                  employeesResult,
                );

                // Mevcut seçili çalışan listede yoksa ekle
                bool employeeExists = filteredEmployees.any(
                  (e) =>
                      ('${e['ad'] ?? ''} ${e['soyad'] ?? ''}'.trim() ==
                      selectedEmployee),
                );

                // Çalışanlar filtrelendi

                final List<Map<String, dynamic>> finalEmployees = [
                  ...filteredEmployees,
                  if (selectedEmployee.isNotEmpty && !employeeExists)
                    {
                      'ad': (selectedEmployee.split(' ').isNotEmpty)
                          ? selectedEmployee.split(' ').first
                          : selectedEmployee,
                      'soyad': (selectedEmployee.split(' ').length > 1)
                          ? selectedEmployee.split(' ').sublist(1).join(' ')
                          : '',
                      'hizmet': serviceName,
                    },
                ];

                if (context.mounted &&
                    mounted &&
                    !isDialogClosed &&
                    !isDisposed) {
                  setDialogState(() {
                    employees = finalEmployees;
                  });
                }
              } catch (e) {
                if (context.mounted &&
                    mounted &&
                    !isDialogClosed &&
                    !isDisposed) {
                  setDialogState(() {
                    employees = [];
                  });
                }
              }
            }

            // Dialog açıldığında verileri yükle - sadece bir kez
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isDialogClosed &&
                  context.mounted &&
                  mounted &&
                  !dataLoaded) {
                dataLoaded = true;
                loadData().then((_) {
                  if (!isDialogClosed &&
                      context.mounted &&
                      mounted &&
                      !isDisposed &&
                      selectedService.isNotEmpty) {
                    loadEmployeesByService(selectedService);
                  }
                });
              }
            });

            final lang = Provider.of<LanguageProvider>(context, listen: false);
            return AlertDialog(
              backgroundColor: _isDarkMode
                  ? const Color(0xFF181818).withValues(alpha: 0.95)
                  : const Color(0xFFEDECE8).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: SiriusColors.accent, width: 2),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/ikon/edit-Photoroom.png',
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        lang.t('edit_appointment'),
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      isDialogClosed = true;
                      isDisposed = true;
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.close, color: Colors.red, size: 24),
                  ),
                ],
              ),
              content: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Cormorant',
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width > 600
                      ? 500
                      : MediaQuery.of(context).size.width * 0.9,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoadingData) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 16),
                      ] else ...[
                        // Hizmet ve çalışan seçimi her zaman görünür
                        DropdownButtonFormField<String>(
                          key: const ValueKey('service_dropdown'),
                          isExpanded: true,
                          isDense: true,
                          value: selectedService.isEmpty || services.isEmpty
                              ? null
                              : (services.any(
                                      (service) =>
                                          (service['hizmet'] ?? '')
                                              .toString()
                                              .trim() ==
                                          selectedService.trim(),
                                    )
                                    ? selectedService.trim()
                                    : null),
                          decoration: InputDecoration(
                            labelText: lang.t('service'),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            filled: true,
                            fillColor: _isDarkMode
                                ? SiriusColors.background
                                : Colors.grey[100],
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontFamily: 'Cormorant',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                          hint: Text(
                            selectedService.isNotEmpty
                                ? selectedService
                                : lang.t('service'),
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: services.isEmpty
                              ? [
                                  DropdownMenuItem<String>(
                                    value: 'loading',
                                    child: Text(
                                      'Yükleniyor...',
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ]
                              : services.map((service) {
                                  final serviceName = (service['hizmet'] ?? '')
                                      .toString()
                                      .trim();
                                  return DropdownMenuItem<String>(
                                    value: serviceName,
                                    child: Text(
                                      serviceName,
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                          onChanged: (value) {
                            if (value != null &&
                                value != selectedService &&
                                value != 'loading') {
                              if (mounted && !isDialogClosed && !isDisposed) {
                                setDialogState(() {
                                  selectedService = value;
                                  selectedEmployee =
                                      ''; // Çalışan seçimini sıfırla
                                });
                                // Servis değiştiğinde çalışan listesini güncelle
                                loadEmployeesByService(value);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          key: const ValueKey('employee_dropdown'),
                          isExpanded: true,
                          isDense: true,
                          value: selectedEmployee.isEmpty
                              ? null
                              : selectedEmployee,
                          decoration: InputDecoration(
                            labelText: lang.t('employee'),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            filled: true,
                            fillColor: _isDarkMode
                                ? SiriusColors.background
                                : Colors.grey[100],
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: SiriusColors.accent,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontFamily: 'Cormorant',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                          hint: Text(
                            selectedEmployee.isNotEmpty
                                ? selectedEmployee
                                : lang.t('employee'),
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: employees.map((employee) {
                            final fullName =
                                '${employee['ad'] ?? ''} ${employee['soyad'] ?? ''}'
                                    .trim();
                            return DropdownMenuItem<String>(
                              value: fullName,
                              child: Text(
                                fullName,
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              if (mounted && !isDialogClosed && !isDisposed) {
                                setDialogState(() {
                                  selectedEmployee = value;
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Hizmet ve çalışan seçimi yukarıda eklendi
                      ],

                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: SiriusColors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.t('date_time'),
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 16,
                                      fontFamily: 'Cormorant',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    '${selectedDateTime.hour}:${selectedDateTime.minute.toString().padLeft(2, '0')} ${selectedDateTime.day}/${selectedDateTime.month}/${selectedDateTime.year}',
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: 'Cormorant',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.edit_calendar,
                                color: SiriusColors.accent,
                                size: 20,
                              ),
                              onPressed: () async {
                                try {
                                  // Önce saat seç, sonra tarih seç
                                  final theme = Theme.of(context);
                                  final isDarkMode = Provider.of<ThemeProvider>(
                                    context,
                                    listen: false,
                                  ).isDarkMode;

                                  // Saat seçimi
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      selectedDateTime,
                                    ),
                                    initialEntryMode: TimePickerEntryMode.dial,
                                    builder: (context, child) {
                                      return Theme(
                                        data: theme.copyWith(
                                          colorScheme: theme.colorScheme
                                              .copyWith(
                                                primary: SiriusColors.accent,
                                                onPrimary: Colors.white,
                                                surface: isDarkMode
                                                    ? Colors.black
                                                    : Colors.white,
                                                onSurface: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                onSurfaceVariant: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                onSecondary: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                secondary: SiriusColors.accent
                                                    .withValues(alpha: 0.8),
                                              ),
                                          timePickerTheme: TimePickerThemeData(
                                            backgroundColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            dialBackgroundColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            hourMinuteTextColor: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            helpTextStyle: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            dialTextColor: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            entryModeIconColor: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            hourMinuteColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            dayPeriodColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            dayPeriodTextColor: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            dialHandColor: isDarkMode
                                                ? Colors.blue
                                                : Colors.blue,
                                            inputDecorationTheme:
                                                InputDecorationTheme(
                                                  fillColor: isDarkMode
                                                      ? Colors.black
                                                      : Colors.white,
                                                  labelStyle: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                  hintStyle: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                ),
                                          ),
                                          // Keep global textButtonTheme/dialogTheme outside of TimePickerThemeData
                                        ),
                                        child: MediaQuery(
                                          data: MediaQuery.of(context).copyWith(
                                            alwaysUse24HourFormat: true,
                                          ),
                                          child: child!,
                                        ),
                                      );
                                    },
                                  );

                                  if (!context.mounted) return;

                                  // Tarih seçimi - initialDate, firstDate'ten küçükse hatayı önle
                                  final DateTime firstAllowedDate =
                                      DateTime.now();
                                  final DateTime initialDateSafe =
                                      selectedDateTime.isBefore(
                                        firstAllowedDate,
                                      )
                                      ? firstAllowedDate
                                      : selectedDateTime;
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: initialDateSafe,
                                    firstDate: firstAllowedDate,
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                    builder: (context, child) {
                                      return Theme(
                                        data: theme.copyWith(
                                          colorScheme: theme.colorScheme
                                              .copyWith(
                                                primary: SiriusColors.accent,
                                                onPrimary: Colors.white,
                                                surface: isDarkMode
                                                    ? Colors.black
                                                    : Colors.white,
                                                onSurface: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                onSurfaceVariant: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54,
                                                outline: isDarkMode
                                                    ? Colors.white24
                                                    : Colors.black26,
                                              ),
                                          dialogTheme: DialogThemeData(
                                            backgroundColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            surfaceTintColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                          datePickerTheme: DatePickerThemeData(
                                            backgroundColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            surfaceTintColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            headerBackgroundColor: isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            headerForegroundColor: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            dayForegroundColor:
                                                MaterialStateProperty.resolveWith(
                                                  (states) {
                                                    if (states.contains(
                                                      MaterialState.selected,
                                                    )) {
                                                      return Colors.white;
                                                    }
                                                    return isDarkMode
                                                        ? Colors.white
                                                        : Colors.black;
                                                  },
                                                ),
                                            dayBackgroundColor:
                                                MaterialStateProperty.resolveWith(
                                                  (states) {
                                                    if (states.contains(
                                                      MaterialState.selected,
                                                    )) {
                                                      return SiriusColors
                                                          .accent;
                                                    }
                                                    return Colors.transparent;
                                                  },
                                                ),
                                            todayForegroundColor:
                                                MaterialStateProperty.resolveWith(
                                                  (states) {
                                                    return SiriusColors.accent;
                                                  },
                                                ),
                                            todayBackgroundColor:
                                                MaterialStateProperty.resolveWith(
                                                  (states) {
                                                    return isDarkMode
                                                        ? Colors.black
                                                        : Colors.white;
                                                  },
                                                ),
                                            weekdayStyle: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                            yearForegroundColor:
                                                MaterialStateProperty.resolveWith(
                                                  (states) {
                                                    if (states.contains(
                                                      MaterialState.selected,
                                                    )) {
                                                      return Colors.white;
                                                    }
                                                    return isDarkMode
                                                        ? Colors.white
                                                        : Colors.black;
                                                  },
                                                ),
                                            yearBackgroundColor:
                                                MaterialStateProperty.resolveWith(
                                                  (states) {
                                                    if (states.contains(
                                                      MaterialState.selected,
                                                    )) {
                                                      return SiriusColors
                                                          .accent;
                                                    }
                                                    return Colors.transparent;
                                                  },
                                                ),
                                          ),
                                          textButtonTheme: TextButtonThemeData(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  SiriusColors.accent,
                                            ),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );

                                  if (pickedTime != null ||
                                      pickedDate != null) {
                                    final effectiveDate =
                                        pickedDate ??
                                        DateTime(
                                          selectedDateTime.year,
                                          selectedDateTime.month,
                                          selectedDateTime.day,
                                        );
                                    final effectiveTime =
                                        pickedTime ??
                                        TimeOfDay.fromDateTime(
                                          selectedDateTime,
                                        );
                                    setDialogState(() {
                                      selectedDateTime = DateTime(
                                        effectiveDate.year,
                                        effectiveDate.month,
                                        effectiveDate.day,
                                        effectiveTime.hour,
                                        effectiveTime.minute,
                                      );
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Tarih/saat seçimi hatası: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () async {
                    // Güncelleme işlemi
                    await _performEditAppointment(
                      appointment,
                      selectedDateTime,
                      selectedService.isNotEmpty
                          ? selectedService
                          : appointment.serviceName,
                      selectedEmployee.isNotEmpty
                          ? selectedEmployee
                          : appointment.employeeName,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green, width: 1.5),
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    lang.t('update'),
                    style: const TextStyle(
                      fontFamily: 'Cormorant',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Supabase ile randevu düzenleme
  Future<void> _performEditAppointment(
    Appointment appointment,
    DateTime newDateTime,
    String newService,
    String newEmployee,
  ) async {
    try {
      final client = Supabase.instance.client;

      // customerid al
      final dynamic custIdDyn = _supaCustomer != null
          ? (_supaCustomer as Map<String, dynamic>)['customerid']
          : null;
      final int? customerId = (custIdDyn is num) ? custIdDyn.toInt() : null;
      if (customerId == null) {
        throw Exception(context.t('customer_id_not_found'));
      }

      // Hizmet ve çalışan ID'leri (opsiyonel)
      String? hizmetId;
      int? calisanId;
      try {
        final svcRow = await client
            .from('menu_hizmet_icerigi')
            .select('menu_hizmet_icerigi_id')
            .eq('hizmet', newService)
            .maybeSingle();
        hizmetId = svcRow?['menu_hizmet_icerigi_id'] as String?;

        final names = newEmployee.split(' ');
        final first = names.isNotEmpty ? names.first : newEmployee;
        final empRow = await client
            .from('calisanlar')
            .select('id')
            .eq('ad', first)
            .maybeSingle();
        calisanId = (empRow?['id'] as num?)?.toInt();
      } catch (_) {}

      final updateData = <String, dynamic>{
        'appointment_datetime': newDateTime.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (hizmetId != null) updateData['hizmet_id'] = hizmetId;
      if (calisanId != null) updateData['calisan_id'] = calisanId;

      // Orijinal kaydı müşteri + orijinal tarih ile eşle
      await client
          .from('randevu')
          .update(updateData)
          .eq('customerid', customerId)
          .eq(
            'appointment_datetime',
            appointment.appointmentDateTime.toIso8601String(),
          );

      // Local listeyi güncelle
      _safeSetState(() {
        final index = _userAppointments.indexWhere(
          (a) => a.appointmentDateTime == appointment.appointmentDateTime,
        );
        if (index != -1) {
          _userAppointments[index] = _userAppointments[index].copyWith(
            appointmentDateTime: newDateTime,
            serviceName: newService,
            employeeName: newEmployee,
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('appointment_updated_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('appointment_update_error')} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildQuickAccessCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode
            ? SiriusColors.surface
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SiriusColors.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SiriusColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: SiriusColors.accent, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: SiriusColors.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: SiriusColors.defaultText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryButtons() {
    final List<_StoryBtn> items = [
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('profile_contact_us'),
        Color(0xFF9EF7BF),
        Icons.chat_bubble,
        () {
          _showContactDialog();
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('profile_create_appointment'),
        Color(0xFFFAA940),
        Icons.add_circle,
        () {
          Navigator.pushNamed(context, '/appointment');
        },
      ),
      _StoryBtn(
        Provider.of<LanguageProvider>(
          context,
          listen: false,
        ).t('get_directions'),
        Color(0xFFF5928E),
        Icons.map,
        () {
          _showDirectionDialog();
        },
      ),
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTiny = screenWidth < 360;
    final bool isSmall = screenWidth < 480;
    final bool isNarrow = screenWidth < 380; // sığmıyorsa bir tık küçült
    final double circleSize = isTiny
        ? 50
        : (isNarrow ? 54 : (isSmall ? 58 : 64));
    // Eski etiket genişliği artık kullanılmıyor, metinler tooltip ile gösteriliyor
    // Ortadaki (2.) butonu bir tık büyük yap
    final double centerScale = 1.18; // orta ikon bir tık daha büyük
    final double centerSize = circleSize * centerScale;
    final double maxCircleSize = centerSize > circleSize
        ? centerSize
        : circleSize;

    Widget buildItem(_StoryBtn it, double size) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Metinleri alttan kaldır, hover/long-press ile göster
            Tooltip(
              message: it.title,
              waitDuration: const Duration(milliseconds: 300),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDarkMode
                      ? const Color(0xFF181818)
                      : const Color(0xFFF0F0F0),
                  gradient: _isDarkMode
                      ? null
                      : LinearGradient(
                          colors: [
                            it.color.withValues(alpha: 0.9),
                            it.color.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: it.color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: it.onTap,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Icon(
                        it.icon,
                        color: _isDarkMode ? it.color : Colors.white,
                        size: isTiny ? 24 : 28,
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

    if (screenWidth >= 900) {
      return Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            buildItem(items[0], circleSize),
            buildItem(items[1], centerSize),
            buildItem(items[2], circleSize),
          ],
        ),
      );
    }

    // Gölge taşması için yeterli alan: blurRadius 12 + offsetY 6 + margin 2*2 = 22px ekstra
    return SizedBox(
      height: maxCircleSize + 30,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            buildItem(items[0], circleSize),
            buildItem(items[1], centerSize),
            buildItem(items[2], circleSize),
          ],
        ),
      ),
    );
  }

  // Profil değişikliklerini kaydetme
  Future<void> _saveProfileChanges() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null || user.email == null) {
        throw Exception(context.t('user_session_not_found'));
      }

      // Müşteri ID'sini al
      final customerId = _supaCustomer?['customerid'];
      if (customerId == null) {
        throw Exception(context.t('customer_id_not_found'));
      }

      // Profil bilgilerini güncelle
      await client
          .from('musteriler')
          .update({
            'firstname': _firstNameController.text.trim(),
            'lastname': _lastNameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('customerid', customerId);

      // Local state'i güncelle
      _safeSetState(() {
        _isEditingProfile = false;
        _supaCustomer = {
          ..._supaCustomer!,
          'firstname': _firstNameController.text.trim(),
          'lastname': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        };
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('profile_updated_success_alt')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('profile_update_error_alt')} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Yol tarifi dialog'u
  void _showDirectionDialog() {
    if (!mounted) return;

    final Map<String, dynamic>? biz = _isletme is Map<String, dynamic>
        ? _isletme as Map<String, dynamic>
        : null;
    final String adres = (biz?['adres'] ?? '-').toString();
    final String ilce = (biz?['ilce'] ?? '-').toString();
    final String sehir = (biz?['sehir'] ?? '-').toString();
    final String posta = (biz?['posta_kodu'] ?? biz?['postakodu'] ?? '-')
        .toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? const Color(0xFF181818).withValues(alpha: 0.95)
              : const Color(0xFFEDECE8).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: SiriusColors.accent, width: 2),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/ikon/konumikon-Photoroom.png',
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('directions_dialog_title'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cormorant',
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: Colors.red, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('close'),
              ),
            ],
          ),
          content: DefaultTextStyle.merge(
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black87,
              fontFamily: 'Cormorant',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('address_label'),
                    adres,
                  ),
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('district_label'),
                    ilce,
                  ),
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('city_label'),
                    sehir,
                  ),
                  _buildContactInfoRow(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('postal_code_label'),
                    posta,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: SiriusColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_car,
                          color: SiriusColors.accent,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('public_transport_title'),
                          style: TextStyle(
                            color: _isDarkMode
                                ? SiriusColors.heading
                                : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Cormorant',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('public_transport_info'),
                          style: TextStyle(
                            color: _isDarkMode
                                ? SiriusColors.defaultText
                                : Colors.black87,
                            fontSize: 14,
                            fontFamily: 'Cormorant',
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Logout dialog'u göster
  void _showLogoutDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode
            ? const Color(0xFF181818).withValues(alpha: 0.95)
            : Colors.white,
        title: Text(
          lang.t('logout'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
          ),
        ),
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false).isEnglish
              ? 'Are you sure you want to logout?'
              : 'Çıkış yapmak istediğinizden emin misiniz?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('cancel'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red, width: 2),
            ),
            child: Text(lang.t('logout')),
          ),
        ],
      ),
    );
  }

  // Çıkış işlemini gerçekleştir
  Future<void> _performLogout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Tema değiştirme fonksiyonu
  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    themeProvider.setTheme(_isDarkMode);
  }
}
