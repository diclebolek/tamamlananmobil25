// ignore_for_file: unused_field, use_build_context_synchronously, deprecated_member_use, avoid_print
// Gerekli paketleri import ediyoruz.
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hairsalon_flutter/models/appointment.dart';
import 'package:hairsalon_flutter/models/employee.dart';
import 'package:hairsalon_flutter/models/employee_performance.dart';
import 'package:hairsalon_flutter/services/db_service.dart';
import 'package:hairsalon_flutter/constants/colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';

// Ana AdminScreen widget'ı
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

// Responsive tasarım için eşik değeri (kaldırıldı)

class _AdminScreenState extends State<AdminScreen> {
  // State değişkenleri
  final ImagePicker _imagePicker = ImagePicker();
  List<Map<String, dynamic>> _galeriItems = [];
  List<Map<String, dynamic>> _eventItems = [];
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, String> _icerikBlok = {};
  final Map<String, bool> _expanded = {
    'logo': false,
    'hero': false,
    'about_image': false,
    'why': false,
    'about': false,
    'gallery': false,
    'events': false,
    'account': false,
    'business': false,
    'contact': false,
    'address': false,
    'visual': false,
    'menu_services': false,
  };
  Future<List<Appointment>>? _appointmentsFuture;

  List<EmployeePerformance> _employeePerformance = [];
  bool _isLoadingPerformance = true;

  List<Employee> _allEmployees = [];
  bool _isLoadingEmployees = true;

  // Supabase ve çoklu-tenant için yardımcı durum
  String? _isletmeId;
  Map<String, dynamic>? _isletme;
  // Supabase randevu UUID -> UI'de kullanılan lokal int ID eşlemesi
  final Map<int, String> _localApptIdToUuid = {};
  int _localApptCounter = 0;

  // UI için controller'lar ve state
  int _selectedIndex =
      3; // 3: Home (default), 0: Employee Operations, 1: Employee Performance, 2: Personal Info
  int _employeeOpsIndex = 0; // 0: Appointments, 1: Employee Management

  // Seçili randevular için state
  Set<String> _selectedAppointments = {};

  // Dark mode ve dil seçenekleri
  bool _isDarkMode = true; // Varsayılan olarak dark mode
  final String _selectedLanguage = 'en'; // Default to English
  final bool _isDebugMode = true; // Debug modu varsayılan olarak açık
  final bool _isAutoRefresh =
      false; // Otomatik yenileme varsayılan olarak kapalı
  Timer? _autoRefreshTimer; // Otomatik yenileme timer'ı

  // Günlük özet sayıları
  int _todayTotalAppointments = 0;
  int _todayPendingAppointments = 0;
  int _todayCompletedAppointments = 0;

  // Çalışan listesi filtreleme
  String _employeeSearchQuery = '';
  final bool _employeeOnlyActive = false;

  // Drawer kontrolü için Scaffold key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Dialog içi setState için referans (StatefulBuilder)
  void Function(VoidCallback fn)? _dialogSetState;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedService;
  String? _selectedCategory;
  String? _selectedPhotoUrl;

  // Randevu arama/sıralama/filtreleme durumu
  String _appointmentSearchQuery = '';
  bool _appointmentSortAscending =
      false; // false: en yeni -> en eski (varsayılan)
  DateTime? _appointmentFilterStart;
  DateTime? _appointmentFilterEnd;
  String _appointmentFilterStatus =
      'All'; // All, Pending, Approved, Cancelled, Today

  @override
  void initState() {
    super.initState();

    // ThemeProvider'dan mevcut tema durumunu al
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      setState(() {
        _isDarkMode = themeProvider.isDarkMode;
      });
    });

    // Sıralı olarak veri yükle
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _loadIsletme();
      await _fetchEmployees();
      _appointmentsFuture = _getAppointmentsFromSupabase();
      await _fetchEmployeePerformance();
      await _fetchTodaySummary();
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.t('error_loading_data')}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _skillsController.dispose();
    _selectedAppointments.clear();
    super.dispose();
  }

  // --- Veri Çekme Fonksiyonları (PostgreSQL ile entegre edildi) ---

  Future<void> _fetchAppointments() async {
    if (mounted) {
      setState(() {
        _appointmentsFuture = _getAppointmentsFromSupabase();
      });
    }
  }

  Future<void> _refreshAppointments() async {
    await _fetchAppointments();
    await _fetchTodaySummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Randevular yenilendi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _ensureIsletmeId() async {
    if (!mounted) return;

    if (_isletmeId == null || _isletmeId!.isEmpty) {
      try {
        _isletmeId = await DbService.resolveIsletmeId();

        if (_isletmeId == null || _isletmeId!.isEmpty) {
          throw Exception(
            'İşletme ID çözümlenemedi. Supabase bağlantısını kontrol edin.',
          );
        }
      } catch (e, st) {
        debugPrint('[_ensureIsletmeId] Hata: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('İşletme ID alınamadı: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        rethrow;
      }
    } else {}
  }

  Future<void> _loadIsletme() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final isletme = await DbService.getIsletmeById(_isletmeId!);
      if (mounted) {
        setState(() {
          _isletme = isletme;
        });
      }
      // Galeri verilerini yükle
      try {
        final items = await DbService.getIsletmeResimleri(_isletmeId!);
        if (mounted) {
          setState(() {
            _galeriItems = items;
          });
        }
      } catch (e, st) {
        debugPrint('[_loadIsletme] Galeri yüklenemedi: $e\n$st');
      }
      // Etkinlikler (etkinlik tablosu) yükle
      try {
        final list = await DbService.getEtkinlikler(_isletmeId!);
        final normalized = <Map<String, dynamic>>[];
        for (final row in list) {
          final map = Map<String, dynamic>.from(row);
          // UI'de kullanılan anahtar adı uyumu için image_url aliası
          map['image_url'] = map['afis_url'];
          normalized.add(map);
        }
        if (mounted) {
          setState(() {
            _eventItems = normalized;
          });
        }
      } catch (e, st) {
        debugPrint('[_loadIsletme] Etkinlikler yüklenemedi: $e\n$st');
      }
      // Menü/Hizmetler yükle
      try {
        final menu = await DbService.getMenuHizmetIcerigi(_isletmeId!);
        if (mounted) {
          setState(() {
            _menuItems = menu;
          });
        }
      } catch (e, st) {
        debugPrint('[_loadIsletme] Menü yüklenemedi: $e\n$st');
      }
      // İçerik blok metinleri yükle (Why & About)
      try {
        final map = await DbService.getIcerikBlokMap(_isletmeId!);
        if (mounted) {
          setState(() {
            _icerikBlok = map;
          });
        }
      } catch (e, st) {
        debugPrint('[_loadIsletme] İçerik blokları yüklenemedi: $e\n$st');
      }
      await _fetchTodaySummary();
    } catch (e, st) {
      debugPrint('[_loadIsletme] Hata: $e\n$st');
    }
  }

  Future<List<Appointment>> _getAppointmentsFromSupabase() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        return [];
      }

      final client = Supabase.instance.client;

      // Önce basit bir sorgu ile test et
      try {
        await client
            .from('randevu')
            .select(
              'randevu_id, appointment_datetime, total_price, approval_status',
            )
            .limit(1);
      } catch (e) {
        // Hata detaylarını göster
        if (e.toString().contains('PGRST205')) {
        } else if (e.toString().contains('permission denied')) {}
        // Eğer randevu tablosu yoksa boş liste döndür
        return [];
      }

      // Ana sorgu - önce ilişkisel dene; hata olursa ilişkisel olmayan basit sorguya düş
      List data;
      try {
        data = await client
            .from('randevu')
            .select(
              'randevu_id, appointment_datetime, process, total_price, approval_status, notes, customerid, calisan_id, hizmet_id,'
              'musteriler:customerid (firstname, lastname, email, phone),'
              'calisanlar:calisan_id (ad, soyad),'
              'menu_hizmet_icerigi:hizmet_id (hizmet, hizmet_adi)',
            )
            .eq('isletme_id', _isletmeId!)
            .order('appointment_datetime', ascending: false);
      } catch (e) {
        data = await client
            .from('randevu')
            .select(
              'randevu_id, appointment_datetime, process, total_price, approval_status, notes, customerid, calisan_id, hizmet_id,'
              'musteriler:customerid (firstname, lastname, email, phone),'
              'calisanlar:calisan_id (ad, soyad)',
            )
            .eq('isletme_id', _isletmeId!)
            .order('appointment_datetime', ascending: false);
      }

      // Widget dispose edildiyse işlemi durdur
      if (!mounted) return [];

      // Yeni liste ve lokal ID eşlemelerini oluştur
      _localApptIdToUuid.clear();
      _localApptCounter = 0;

      final List<Appointment> list = [];
      for (final row in data) {
        final map = row as Map<String, dynamic>;
        _localApptCounter += 1;
        final localId = _localApptCounter;
        final uuid = (map['randevu_id'] ?? '').toString();
        _localApptIdToUuid[localId] = uuid; // UUID saklıyoruz (randevu_id uuid)

        final dynamic priceVal = map['total_price'];
        double price = 0.0;
        if (priceVal is num) {
          price = priceVal.toDouble();
        } else if (priceVal is String) {
          price = double.tryParse(priceVal) ?? 0.0;
        }

        final dynamic dtVal = map['appointment_datetime'];
        final DateTime apptDt = dtVal is String
            ? DateTime.parse(dtVal)
            : (dtVal is DateTime ? dtVal : DateTime.now());

        // process alanını metne çevir (0/1/2)
        String processText = 'Waiting';
        final dynamic proc = map['process'];
        if (proc is int) {
          switch (proc) {
            case 0:
              processText = 'Waiting';
              break;
            case 1:
              processText = 'In Progress';
              break;
            case 2:
              processText = 'Completed';
              break;
            default:
              processText = 'Unknown';
          }
        }

        // İlişkisel alanlardan isim ve iletişim bilgileri
        final musteriler = map['musteriler'] as Map<String, dynamic>?;
        final calisan = map['calisanlar'] as Map<String, dynamic>?;
        final hizmet = map['menu_hizmet_icerigi'] as Map<String, dynamic>?;

        final String customerFirst = (musteriler?['firstname'] ?? '')
            .toString();
        final String customerLast = (musteriler?['lastname'] ?? '').toString();
        final String customerName = [
          customerFirst,
          customerLast,
        ].where((p) => p.trim().isNotEmpty).join(' ');

        final String employeeFirst = (calisan?['ad'] ?? '').toString();
        final String employeeLast = (calisan?['soyad'] ?? '').toString();
        final String employeeName = [
          employeeFirst,
          employeeLast,
        ].where((p) => p.trim().isNotEmpty).join(' ');

        // Hizmet adı: varsa 'hizmet', yoksa 'hizmet_adi', ikisi de yoksa '-'
        final String serviceName =
            ((hizmet?['hizmet'] ?? '') as String).toString().trim().isNotEmpty
            ? (hizmet?['hizmet'] as String)
            : (((hizmet?['hizmet_adi'] ?? '') as String)
                      .toString()
                      .trim()
                      .isNotEmpty
                  ? (hizmet?['hizmet_adi'] as String)
                  : '-');

        list.add(
          Appointment(
            appointmentId:
                localId, // UI aynı kalsın diye lokal sayı kullanıyoruz
            customerName: customerName.isNotEmpty ? customerName : 'Unknown',
            employeeName: employeeName.isNotEmpty ? employeeName : 'Unknown',
            serviceName: serviceName,
            process: processText,
            totalPrice: price,
            appointmentDateTime: apptDt,
            approvalStatus: (map['approval_status'] ?? 'Pending').toString(),
            createdAt: null,
            updatedAt: null,
            notes: (map['notes'] as String?),
            customerPhone: (musteriler?['phone'] as String?) ?? '',
            customerEmail: (musteriler?['email'] as String?) ?? '',
          ),
        );
      }

      return list;
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Randevu verileri yüklenirken hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return [];
    }
  }

  // Çalışan ekleme
  Future<void> _addEmployee() async {
    if (!mounted) return;

    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _skillsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).t('please_fill_all_fields'),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('Business ID not found');
      }

      final client = Supabase.instance.client;

      // Çalışan eklemeden önce aynı isimde çalışan var mı kontrol et
      final existingEmployee = await client
          .from('calisanlar')
          .select('id')
          .eq('isletme_id', _isletmeId!)
          .eq('ad', _firstNameController.text.trim())
          .eq('soyad', _lastNameController.text.trim())
          .maybeSingle();

      if (existingEmployee != null) {
        throw Exception('An employee with this name already exists!');
      }

      await client.from('calisanlar').insert({
        'isletme_id': _isletmeId,
        'ad': _firstNameController.text.trim(),
        'soyad': _lastNameController.text.trim(),
        'beceriler': _skillsController.text.trim(),
        'uzmanlik': _selectedCategory ?? 'general',
        'hizmet': _selectedService ?? 'General',
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'resim_url': _selectedPhotoUrl,
        'profil_resmi': _selectedPhotoUrl,
        'aktif': true,
        'sira': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      _firstNameController.clear();
      _lastNameController.clear();
      _skillsController.clear();
      _emailController.clear();
      _phoneController.clear();
      _selectedService = null;
      _selectedCategory = null;
      _selectedPhotoUrl = null;

      if (mounted) {
        await _fetchEmployees();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('employee_added_success'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${Provider.of<LanguageProvider>(context, listen: false).t('error_occurred')} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Çalışan güncelleme
  Future<void> _updateEmployee(Employee employee) async {
    try {
      if (!mounted) return;

      // Supabase bağlantı kontrolü
      try {
        final client = Supabase.instance.client;
        await client.from('isletme').select('isletme_id').limit(1);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Supabase bağlantısı kurulamadı. Çalışan güncellenemedi.\nHata: $e',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('Business ID not found');
      }

      final client = Supabase.instance.client;
      if (employee.id == null) {
        throw Exception('Employee ID not found');
      }

      // Güncelleme öncesi aynı isimde başka çalışan var mı kontrol et
      final existingEmployee = await client
          .from('calisanlar')
          .select('id')
          .eq('isletme_id', _isletmeId!)
          .eq('ad', employee.firstName.trim())
          .eq('soyad', employee.lastName.trim())
          .neq('id', employee.id!)
          .maybeSingle();

      if (existingEmployee != null) {
        throw Exception('Another employee with this name already exists!');
      }

      await client
          .from('calisanlar')
          .update({
            'ad': employee.firstName.trim(),
            'soyad': employee.lastName.trim(),
            'beceriler': employee.skills.trim(),
            'hizmet': employee.expertise.trim(),
            'email': employee.email?.trim().isEmpty == true
                ? null
                : employee.email?.trim(),
            'phone': employee.phone?.trim().isEmpty == true
                ? null
                : employee.phone?.trim(),
            'resim_url': employee.profileImage,
            'profil_resmi': employee.profileImage,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', employee.id!);

      if (mounted) {
        await _fetchEmployees();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('employee_updated_success'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${Provider.of<LanguageProvider>(context, listen: false).t('error_occurred')} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Çalışan silme
  Future<void> _deleteEmployee(int employeeId) async {
    try {
      if (!mounted) return;

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('Business ID not found');
      }

      final client = Supabase.instance.client;
      // Soft delete
      await client
          .from('calisanlar')
          .update({'aktif': false})
          .eq('id', employeeId);

      if (mounted) {
        await _fetchEmployees();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('employee_deleted_success'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${Provider.of<LanguageProvider>(context, listen: false).t('error_occurred')} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchEmployeePerformance() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingPerformance = true;
        });
      }

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        if (mounted) {
          setState(() {
            _employeePerformance = [];
            _isLoadingPerformance = false;
          });
        }
        return;
      }

      // Önce çalışanların yüklenmesini bekle
      if (_allEmployees.isEmpty) {
        await _fetchEmployees();
        // Çalışanlar yüklendikten sonra tekrar kontrol et
        if (_allEmployees.isEmpty) {
          if (mounted) {
            setState(() {
              _employeePerformance = [];
              _isLoadingPerformance = false;
            });
          }
          return;
        }
      }

      final client = Supabase.instance.client;
      final today = DateTime.now();
      final dateStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      List<EmployeePerformance> performances = [];

      // Önce performans tablosundan veri çekmeyi dene
      try {
        final rows = await client
            .from('calisan_performans')
            .select()
            .eq('isletme_id', _isletmeId!)
            .eq('tarih', dateStr)
            .order('created_at', ascending: true);

        if (rows.isNotEmpty) {
          final Map<int, String> idToName = {
            for (final e in _allEmployees)
              if (e.id != null) e.id!: e.fullName,
          };

          for (final row in (rows as List)) {
            final m = row as Map<String, dynamic>;
            final calisanId = (m['calisan_id'] as num?)?.toInt();
            final name = calisanId != null
                ? (idToName[calisanId] ?? 'Bilinmeyen')
                : 'Bilinmeyen';
            performances.add(
              EmployeePerformance(
                employeeName: name,
                dailyEarnings: (m['gunluk_kazanc'] as num?)?.toDouble() ?? 0.0,
                totalEarnings: (m['toplam_kazanc'] as num?)?.toDouble() ?? 0.0,
                efficiency: (m['verimlilik'] as num?)?.toDouble() ?? 0.0,
                date:
                    DateTime.tryParse((m['tarih'] ?? dateStr).toString()) ??
                    today,
                appointmentsCompleted:
                    (m['tamamlanan_randevu'] as num?)?.toInt() ?? 0,
                averageRating: (m['ortalama_puan'] as num?)?.toDouble() ?? 0.0,
              ),
            );
          }
        }
      } catch (e) {
        performances = [];
      }

      // Eğer performans tablosunda veri yoksa, randevulardan hesapla
      if (performances.isEmpty) {
        try {
          final now = DateTime.now();
          // Son 30 günlük veriyi al
          final start = DateTime(now.year, now.month, now.day - 30, 0, 0, 0);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

          // Tüm çalışanlar için performans hesapla (randevu olsun ya da olmasın)
          // ignore: unused_local_variable
          final Map<int, String> idToName = {
            for (final e in _allEmployees)
              if (e.id != null) e.id!: e.fullName,
          };

          // Her çalışan için performans hesapla
          final List<EmployeePerformance> computed = [];

          for (final employee in _allEmployees) {
            if (employee.id == null) continue;

            final empId = employee.id!;
            final name = employee.fullName;

            try {
              // Bu çalışanın randevularını getir (bugünkü onaylanan randevulara öncelik ver)
              final today = DateTime.now();
              final todayStart = DateTime(
                today.year,
                today.month,
                today.day,
                0,
                0,
                0,
              );
              final todayEnd = DateTime(
                today.year,
                today.month,
                today.day,
                23,
                59,
                59,
                999,
              );

              // Önce bugünkü onaylanan randevuları getir (çeşitli durum değerlerini kabul et)
              final todayAppts = await client
                  .from('randevu')
                  .select(
                    'calisan_id, approval_status, total_price, appointment_datetime',
                  )
                  .eq('isletme_id', _isletmeId!)
                  .eq('calisan_id', empId)
                  .or(
                    "approval_status.eq.Approved,approval_status.eq.approved,"
                    "approval_status.eq.Completed,approval_status.eq.completed,"
                    "approval_status.eq.Approved,approval_status.eq.approved,"
                    "approval_status.eq.Completed,approval_status.eq.completed",
                  )
                  .gte(
                    'appointment_datetime',
                    todayStart.toUtc().toIso8601String(),
                  )
                  .lte(
                    'appointment_datetime',
                    todayEnd.toUtc().toIso8601String(),
                  );

              // Bugünkü bekleyen randevuları getir
              final todayPendingAppts = await client
                  .from('randevu')
                  .select(
                    'calisan_id, approval_status, total_price, appointment_datetime',
                  )
                  .eq('isletme_id', _isletmeId!)
                  .eq('calisan_id', empId)
                  .eq('approval_status', 'Pending')
                  .gte(
                    'appointment_datetime',
                    todayStart.toUtc().toIso8601String(),
                  )
                  .lte(
                    'appointment_datetime',
                    todayEnd.toUtc().toIso8601String(),
                  );

              // Sonra genel randevuları getir
              final appts = await client
                  .from('randevu')
                  .select(
                    'calisan_id, approval_status, total_price, appointment_datetime',
                  )
                  .eq('isletme_id', _isletmeId!)
                  .eq('calisan_id', empId)
                  .gte('appointment_datetime', start.toIso8601String())
                  .lte('appointment_datetime', end.toIso8601String());

              int approvedCount = 0;
              int pendingCount = 0;
              double totalEarnings = 0.0;
              double todayEarnings = 0.0;

              // Bugünkü onaylanan randevuları işle
              for (final row in (todayAppts as List)) {
                final m = row as Map<String, dynamic>;
                final dynamic rawPrice = m['total_price'];
                final double price = rawPrice is num
                    ? rawPrice.toDouble()
                    : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;
                todayEarnings += price;
                approvedCount++;
              }

              // Genel randevuları işle
              for (final row in (appts as List)) {
                final m = row as Map<String, dynamic>;
                final status = (m['approval_status'] ?? '')
                    .toString()
                    .toLowerCase();
                final dynamic rawPrice = m['total_price'];
                final double price = rawPrice is num
                    ? rawPrice.toDouble()
                    : double.tryParse(rawPrice?.toString() ?? '') ?? 0.0;

                if (status == 'approved' ||
                    status == 'tamamlandı' ||
                    status == 'onaylandı' ||
                    status == 'completed') {
                  totalEarnings += price;
                }
              }

              // Bugünkü bekleyenleri say
              pendingCount = (todayPendingAppts as List).length;

              final total = approvedCount + pendingCount;
              // Verimlilik: Onaylanan randevular / Toplam randevular * 100
              final efficiency = total > 0
                  ? (approvedCount * 100.0 / total)
                  : 0.0;

              computed.add(
                EmployeePerformance(
                  employeeName: name,
                  dailyEarnings: todayEarnings, // Bugünkü kazancı kullan
                  totalEarnings: totalEarnings, // Tüm zamanlardan toplam kazanç
                  efficiency: efficiency,
                  date: DateTime(now.year, now.month, now.day),
                  appointmentsCompleted: approvedCount,
                  averageRating: approvedCount > 0
                      ? 4.5
                      : 0.0, // Onaylanan randevu varsa rating ver
                  pendingAppointments: pendingCount,
                ),
              );
            } catch (e) {
              // Hata durumunda da çalışanı ekle (sıfır performans ile)
              computed.add(
                EmployeePerformance(
                  employeeName: name,
                  dailyEarnings: 0.0,
                  totalEarnings: 0.0,
                  efficiency: 0.0,
                  date: DateTime(now.year, now.month, now.day),
                  appointmentsCompleted: 0,
                  averageRating: 0.0,
                  pendingAppointments: 0,
                ),
              );
            }
          }

          performances = computed;
        } catch (e) {
          // Hata durumunda tüm çalışanları sıfır performans ile ekle
          performances = _allEmployees
              .map(
                (employee) => EmployeePerformance(
                  employeeName: employee.fullName,
                  dailyEarnings: 0.0,
                  totalEarnings: 0.0,
                  efficiency: 0.0,
                  date: DateTime.now(),
                  appointmentsCompleted: 0,
                  averageRating: 0.0,
                  pendingAppointments: 0,
                ),
              )
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _employeePerformance = performances;
          _isLoadingPerformance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPerformance = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${Provider.of<LanguageProvider>(context, listen: false).t('error_loading_performance')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = true;
        });
      }

      await _ensureIsletmeId();
      if (_isletmeId == null) {
        if (mounted) {
          setState(() {
            _allEmployees = [];
            _isLoadingEmployees = false;
          });
        }
        return;
      }

      final client = Supabase.instance.client;

      // Önce tüm çalışanları getir (aktif olmayanlar dahil)
      final allRows = await client
          .from('calisanlar')
          .select()
          .eq('isletme_id', _isletmeId!)
          .order('sira', ascending: true)
          .order('created_at', ascending: true);

      // Sadece aktif çalışanları filtrele
      final rows = await client
          .from('calisanlar')
          .select()
          .eq('isletme_id', _isletmeId!)
          .eq('aktif', true) // Sadece aktif çalışanları getir
          .order('sira', ascending: true)
          .order('created_at', ascending: true);

      // Eğer aktif çalışan yoksa, tüm çalışanları göster
      final finalRows = (rows as List).isNotEmpty ? rows : allRows;

      final employees = <Employee>[];
      for (final row in (finalRows as List)) {
        final m = row as Map<String, dynamic>;
        final empId = (m['id'] as num?)?.toInt();
        final firstName = (m['ad'] ?? '').toString();
        final lastName = (m['soyad'] ?? '').toString();
        final isActive = (m['aktif'] as bool?) ?? true;

        employees.add(
          Employee(
            id: empId,
            firstName: firstName,
            lastName: lastName,
            expertise: (m['hizmet'] ?? 'Genel').toString(),
            skills: (m['beceriler'] ?? '').toString(),
            prolificacy: null,
            dailyEarnings: null,
            serviceId: null,
            email: (m['email'] as String?),
            phone: (m['phone'] as String?),
            isActive: isActive,
            hireDate: m['ise_baslama_tarihi'] != null
                ? DateTime.tryParse(m['ise_baslama_tarihi'].toString())
                : null,
            profileImage: (m['profil_resmi'] as String?),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allEmployees = employees;
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEmployees = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${Provider.of<LanguageProvider>(context, listen: false).t('error_loading_employees')}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      // Keep reference to avoid unused warning without affecting runtime
      _showEditProfileDialog;
      _buildProfileInfoRow;
      return true;
    }());
    return Scaffold(
      extendBody: true,
      key: _scaffoldKey,
      backgroundColor: _isDarkMode
          ? Colors
                .black // Dark mode'da siyah (eskisi gibi)
          : const Color(0xFFE5E2DB), // Açık modda #E5E2DB rengi
      appBar: AppBar(
        backgroundColor: (_isDarkMode ? Colors.black : Colors.white).withValues(
          alpha: 0.08,
        ),
        elevation: 0,
        toolbarHeight: (!kIsWeb && MediaQuery.of(context).size.width <= 768)
            ? 48
            : 56,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: (!kIsWeb && MediaQuery.of(context).size.width <= 768)
            ? 0
            : null,
        leadingWidth: (!kIsWeb && MediaQuery.of(context).size.width <= 768)
            ? 0
            : null,
        leading: (kIsWeb || MediaQuery.of(context).size.width > 768)
            ? IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: Icon(
                  Icons.menu,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                tooltip: 'Menu',
              )
            : const SizedBox.shrink(),
        iconTheme: IconThemeData(
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),

        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: (_isDarkMode ? Colors.black : Colors.white).withValues(
                  alpha: 0.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 400;
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobileOrTablet = !kIsWeb && screenWidth <= 768;

            // Logo + İşletme adı widget'ı
            Widget logoAndName = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ((_isletme != null) &&
                        ((_isletme!['logo_url'] as String?)?.isNotEmpty ==
                            true))
                    ? Image.network(
                        ((_isletme!['logo_url'] as String).startsWith('http') ||
                                (_isletme!['logo_url'] as String).startsWith(
                                  'https',
                                ))
                            ? (_isletme!['logo_url'] as String)
                            : DbService.getPublicImageUrl(
                                _isletme!['logo_url'] as String,
                              ),
                        height: isMobileOrTablet ? 28 : (isNarrow ? 32 : 40),
                        width: isMobileOrTablet ? 28 : (isNarrow ? 32 : 40),
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.storefront_rounded,
                            size: isMobileOrTablet ? 28 : (isNarrow ? 32 : 40),
                          );
                        },
                      )
                    : Icon(
                        Icons.storefront_rounded,
                        size: isMobileOrTablet ? 28 : (isNarrow ? 32 : 40),
                      ),
                SizedBox(width: isMobileOrTablet ? 8 : 10),
                // İşletme adı
                Flexible(
                  child: Text(
                    (_isletme != null && (_isletme!['isim'] as String?) != null)
                        ? ((_isletme!['isim'] as String?) ?? 'Sirius')
                        : 'Sirius',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      fontFamily: 'Cormorant',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );

            // Web kontrolü - her zaman web'de hamburger göster
            final isWebOrLargeScreen = kIsWeb || screenWidth > 768;

            if (isWebOrLargeScreen) {
              // Web/büyük ekranda: Leading'de hamburger var, başlıkta sağda logo+isim
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [logoAndName],
              );
            } else {
              // Mobil ve tablet'te: Sol logo+isim (hamburger menü yok)
              return Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [logoAndName],
              );
            }
          },
        ),
        actions: [],
      ),
      drawer: _buildSidebarDrawer(),
      body: SafeArea(
        child: _selectedIndex == 0
            ? _buildEmployeeOperations()
            : _selectedIndex == 1
            ? _buildPerformanceAnalysis()
            : _selectedIndex == 2
            ? _buildWelcomeScreen()
            : _selectedIndex == 3
            ? _buildHomeScreen()
            : _buildWelcomeScreen(),
      ),
      bottomNavigationBar: _buildAdminBottomNavigationBar(),
    );
  }

  // Drawer içeriği (eski sol sidebar ile aynı)
  Widget _buildSidebarDrawer() {
    final lang = Provider.of<LanguageProvider>(context);
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width < 400 ? 200 : 250,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: (_isDarkMode ? Colors.black : Colors.white).withValues(
                alpha: 0.2,
              ),
              border: Border(
                right: BorderSide(
                  color: (_isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.25,
                  ),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
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
                          (_isletme != null &&
                                  (_isletme!['isim'] as String?) != null)
                              ? ((_isletme!['isim'] as String?) ?? 'Sirius')
                              : 'Sirius',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Playfair Display',
                          ),
                        ),
                        Text(
                          (_isletme != null &&
                                  (_isletme!['aciklama'] as String?) != null)
                              ? ((_isletme!['aciklama'] as String?) ??
                                    'Beauty & Spa')
                              : 'Beauty & Spa',
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
                  // Home at the top
                  _buildSidebarItem(
                    icon: Icons.home,
                    title: lang.t('home_title'),
                    isSelected: _selectedIndex == 3,
                    onTap: () {
                      setState(() => _selectedIndex = 3);
                      Navigator.of(context).pop();
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.work,
                    title: lang.t('employee_and_appointment'),
                    isSelected: _selectedIndex == 0,
                    onTap: () {
                      setState(() => _selectedIndex = 0);
                      Navigator.of(context).pop();
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.analytics,
                    title: lang.t('performance_analysis'),
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      setState(() => _selectedIndex = 1);
                      Navigator.of(context).pop();
                    },
                  ),
                  // Yeni: Profil Bilgileri
                  _buildSidebarItem(
                    icon: Icons.person,
                    title: lang.t('profile_info'),
                    isSelected: false,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showAdminProfileDialog();
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

  void _toggleTheme() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    themeProvider.setTheme(_isDarkMode);
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
              ? SiriusColors.accent
              : (_isDarkMode ? Colors.white : Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? SiriusColors.accent
                : (_isDarkMode ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected
            ? SiriusColors.accent.withValues(alpha: 0.1)
            : null,
      ),
    );
  }

  Widget _buildEmployeeOperations() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Column(
      children: [
        // Tab Buttons
        Container(
          margin: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 20,
          ),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SiriusColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SiriusColors.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  title: lang.t('appointments'),
                  isSelected: _employeeOpsIndex == 0,
                  onTap: () => setState(() {
                    _employeeOpsIndex = 0;
                    _selectedAppointments.clear();
                  }),
                ),
              ),
              Expanded(
                child: _buildTabButton(
                  title: lang.t('employee_management'),
                  isSelected: _employeeOpsIndex == 1,
                  onTap: () => setState(() {
                    _employeeOpsIndex = 1;
                    _selectedAppointments.clear();
                  }),
                ),
              ),
            ],
          ),
        ),

        // İçerik - Expanded kullanarak overflow'u önlüyoruz
        Expanded(
          child: _employeeOpsIndex == 0
              ? _buildAppointmentsTab()
              : _buildEmployeeManagementTab(),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.width < 600 ? 12 : 16,
          horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 20,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? SiriusColors.accent
              : (_isDarkMode
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SiriusColors.accent : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? SiriusColors.contrast : SiriusColors.heading,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (_appointmentsFuture == null) {
      return Center(
        child: CircularProgressIndicator(color: SiriusColors.accent),
      );
    }

    return FutureBuilder<List<Appointment>>(
      future: _appointmentsFuture!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: SiriusColors.accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Randevular yüklenirken hata oluştu: ${snapshot.error}',
                  style: const TextStyle(
                    color: SiriusColors.defaultText,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchAppointments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SiriusColors.accent,
                    foregroundColor: SiriusColors.contrast,
                  ),
                  child: Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('try_again'),
                  ),
                ),
              ],
            ),
          );
        }

        final appointments = snapshot.data ?? [];

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Arama ve Filtreleme
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 12 : 16,
                ),
                color: _isDarkMode
                    ? SiriusColors.surface
                    : Colors.black.withValues(
                        alpha: 0.3,
                      ), // Açık modda transparan siyah
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arama ve Filtreleme
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isNarrow = constraints.maxWidth < 500;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('search_appointment_hint'),
                                  prefixIcon: Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                onChanged: (query) {
                                  setState(() {
                                    _appointmentSearchQuery = query.trim();
                                  });
                                },
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('search_appointment_hint'),
                                  prefixIcon: Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                onChanged: (query) {
                                  setState(() {
                                    _appointmentSearchQuery = query.trim();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Eski sıralama butonu kaldırıldı - artık üç ikonun sağında
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Günlük özet - sadece ikonlar + sıralama butonu
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // All butonu
                          Tooltip(
                            message: 'Tüm randevular',
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appointmentFilterStatus = 'All';
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _appointmentFilterStatus == 'All'
                                      ? Colors.red.withValues(alpha: 0.8)
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                  border: _appointmentFilterStatus == 'All'
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: const Icon(
                                  Icons.list,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: 'Bugün: $_todayTotalAppointments',
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appointmentFilterStatus =
                                      _appointmentFilterStatus == 'Today'
                                      ? 'All'
                                      : 'Today';
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _appointmentFilterStatus == 'Today'
                                      ? Colors.blue.withValues(alpha: 0.8)
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                  border: _appointmentFilterStatus == 'Today'
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: const Icon(
                                  Icons.today,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message:
                                '${Provider.of<LanguageProvider>(context, listen: false).t('pending')}: $_todayPendingAppointments',
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appointmentFilterStatus =
                                      _appointmentFilterStatus == 'Pending'
                                      ? 'All'
                                      : 'Pending';
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _appointmentFilterStatus == 'Pending'
                                      ? Colors.orange.withValues(alpha: 0.8)
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                  border: _appointmentFilterStatus == 'Pending'
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: const Icon(
                                  Icons.timelapse,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Tooltip(
                            message:
                                '${Provider.of<LanguageProvider>(context, listen: false).t('confirmed')}: $_todayCompletedAppointments',
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appointmentFilterStatus =
                                      _appointmentFilterStatus == 'Approved'
                                      ? 'All'
                                      : 'Approved';
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _appointmentFilterStatus == 'Approved'
                                      ? Colors.green.withValues(alpha: 0.8)
                                      : Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                  border: _appointmentFilterStatus == 'Approved'
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // İptal edilenler ikonu
                          Tooltip(
                            message: Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('cancelled'),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appointmentFilterStatus =
                                      _appointmentFilterStatus == 'Cancelled'
                                      ? 'All'
                                      : 'Cancelled';
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _appointmentFilterStatus == 'Cancelled'
                                      ? Colors.red.withValues(alpha: 0.8)
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      _appointmentFilterStatus == 'Cancelled'
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: const Icon(
                                  Icons.cancel,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sıralama butonu (mobilde dört ikonun sağında)
                          Tooltip(
                            message: _appointmentSortAscending
                                ? 'Eskiden Yeniye'
                                : 'En Yeniden Eskiye',
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _appointmentSortAscending =
                                      !_appointmentSortAscending;
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: SiriusColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: SiriusColors.accent,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.swap_vert,
                                  color: SiriusColors.accent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Üst işlem butonları - Sağ üstte ikonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tümünü seç checkbox'ı
                        Row(
                          children: [
                            Transform.scale(
                              scale: 0.8,
                              child: Checkbox(
                                value:
                                    _selectedAppointments.length ==
                                        _getFilteredAppointments(
                                          appointments,
                                        ).length &&
                                    _getFilteredAppointments(
                                      appointments,
                                    ).isNotEmpty,
                                tristate: true,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      // Tümünü seç (sadece filtrelenmiş olanları)
                                      _selectedAppointments =
                                          _getFilteredAppointments(appointments)
                                              .map(
                                                (appointment) => appointment
                                                    .appointmentId
                                                    .toString(),
                                              )
                                              .toSet();
                                    } else {
                                      // Tümünü kaldır
                                      _selectedAppointments.clear();
                                    }
                                  });
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            Text(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('select_all'),
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        // Sağ taraftaki işlem butonları
                        Row(
                          children: [
                            // Seçili randevuları silme ikonu
                            IconButton(
                              onPressed: _selectedAppointments.isEmpty
                                  ? null
                                  : () => _showBulkDeleteDialog(
                                      appointments
                                          .where(
                                            (appointment) =>
                                                _selectedAppointments.contains(
                                                  appointment.appointmentId
                                                      .toString(),
                                                ),
                                          )
                                          .toList(),
                                    ),
                              icon: Builder(
                                builder: (context) {
                                  final bool isMobile =
                                      MediaQuery.of(context).size.width < 600;
                                  return Icon(
                                    Icons.delete,
                                    color: _selectedAppointments.isEmpty
                                        ? Colors.grey
                                        : Colors.red[600],
                                    size: isMobile ? 18 : 24,
                                  );
                                },
                              ),
                              tooltip: lang.t('delete_selected_appointments'),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width < 600
                                  ? 4
                                  : 8,
                            ),
                            // Yenileme ikonu
                            IconButton(
                              onPressed: () => _refreshAppointments(),
                              icon: Builder(
                                builder: (context) {
                                  final bool isMobile =
                                      MediaQuery.of(context).size.width < 600;
                                  return Icon(
                                    Icons.refresh,
                                    color: SiriusColors.accent,
                                    size: isMobile ? 18 : 24,
                                  );
                                },
                              ),
                              tooltip: Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('refresh'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Alt padding overflow önlemek için
              const SizedBox(height: 16),

              // Randevu Listesi
              if (appointments.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz randevu bulunmuyor',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Müşteriler randevu oluşturduğunda burada görünecek',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white54 : Colors.black54,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _getFilteredAppointments(appointments).length,
                  itemBuilder: (context, index) {
                    List<Appointment> filteredAppointments =
                        _getFilteredAppointments(appointments);
                    filteredAppointments.sort((a, b) {
                      return _appointmentSortAscending
                          ? a.appointmentDateTime.compareTo(
                              b.appointmentDateTime,
                            )
                          : b.appointmentDateTime.compareTo(
                              a.appointmentDateTime,
                            );
                    });
                    final appointment = filteredAppointments[index];
                    final isSelected = _selectedAppointments.contains(
                      appointment.appointmentId.toString(),
                    );

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? SiriusColors.surface.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: SiriusColors.accent, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          appointment.customerName,
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  appointment.employeeName,
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if ((appointment.notes ?? '')
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                                  InkWell(
                                    onTap: () async {
                                      final titleText = (() {
                                        final t = Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).t('appointment_note');
                                        return t == 'appointment_note'
                                            ? 'Appointment Note'
                                            : t;
                                      })();
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: _isDarkMode
                                              ? Colors.black
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          titlePadding: const EdgeInsets.only(
                                            left: 20,
                                            top: 16,
                                            right: 8,
                                            bottom: 0,
                                          ),
                                          title: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  titleText,
                                                  style: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
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
                                          content: Text(
                                            appointment.notes!.trim(),
                                            style: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 2),
                                      child: Icon(
                                        Icons.sticky_note_2_outlined,
                                        color: Colors.blueAccent,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${appointment.appointmentDateTime.day}/${appointment.appointmentDateTime.month}/${appointment.appointmentDateTime.year} - ${appointment.appointmentDateTime.hour}:${appointment.appointmentDateTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _cycleAppointmentStatus(
                                  appointment.appointmentId.toString(),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      appointment.approvalStatus,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final bool isVerySmall =
                                          MediaQuery.of(context).size.width <
                                          350;
                                      final String statusText =
                                          _getTranslatedStatus(
                                            appointment.approvalStatus,
                                          );
                                      final String displayText = isVerySmall
                                          ? _getStatusInitials(statusText)
                                          : statusText;

                                      return Text(
                                        displayText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₺${appointment.totalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: SiriusColors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAppointments.remove(
                                appointment.appointmentId.toString(),
                              );
                            } else {
                              _selectedAppointments.add(
                                appointment.appointmentId.toString(),
                              );
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'onaylandı':
      case 'completed':
      case 'tamamlandı':
        return Colors.green;
      case 'pending':
      case 'bekliyor':
        return Colors.orange;
      case 'cancelled':
      case 'canceled':
      case 'iptal':
      case 'denied':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTranslatedStatus(String status) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    switch (status.toLowerCase()) {
      case 'approved':
      case 'onaylandı':
      case 'completed':
      case 'tamamlandı':
        return lang.t('confirmed');
      case 'pending':
      case 'bekliyor':
        return lang.t('pending');
      case 'cancelled':
      case 'canceled':
      case 'iptal':
      case 'denied':
        return lang.t('cancelled');
      default:
        return status;
    }
  }

  String _getStatusInitials(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'onaylanan':
        return 'O';
      case 'pending':
      case 'bekleyen':
        return 'B';
      case 'cancelled':
      case 'iptal':
        return 'İ';
      default:
        return status.isNotEmpty ? status[0].toUpperCase() : '?';
    }
  }

  // Randevu durumunu döngüsel olarak değiştir
  Future<void> _cycleAppointmentStatus(String appointmentId) async {
    try {
      // Mevcut randevuları al
      if (_appointmentsFuture == null) return;
      final appointments = await _appointmentsFuture!;

      // Mevcut randevuyu bul
      final appointment = appointments.firstWhere(
        (apt) => apt.appointmentId.toString() == appointmentId,
      );

      // Durum döngüsü: Pending -> Approved -> Cancelled -> Pending
      String newStatus;
      switch (appointment.approvalStatus.toLowerCase()) {
        case 'pending':
        case 'bekliyor':
          newStatus = 'Approved';
          break;
        case 'approved':
        case 'onaylandı':
        case 'completed':
        case 'tamamlandı':
          newStatus = 'Cancelled';
          break;
        case 'cancelled':
        case 'iptal':
        case 'denied':
          newStatus = 'Pending';
          break;
        default:
          newStatus = 'Pending';
      }

      await _updateAppointmentStatus(appointmentId, newStatus);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Randevu durumunu güncelle
  Future<void> _updateAppointmentStatus(
    String appointmentId,
    String newStatus,
  ) async {
    try {
      final client = Supabase.instance.client;

      // Lokal ID -> UUID eşlemesini kullan (randevu_id uuid)
      String idToUse = appointmentId;
      final int? localId = int.tryParse(appointmentId);
      if (localId != null) {
        final String? uuid = _localApptIdToUuid[localId];
        if (uuid != null && uuid.isNotEmpty) {
          idToUse = uuid;
        }
      }

      // Supabase'de güncelle - randevu_id UUID ile
      await client
          .from('randevu')
          .update({'approval_status': newStatus})
          .eq('randevu_id', idToUse);

      // Yerel state'i güncelle
      setState(() {
        // Randevuları yeniden yükle
        _fetchAppointments();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Randevu durumu güncellendi: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmployeeManagementTab() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return Column(
      children: [
        // Çalışan Yönetimi Kartı
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? SiriusColors.surface
                : Colors.black.withValues(
                    alpha: 0.3,
                  ), // Açık modda transparan siyah
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SiriusColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people,
                            color: SiriusColors.accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('employee_management'),
                                style: TextStyle(
                                  color: SiriusColors.heading,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('name_surname_and_actions'),
                                style: TextStyle(
                                  color: SiriusColors.defaultText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        MediaQuery.of(context).size.width < 600
                            ? SizedBox(
                                width: 44,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () => _showAddEmployeeDialog(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SiriusColors.accent,
                                    foregroundColor: SiriusColors.contrast,
                                    minimumSize: const Size(44, 40),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add, size: 20),
                                  ),
                                ),
                              )
                            : Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showAddEmployeeDialog(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SiriusColors.accent,
                                    foregroundColor: SiriusColors.contrast,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('add'),
                                  ),
                                ),
                              ),

                        const SizedBox(width: 12),
                        MediaQuery.of(context).size.width < 600
                            ? SizedBox(
                                width: 44,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: () => _fetchEmployees(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SiriusColors.surface,
                                    foregroundColor: SiriusColors.accent,
                                    minimumSize: const Size(44, 40),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.refresh, size: 20),
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () => _fetchEmployees(),
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('refresh'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SiriusColors.surface,
                                  foregroundColor: SiriusColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('search_employee_hint'),
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (q) {
                        setState(() {
                          _employeeSearchQuery = q.trim().toLowerCase();
                        });
                      },
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SiriusColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.people,
                      color: SiriusColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('employee_management'),
                          style: TextStyle(
                            color: SiriusColors.heading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('name_surname_and_actions'),
                          style: TextStyle(
                            color: SiriusColors.defaultText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEmployeeDialog(),
                    icon: const Icon(Icons.add),
                    label: MediaQuery.of(context).size.width < 600
                        ? const SizedBox.shrink()
                        : Text(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('new_employee'),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.accent,
                      foregroundColor: SiriusColors.contrast,
                      minimumSize: MediaQuery.of(context).size.width < 600
                          ? const Size(44, 40)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _fetchEmployees(),
                    icon: const Icon(Icons.refresh),
                    label: MediaQuery.of(context).size.width < 600
                        ? const SizedBox.shrink()
                        : Text(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('refresh'),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.surface,
                      foregroundColor: SiriusColors.accent,
                      minimumSize: MediaQuery.of(context).size.width < 600
                          ? const Size(44, 40)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingEmployees
              ? Center(
                  child: CircularProgressIndicator(color: SiriusColors.accent),
                )
              : _allEmployees.isEmpty
              ? const Center(
                  child: Text(
                    'Henüz çalışan bulunmamaktadır.',
                    style: TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: 16,
                    ),
                  ),
                )
              : Builder(
                  builder: (context) {
                    List<Employee> filtered = List.of(_allEmployees);
                    if (_employeeSearchQuery.isNotEmpty) {
                      filtered = filtered.where((e) {
                        final name = e.fullName.toLowerCase();
                        final exp = (e.expertise).toLowerCase();
                        return name.contains(_employeeSearchQuery) ||
                            exp.contains(_employeeSearchQuery);
                      }).toList();
                    }
                    if (_employeeOnlyActive) {
                      filtered = filtered
                          .where((e) => e.isActive == true)
                          .toList();
                    }
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'Filtrenize uygun çalışan bulunamadı.',
                          style: TextStyle(
                            color: SiriusColors.defaultText,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      primary: false,
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final employee = filtered[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: _isDarkMode
                              ? SiriusColors.surface
                              : Colors.black.withValues(
                                  alpha: 0.3,
                                ), // Açık modda transparan siyah
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: SiriusColors.accent,
                              child: Text(
                                employee.firstName[0],
                                style: const TextStyle(
                                  color: SiriusColors.contrast,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              employee.fullName,
                              style: const TextStyle(
                                color: SiriusColors.heading,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${Provider.of<LanguageProvider>(context, listen: false).t('expertise')}: ${employee.expertise}',
                                  style: const TextStyle(
                                    color: SiriusColors.defaultText,
                                  ),
                                ),
                                Text(
                                  '${Provider.of<LanguageProvider>(context, listen: false).t('skills')}: ${employee.skills}',
                                  style: const TextStyle(
                                    color: SiriusColors.defaultText,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Düzenleme butonu
                                IconButton(
                                  onPressed: () =>
                                      _showEditEmployeeDialog(employee),
                                  icon: Icon(
                                    Icons.edit,
                                    color: SiriusColors.accent,
                                    size: 20,
                                  ),
                                  tooltip: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('edit'),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                                // Silme butonu
                                IconButton(
                                  onPressed: () =>
                                      _showDeleteEmployeeDialog(employee.id!),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  tooltip: lang.t('delete'),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: false,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceAnalysis() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          color: _isDarkMode
              ? Colors.black
              : Colors.black.withValues(alpha: 0.3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('employee_performance_analysis'),
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  color: SiriusColors.heading,
                                  fontSize:
                                      MediaQuery.of(context).size.width < 400
                                      ? 14
                                      : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${Provider.of<LanguageProvider>(context, listen: false).t('date')}: ${_formatDate(DateTime.now())}',
                                style: const TextStyle(
                                  color: SiriusColors.defaultText,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _fetchEmployeePerformance();
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: SiriusColors.accent,
                            size: 24,
                          ),
                          tooltip: Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('refresh_performance_data'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.t('employee_performance_analysis'),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: SiriusColors.heading,
                        fontSize: MediaQuery.of(context).size.width < 500
                            ? 16
                            : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Debug sayacı kaldırıldı
                  const SizedBox(width: 12),
                  Text(
                    '${lang.t('date')}: ${_formatDate(DateTime.now())}',
                    style: const TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      _fetchEmployeePerformance();
                    },
                    icon: Icon(
                      Icons.refresh,
                      color: SiriusColors.accent,
                      size: 20,
                    ),
                    tooltip: lang.t('refresh_performance_data'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _fetchEmployees();
                    },
                    icon: Icon(Icons.people, color: Colors.blue, size: 20),
                    tooltip: lang.t('refresh_employees'),
                  ),
                ],
              );
            },
          ),
        ),
        // Performans özeti kartları (responsive)
        Container(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 700;
              if (isNarrow) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildSummaryCard(
                          lang.t('total_employees'),
                          _allEmployees.length.toString(),
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildSummaryCard(
                          lang.t('total_earnings'),
                          '₺${_calculateTotalEarnings().toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildSummaryCard(
                          lang.t('average_efficiency'),
                          '${_calculateAverageEfficiency().toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      lang.t('total_employees'),
                      _allEmployees.length.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      lang.t('total_earnings'),
                      '₺${_calculateTotalEarnings().toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      lang.t('average_efficiency'),
                      '${_calculateAverageEfficiency().toStringAsFixed(1)}%',
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: _isLoadingPerformance
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: SiriusColors.accent),
                      const SizedBox(height: 16),
                      Text(
                        lang.t('performance_data_loading'),
                        style: TextStyle(
                          color: SiriusColors.defaultText,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _employeePerformance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: SiriusColors.defaultText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        lang.t('no_performance_data'),
                        style: TextStyle(
                          color: SiriusColors.defaultText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${lang.t('employees')}: ${_allEmployees.length}',
                        style: TextStyle(
                          color: SiriusColors.defaultText.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'İşletme ID: ${_isletmeId ?? 'Bulunamadı'}',
                        style: TextStyle(
                          color: SiriusColors.defaultText.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _fetchEmployeePerformance();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SiriusColors.accent,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(lang.t('refresh')),
                          ),
                          const SizedBox(width: 12),
                          if (_isDebugMode)
                            OutlinedButton(
                              onPressed: () {
                                _createTestPerformanceData();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.orange),
                                foregroundColor: Colors.orange,
                              ),
                              child: const Text('Test Verisi'),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  primary: false,
                  shrinkWrap: true,
                  itemCount: _employeePerformance.length,
                  itemBuilder: (context, index) {
                    final performance = _employeePerformance[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    performance.employeeName,
                                    style: const TextStyle(
                                      color: SiriusColors.heading,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SiriusColors.accent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '₺${performance.dailyEarnings.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: SiriusColors.contrast,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    lang.t('efficiency'),
                                    '${performance.efficiency.toStringAsFixed(1)}%',
                                    Icons.trending_up,
                                    _getEfficiencyColor(performance.efficiency),
                                  ),
                                ),
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    (() {
                                      final t = lang.t('rating');
                                      return t == 'rating' ? 'Rating' : t;
                                    })(),
                                    '${performance.averageRating.toStringAsFixed(1)} ★',
                                    Icons.star,
                                    Colors.amber,
                                  ),
                                ),
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    lang.t('confirmed'),
                                    performance.appointmentsCompleted
                                        .toString(),
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                ),
                                Expanded(
                                  child: _buildPerformanceMetric(
                                    lang.t('pending'),
                                    performance.pendingAppointments.toString(),
                                    Icons.timelapse,
                                    Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Detaylı performans bilgileri
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isDarkMode
                                    ? SiriusColors.background
                                    : Colors.black.withValues(
                                        alpha: 0.2,
                                      ), // Açık modda daha açık transparan siyah
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDetailMetric(
                                          lang.t('hourly_earnings'),
                                          '₺${(performance.dailyEarnings / 8).toStringAsFixed(2)}',
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDetailMetric(
                                          lang.t('per_appointment'),
                                          '₺${performance.appointmentsCompleted > 0 ? (performance.dailyEarnings / performance.appointmentsCompleted).toStringAsFixed(2) : '0.00'}',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: performance.efficiency / 100,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getEfficiencyColor(
                                        performance.efficiency,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${lang.t('efficiency')}: ${performance.efficiency.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: SiriusColors.defaultText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetric(
    String label,
    String value,
    IconData icon,
    Color? color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color ?? SiriusColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: SiriusColors.heading,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: SiriusColors.defaultText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SiriusColors.heading,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: SiriusColors.defaultText, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: SiriusColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 100;
            final double iconSize = isNarrow ? 24 : 28;
            final double valueSize = isNarrow ? 16 : 18;
            final double titleSize = isNarrow ? 10 : 11;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: iconSize),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: SiriusColors.heading,
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SiriusColors.defaultText,
                    fontSize: titleSize,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode
            ? Colors.grey[900]!.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık ve kapatma butonu
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('new_employee'),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.red[600], size: 24),
                    ),
                  ],
                ),
              ),
              // İçerik
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: (() async {
                      try {
                        await _ensureIsletmeId();
                        if (_isletmeId == null) return <Map<String, dynamic>>[];
                        final client = Supabase.instance.client;
                        final rows = await client
                            .from('menu_hizmet_icerigi')
                            .select('kategori, hizmet, aktif')
                            .eq('isletme_id', _isletmeId!)
                            .eq('aktif', true)
                            .order('kategori', ascending: true)
                            .order('hizmet', ascending: true);
                        return (rows as List).cast<Map<String, dynamic>>();
                      } catch (_) {
                        return <Map<String, dynamic>>[];
                      }
                    })(),
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? [];
                      final Map<String, List<String>> categoryToServices = {};
                      for (final m in data) {
                        final cat = (m['kategori'] ?? 'Genel').toString();
                        final svc = (m['hizmet'] ?? '').toString();
                        if (svc.isEmpty) continue;
                        categoryToServices.putIfAbsent(cat, () => []);
                        if (!categoryToServices[cat]!.contains(svc)) {
                          categoryToServices[cat]!.add(svc);
                        }
                      }

                      final categories = categoryToServices.keys.toList()
                        ..sort();
                      String? localSelectedCategory = categories.isNotEmpty
                          ? categories.first
                          : null;
                      String? localSelectedService =
                          (localSelectedCategory != null &&
                              categoryToServices[localSelectedCategory]!
                                  .isNotEmpty)
                          ? categoryToServices[localSelectedCategory]!.first
                          : null;

                      return StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Üst başlık şeridi
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.blueGrey[800]!
                                      : Colors.blue[50]!,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _isDarkMode
                                        ? Colors.blueGrey[600]!
                                        : Colors.blue[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('enter_new_employee_info'),
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.blue[800]!,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextField(
                                controller: _firstNameController,
                                decoration: InputDecoration(
                                  labelText:
                                      '${Provider.of<LanguageProvider>(context, listen: false).t('first_name')} *',
                                  hintText: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('employee_name_hint'),
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _lastNameController,
                                decoration: InputDecoration(
                                  labelText:
                                      '${Provider.of<LanguageProvider>(context, listen: false).t('last_name')} *',
                                  hintText: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('employee_surname_hint'),
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText:
                                      '${Provider.of<LanguageProvider>(context, listen: false).t('email')} *',
                                  hintText: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('email_hint'),
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText:
                                      '${Provider.of<LanguageProvider>(context, listen: false).t('phone')} *',
                                  hintText: '+90 5XX XXX XX XX',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  hintStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Beceriler alanı hizmet seçiminden sonra gösterilecek
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting)
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: LinearProgressIndicator(),
                                )
                              else if (categoryToServices.isNotEmpty) ...[
                                DropdownButtonFormField<String>(
                                  initialValue: localSelectedCategory,
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  dropdownColor: _isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${Provider.of<LanguageProvider>(context, listen: false).t('category')} *',
                                    hintText: Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('select_category'),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              c,
                                              style: TextStyle(
                                                color: _isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      localSelectedCategory = value;
                                      final services = value != null
                                          ? categoryToServices[value] ?? []
                                          : <String>[];
                                      localSelectedService = services.isNotEmpty
                                          ? services.first
                                          : null;
                                      _selectedService =
                                          localSelectedService; // store chosen service
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: localSelectedService,
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  dropdownColor: _isDarkMode
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${Provider.of<LanguageProvider>(context, listen: false).t('service')} *',
                                    hintText: Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('select_service'),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items:
                                      (localSelectedCategory != null
                                              ? (categoryToServices[localSelectedCategory!] ??
                                                    [])
                                              : <String>[])
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                child: Text(
                                                  s,
                                                  style: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    setLocalState(() {
                                      localSelectedService = value;
                                      _selectedService = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _skillsController,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${Provider.of<LanguageProvider>(context, listen: false).t('skills')} *',
                                    hintText: Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('skills_hint'),
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    fillColor: _isDarkMode
                                        ? Colors.black26
                                        : Colors.white,
                                    prefixIcon: const Icon(Icons.handyman),
                                    labelStyle: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                    hintStyle: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Fotoğraf yükleme alanı
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _isDarkMode
                                          ? Colors.white30
                                          : Colors.grey,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      // Fotoğraf önizleme veya yükleme butonu
                                      Container(
                                        width: double.infinity,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: _isDarkMode
                                              ? Colors.grey[800]
                                              : Colors.grey[100],
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: _selectedPhotoUrl != null
                                            ? Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                8,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                    child: Image.network(
                                                      _selectedPhotoUrl!,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return const Center(
                                                              child: Icon(
                                                                Icons.person,
                                                                size: 50,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            );
                                                          },
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        setLocalState(() {
                                                          _selectedPhotoUrl =
                                                              null;
                                                        });
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        decoration:
                                                            const BoxDecoration(
                                                              color: Colors.red,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                        child: const Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.add_a_photo,
                                                      size: 40,
                                                      color: Colors.grey,
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      Provider.of<
                                                            LanguageProvider
                                                          >(
                                                            context,
                                                            listen: false,
                                                          )
                                                          .t('select_photo'),
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ),
                                      // Yükleme butonu
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        child: ElevatedButton.icon(
                                          onPressed: () => _uploadEmployeePhoto(
                                            setLocalState,
                                          ),
                                          icon: const Icon(
                                            Icons.upload,
                                            size: 18,
                                          ),
                                          label: Text(
                                            _selectedPhotoUrl != null
                                                ? Provider.of<LanguageProvider>(
                                                    context,
                                                    listen: false,
                                                  ).t('change_photo')
                                                : Provider.of<LanguageProvider>(
                                                    context,
                                                    listen: false,
                                                  ).t('upload_photo'),
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isDarkMode
                                                ? Colors.grey[700]
                                                : Colors.blue[50],
                                            foregroundColor: _isDarkMode
                                                ? Colors.white
                                                : Colors.blue[800],
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // Fallback: eski uzmanlık alanı seçimi
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedService,
                                  decoration: InputDecoration(
                                    labelText:
                                        '${Provider.of<LanguageProvider>(context, listen: false).t('expertise')} Alanı *',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'Genel',
                                      child: Text('Genel'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setLocalState(() {
                                      _selectedService = value;
                                    });
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // Alt butonlar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _addEmployee,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.green[600],
                        side: const BorderSide(color: Colors.green, width: 2),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('add'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Çalışan düzenleme dialog'u - Gelişmiş form
  void _showEditEmployeeDialog(Employee employee) async {
    // Supabase bağlantı kontrolü
    try {
      final client = Supabase.instance.client;
      await client.from('isletme').select('isletme_id').limit(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Supabase bağlantısı kurulamadı. Lütfen Supabase ayarlarını kontrol edin.\nHata: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    try {
      // Önce güncel çalışan verilerini Supabase'den yükle
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        throw Exception('İşletme ID bulunamadı');
      }

      if (employee.id == null) {
        throw Exception('Çalışan ID bulunamadı');
      }

      final client = Supabase.instance.client;
      final updatedEmployeeData = await client
          .from('calisanlar')
          .select()
          .eq('id', employee.id!)
          .eq('isletme_id', _isletmeId!)
          .single();

      // Güncel verileri controller'lara yükle
      _firstNameController.text = (updatedEmployeeData['ad'] ?? '').toString();
      _lastNameController.text = (updatedEmployeeData['soyad'] ?? '')
          .toString();
      _skillsController.text = (updatedEmployeeData['beceriler'] ?? '')
          .toString();
      _emailController.text = (updatedEmployeeData['email'] ?? '').toString();
      _phoneController.text = (updatedEmployeeData['phone'] ?? '').toString();
      _selectedPhotoUrl =
          (updatedEmployeeData['resim_url'] ??
                  updatedEmployeeData['profil_resmi'])
              as String?;

      // Hizmet değerini kontrol et ve geçerli bir değer ata
      final serviceValue = (updatedEmployeeData['hizmet'] ?? 'Genel')
          .toString();
      final validServices = [
        'Saç',
        'Makyaj',
        'Cilt Bakımı',
        'Manikür/Pedikür',
        'Masaj',
        'Lazer',
        'Beslenme Danışmanlığı',
        'Genel',
      ];
      _selectedService = validServices.contains(serviceValue)
          ? serviceValue
          : 'Genel';
    } catch (e) {
      // Hata durumunda mevcut veriyi kullan
      _firstNameController.text = employee.firstName;
      _lastNameController.text = employee.lastName;
      _skillsController.text = employee.skills;
      _emailController.text = employee.email ?? '';
      _phoneController.text = employee.phone ?? '';
      _selectedPhotoUrl = employee.profileImage;

      final validServices = [
        'Saç',
        'Makyaj',
        'Cilt Bakımı',
        'Manikür/Pedikür',
        'Masaj',
        'Lazer',
        'Beslenme Danışmanlığı',
        'Genel',
      ];
      _selectedService = validServices.contains(employee.expertise)
          ? employee.expertise
          : 'Genel';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çalışan verileri güncellenirken hata: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _isDarkMode
              ? Colors.grey[900]!.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width < 600
                ? double.infinity
                : 500,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık ve kapatma butonu
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.grey[800] : Colors.blue[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${Provider.of<LanguageProvider>(context, listen: false).t('edit')} ${Provider.of<LanguageProvider>(context, listen: false).t('employee')}',
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Colors.red[600],
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // İçerik
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Ad
                        TextField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText:
                                '${Provider.of<LanguageProvider>(context, listen: false).t('first_name')} *',
                            hintText: 'Çalışanın adı',
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                            hintStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Soyad
                        TextField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText:
                                '${Provider.of<LanguageProvider>(context, listen: false).t('last_name')} *',
                            hintText: 'Çalışanın soyadı',
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                            hintStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // E-posta
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('email'),
                            hintText: 'ornek@firma.com',
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                            hintStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Telefon
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('phone'),
                            hintText: '+90 5XX XXX XX XX',
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                            hintStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Uzmanlık alanı
                        DropdownButtonFormField<String>(
                          value: _selectedService,
                          decoration: InputDecoration(
                            labelText:
                                '${Provider.of<LanguageProvider>(context, listen: false).t('expertise')} *',
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                          dropdownColor: _isDarkMode
                              ? Colors.grey[850]
                              : Colors.white,
                          items: [
                            DropdownMenuItem(value: 'Saç', child: Text('Saç')),
                            DropdownMenuItem(
                              value: 'Makyaj',
                              child: Text('Makyaj'),
                            ),
                            DropdownMenuItem(
                              value: 'Cilt Bakımı',
                              child: Text('Cilt Bakımı'),
                            ),
                            DropdownMenuItem(
                              value: 'Manikür/Pedikür',
                              child: Text('Manikür/Pedikür'),
                            ),
                            DropdownMenuItem(
                              value: 'Masaj',
                              child: Text('Masaj'),
                            ),
                            DropdownMenuItem(
                              value: 'Lazer',
                              child: Text('Lazer'),
                            ),
                            DropdownMenuItem(
                              value: 'Beslenme Danışmanlığı',
                              child: Text('Beslenme Danışmanlığı'),
                            ),
                            DropdownMenuItem(
                              value: 'Genel',
                              child: Text('Genel'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedService = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Beceriler
                        TextField(
                          controller: _skillsController,
                          decoration: InputDecoration(
                            labelText:
                                '${Provider.of<LanguageProvider>(context, listen: false).t('skills')} *',
                            hintText: 'Örn: Boya, Kesim, Fön',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: _isDarkMode
                                ? Colors.black26
                                : Colors.white,
                            prefixIcon: const Icon(Icons.handyman),
                            labelStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                            hintStyle: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                          ),
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Fotoğraf yükleme alanı
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isDarkMode ? Colors.white30 : Colors.grey,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Fotoğraf önizleme veya yükleme butonu
                              Container(
                                width: double.infinity,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: _selectedPhotoUrl != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(8),
                                                  topRight: Radius.circular(8),
                                                ),
                                            child: Image.network(
                                              _selectedPhotoUrl!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Center(
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 50,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _selectedPhotoUrl = null;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_a_photo,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('select_photo'),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              // Yükleme butonu
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                child: ElevatedButton.icon(
                                  onPressed: () => _uploadEmployeePhoto(
                                    (fn) => setState(fn),
                                  ),
                                  icon: const Icon(Icons.upload, size: 18),
                                  label: Text(
                                    _selectedPhotoUrl != null
                                        ? Provider.of<LanguageProvider>(
                                            context,
                                            listen: false,
                                          ).t('change_photo')
                                        : Provider.of<LanguageProvider>(
                                            context,
                                            listen: false,
                                          ).t('upload_photo'),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isDarkMode
                                        ? Colors.grey[700]
                                        : Colors.blue[50],
                                    foregroundColor: _isDarkMode
                                        ? Colors.white
                                        : Colors.blue[800],
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Alt buton
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.grey[800] : Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          final updatedEmployee = Employee(
                            id: employee.id,
                            firstName: _firstNameController.text,
                            lastName: _lastNameController.text,
                            skills: _skillsController.text,
                            expertise: _selectedService ?? 'Genel',
                            phone: _phoneController.text.isEmpty
                                ? null
                                : _phoneController.text,
                            email: _emailController.text.isEmpty
                                ? null
                                : _emailController.text,
                            isActive: employee.isActive,
                            hireDate: employee.hireDate,
                            profileImage: _selectedPhotoUrl,
                          );
                          _updateEmployee(updatedEmployee);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.green[600],
                          side: const BorderSide(color: Colors.green, width: 2),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                        ),
                        child: Text(
                          Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('update'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Çalışan silme onay dialog'u
  void _showDeleteEmployeeDialog(int employeeId) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.t('delete_employee')),
        content: Text(lang.t('delete_employee_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              Provider.of<LanguageProvider>(context, listen: false).t('cancel'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEmployee(employeeId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(lang.t('delete')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Son 30 günün başlangıç ve bitiş zamanlarını al (sistem saati yanlış olabilir)
  (DateTime, DateTime) _todayRange() {
    final now = DateTime.now();

    // Son 30 günün başlangıcı ve sonu (sistem saati yanlış olsa bile veri bulabiliriz)
    final start = DateTime.utc(now.year, now.month, now.day - 30, 0, 0, 0);
    final end = DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999);

    return (start, end);
  }

  // Supabase'den günlük özet sayılarını çek
  Future<void> _fetchTodaySummary() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) {
        return;
      }

      final (start, end) = _todayRange();
      final client = Supabase.instance.client;

      // Toplam randevu sayısı
      final totalResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .gte('appointment_datetime', start.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());

      final int total = (totalResp as List).length;

      // Bekleyen randevu sayısı (Pending)
      final pendingResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .eq('approval_status', 'Pending')
          .gte('appointment_datetime', start.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());
      final int pending = (pendingResp as List).length;

      // Tamamlanan randevu sayısı (Approved)
      final completedResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .eq('approval_status', 'Approved')
          .gte('appointment_datetime', start.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());
      final int completed = (completedResp as List).length;

      // Test için son 7 günün toplam randevu sayısını da göster
      final lastWeekStart = DateTime.utc(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day - 7,
        0,
        0,
        0,
      );
      final lastWeekResp = await client
          .from('randevu')
          .select('randevu_id')
          .eq('isletme_id', _isletmeId!)
          .gte('appointment_datetime', lastWeekStart.toIso8601String())
          .lte('appointment_datetime', end.toIso8601String());

      // ignore: unused_local_variable
      final int lastWeekTotal = (lastWeekResp as List).length;

      if (!mounted) return;
      setState(() {
        _todayTotalAppointments = total;
        _todayPendingAppointments = pending;
        _todayCompletedAppointments = completed;
      });
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  Color _getEfficiencyColor(double efficiency) {
    if (efficiency >= 80) return Colors.green;
    if (efficiency >= 60) return Colors.orange;
    return Colors.red;
  }

  double _calculateTotalEarnings() {
    // Performans verilerinden toplam kazancı hesapla (tüm zamanlar için)
    double totalFromPerformance = _employeePerformance.fold(
      0.0,
      (sum, p) => sum + p.totalEarnings,
    );

    return totalFromPerformance;
  }

  double _calculateAverageEfficiency() {
    if (_employeePerformance.isEmpty) return 0.0;
    final average =
        _employeePerformance.fold(0.0, (sum, p) => sum + p.efficiency) /
        _employeePerformance.length;
    return average;
  }

  // Otomatik yenileme timer'ını başlat
  // ignore: unused_element
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _isAutoRefresh) {
        _fetchEmployeePerformance();
        _fetchTodaySummary();
      }
    });
  }

  // Otomatik yenileme timer'ını durdur
  // ignore: unused_element
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
  }

  // Test performans verisi oluştur
  void _createTestPerformanceData() {
    if (_allEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce çalışanları yükleyin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final testPerformances = _allEmployees.map((employee) {
      final random = employee.id ?? 1;
      return EmployeePerformance(
        employeeName: employee.fullName,
        dailyEarnings: (random * 100.0) + (random * 50.0),
        totalEarnings: (random * 500.0) + (random * 250.0),
        efficiency: (random * 10.0) % 100.0,
        date: DateTime.now(),
        appointmentsCompleted: (random % 10) + 1,
        averageRating: (random % 5) + 1.0,
      );
    }).toList();

    setState(() {
      _employeePerformance = testPerformances;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${testPerformances.length} test performans verisi oluşturuldu',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Home ekranı - Eski _buildWelcomeScreen ile aynı tasarım
  Widget _buildHomeScreen() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 16 : 24,
      ),
      child: Column(
        children: [
          // Ana hoşgeldiniz kartı - İnce tasarım
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      // Kart yüksekliğini hafifçe azalt
                      minHeight: MediaQuery.of(context).size.width < 600
                          ? 140
                          : 160,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(context).size.width < 600 ? 8 : 12,
                      MediaQuery.of(context).size.width < 600 ? 2 : 4,
                      MediaQuery.of(context).size.width < 600 ? 8 : 12,
                      MediaQuery.of(context).size.width < 600 ? 10 : 14,
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
                          color: SiriusColors.accent.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Üst satır: Ayarlar ve Çıkış ikonları
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _showSettingsDialog(),
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Ayarlar',
                            ),
                            // Sağdaki sadece çıkış kalsın; yenileme ikonu kullanılmıyor
                            IconButton(
                              onPressed: () => _showLogoutDialog(),
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('logout'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Hoş geldiniz yazısı
                        Center(
                          child: Text(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('welcome'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              fontFamily: 'Cormorant',
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Alt satır: Yuvarlak ikon ve yazılar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Sol: Yuvarlak profil ikonu
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: SiriusColors.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Sağ: Yazılar
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_isletme != null &&
                                              (_isletme!['isim'] as String?) !=
                                                  null)
                                          ? ((_isletme!['isim'] as String?) ??
                                                '')
                                          : 'İşletme Adı',
                                      style: TextStyle(
                                        color: SiriusColors.contrast.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Provider.of<LanguageProvider>(
                                        context,
                                        listen: false,
                                      ).t('admin_panel'),
                                      style: TextStyle(
                                        color: SiriusColors.contrast.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
          const SizedBox(height: 16),

          // Hızlı erişim kartları - Sırayla görünme
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                final double itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      height:
                          190, // Overflow'u önlemek için mobil kart yüksekliği artırıldı
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(-30 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildQuickAccessCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('employee_management'),
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('manage_appointments_and_employees'),
                                Icons.work,
                                () => setState(() => _selectedIndex = 0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      height:
                          190, // Overflow'u önlemek için mobil kart yüksekliği artırıldı
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(30 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildQuickAccessCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('employee_performance_analysis'),
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('track_and_analyze_performance'),
                                Icons.analytics,
                                () => setState(() => _selectedIndex = 1),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(-50 * (1 - value), 0),
                          child: Opacity(
                            opacity: value,
                            child: _buildQuickAccessCard(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('employee_management'),
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('manage_appointments_and_employees'),
                              Icons.work,
                              () => setState(() => _selectedIndex = 0),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(50 * (1 - value), 0),
                          child: Opacity(
                            opacity: value,
                            child: _buildQuickAccessCard(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('employee_performance_analysis'),
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('track_and_analyze_performance'),
                              Icons.analytics,
                              () => setState(() => _selectedIndex = 1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // İstatistik kartları - Yukarıdan aşağıya görünme
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1400),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).isEnglish
                              ? 'Appointment Status'
                              : 'Randevu Durumu',
                          style: TextStyle(
                            color: SiriusColors.heading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).isEnglish
                                    ? 'Total Appointments'
                                    : 'Toplam Randevu',
                                _todayTotalAppointments.toString(),
                                Icons.calendar_today,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('pending'),
                                _todayPendingAppointments.toString(),
                                Icons.pending,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('confirmed'),
                                _todayCompletedAppointments.toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Son aktiviteler - En son görünme
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Responsive: allow header text to wrap on small widths
                            Flexible(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool isNarrow =
                                      constraints.maxWidth < 340;
                                  final double titleSize = isNarrow ? 18 : 20;
                                  return Text(
                                    Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).isEnglish
                                        ? 'Recent Activities'
                                        : 'Son Aktiviteler',
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: SiriusColors.heading,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.green[600],
                                    size: 22,
                                  ),
                                  tooltip: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('refresh'),
                                ),
                                IconButton(
                                  onPressed: () => _showClearActivitiesDialog(),
                                  icon: Icon(
                                    Icons.delete_sweep,
                                    color: Colors.red[600],
                                    size: 24,
                                  ),
                                  tooltip: lang.t('delete_past_activities'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadRecentActivities(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Aktiviteler yüklenemedi',
                                style: TextStyle(color: Colors.red[300]),
                              );
                            }
                            final items = snapshot.data ?? [];
                            if (items.isEmpty) {
                              return Text(
                                'Son aktivite bulunamadı',
                                style: TextStyle(
                                  color: SiriusColors.defaultText,
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (int i = 0; i < items.length; i++) ...[
                                  _buildActivityItem(
                                    items[i]['title'] as String,
                                    items[i]['time'] as String,
                                    items[i]['icon'] as IconData,
                                    items[i]['color'] as Color,
                                  ),
                                  if (i < items.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Admin hoşgeldiniz ekranı
  Widget _buildWelcomeScreen() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 16 : 24,
      ),
      child: Column(
        children: [
          // Ana hoşgeldiniz kartı - İnce tasarım
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.width < 600
                          ? 140
                          : 160,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(context).size.width < 600 ? 8 : 12,
                      MediaQuery.of(context).size.width < 600 ? 2 : 4,
                      MediaQuery.of(context).size.width < 600 ? 8 : 12,
                      MediaQuery.of(context).size.width < 600 ? 12 : 16,
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
                          color: SiriusColors.accent.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Üst satır: Ayarlar ve Çıkış ikonları
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _showSettingsDialog(),
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Ayarlar',
                            ),
                            IconButton(
                              onPressed: () => _showLogoutDialog(),
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('logout'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Hoş geldiniz yazısı
                        Center(
                          child: Text(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('welcome'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              fontFamily: 'Cormorant',
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Alt satır: Yuvarlak ikon ve yazılar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Sol: Yuvarlak profil ikonu
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.admin_panel_settings,
                                  color: SiriusColors.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Sağ: Yazılar
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_isletme != null &&
                                              (_isletme!['isim'] as String?) !=
                                                  null)
                                          ? ((_isletme!['isim'] as String?) ??
                                                '')
                                          : 'İşletme Adı',
                                      style: TextStyle(
                                        color: SiriusColors.contrast.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Provider.of<LanguageProvider>(
                                        context,
                                        listen: false,
                                      ).t('admin_panel'),
                                      style: TextStyle(
                                        color: SiriusColors.contrast.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
          const SizedBox(height: 16),

          // Hızlı erişim kartları - Sırayla görünme
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                final double itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      height: 190,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(-30 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildQuickAccessCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('employee_management'),
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('manage_appointments_and_employees'),
                                Icons.work,
                                () => setState(() => _selectedIndex = 0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      height: 190,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1200),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(30 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _buildQuickAccessCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('employee_performance_analysis'),
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('track_and_analyze_performance'),
                                Icons.analytics,
                                () => setState(() => _selectedIndex = 1),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(-50 * (1 - value), 0),
                          child: Opacity(
                            opacity: value,
                            child: _buildQuickAccessCard(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('employee_management'),
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('manage_appointments_and_employees'),
                              Icons.work,
                              () => setState(() => _selectedIndex = 0),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(50 * (1 - value), 0),
                          child: Opacity(
                            opacity: value,
                            child: _buildQuickAccessCard(
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('employee_performance_analysis'),
                              Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).t('track_and_analyze_performance'),
                              Icons.analytics,
                              () => setState(() => _selectedIndex = 1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // İstatistik kartları - Yukarıdan aşağıya görünme
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1400),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Provider.of<LanguageProvider>(
                                context,
                                listen: false,
                              ).isEnglish
                              ? 'Appointment Status'
                              : 'Randevu Durumu',
                          style: TextStyle(
                            color: SiriusColors.heading,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).isEnglish
                                    ? 'Total Appointments'
                                    : 'Toplam Randevu',
                                _todayTotalAppointments.toString(),
                                Icons.calendar_today,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('pending'),
                                _todayPendingAppointments.toString(),
                                Icons.pending,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                Provider.of<LanguageProvider>(
                                  context,
                                  listen: false,
                                ).t('confirmed'),
                                _todayCompletedAppointments.toString(),
                                Icons.check_circle,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Son aktiviteler - En son görünme
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? SiriusColors.surface
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SiriusColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Responsive: allow header text to wrap on small widths
                            Flexible(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool isNarrow =
                                      constraints.maxWidth < 340;
                                  final double titleSize = isNarrow ? 18 : 20;
                                  return Text(
                                    Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).isEnglish
                                        ? 'Recent Activities'
                                        : 'Son Aktiviteler',
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: SiriusColors.heading,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.green[600],
                                    size: 22,
                                  ),
                                  tooltip: Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('refresh'),
                                ),
                                IconButton(
                                  onPressed: () => _showClearActivitiesDialog(),
                                  icon: Icon(
                                    Icons.delete_sweep,
                                    color: Colors.red[600],
                                    size: 24,
                                  ),
                                  tooltip: lang.t('delete_past_activities'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadRecentActivities(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Text(
                                'Aktiviteler yüklenemedi',
                                style: TextStyle(color: Colors.red[300]),
                              );
                            }
                            final items = snapshot.data ?? [];
                            if (items.isEmpty) {
                              return Text(
                                'Son aktivite bulunamadı',
                                style: TextStyle(
                                  color: SiriusColors.defaultText,
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (int i = 0; i < items.length; i++) ...[
                                  _buildActivityItem(
                                    items[i]['title'] as String,
                                    items[i]['time'] as String,
                                    items[i]['icon'] as IconData,
                                    items[i]['color'] as Color,
                                  ),
                                  if (i < items.length - 1)
                                    const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
      constraints: const BoxConstraints(minHeight: 190),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 240;
              final double titleSize = isNarrow ? 15.5 : 18;
              final double descSize = isNarrow ? 12 : 14;
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: SiriusColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: SiriusColors.accent, size: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SiriusColors.heading,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: SiriusColors.defaultText,
                        fontSize: descSize,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(minHeight: 132),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 120;
          final bool isMobile = MediaQuery.of(context).size.width < 600;
          final double valueSize = isNarrow ? 22 : 24;
          final double titleSize = isNarrow ? 11 : 12;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SiriusColors.heading,
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Hide title on mobile for cleaner look
              if (!isMobile) ...[
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SiriusColors.defaultText,
                    fontSize: titleSize,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive: shrink text on very narrow screens and allow wrapping
              final bool isVeryNarrow = constraints.maxWidth < 300;
              final double titleSize = isVeryNarrow ? 13 : 14;
              final double timeSize = isVeryNarrow ? 11 : 12;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: SiriusColors.heading,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      color: SiriusColors.defaultText,
                      fontSize: timeSize,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivities() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return [];
      final client = Supabase.instance.client;
      // Son 15 randevuyu (en güncel) çek
      final resp = await client
          .from('randevu')
          .select(
            'appointment_datetime, approval_status, customerid, calisan_id, musteriler:customerid(firstname, lastname)',
          )
          .eq('isletme_id', _isletmeId!)
          .order('appointment_datetime', ascending: false)
          .limit(15);

      final List<Map<String, dynamic>> activities = [];
      for (final row in (resp as List)) {
        final m = row as Map<String, dynamic>;
        final DateTime dt =
            DateTime.tryParse(
              m['appointment_datetime']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();
        final String status = (m['approval_status'] ?? '').toString();
        String? fullName;
        final cust = m['musteriler'] as Map<String, dynamic>?;
        if (cust != null) {
          final first = (cust['firstname'] ?? '').toString();
          final last = (cust['lastname'] ?? '').toString();
          fullName = [first, last].where((p) => p.trim().isNotEmpty).join(' ');
        }
        final String title = _activityTitleFromStatus(status, fullName);
        final IconData icon = _activityIconFromStatus(status);
        final Color color = _activityColorFromStatus(status);
        activities.add({
          'title': title,
          'time': _relativeTime(dt),
          'icon': icon,
          'color': color,
          'ts': dt,
        });
      }

      // Çalışan aktiviteleri: eklenenler (created_at) ve güncellemeler (updated_at)
      final recentCreated = await client
          .from('calisanlar')
          .select('ad, soyad, created_at, aktif')
          .eq('isletme_id', _isletmeId!)
          .order('created_at', ascending: false)
          .limit(10);

      final recentUpdated = await client
          .from('calisanlar')
          .select('ad, soyad, updated_at, aktif')
          .eq('isletme_id', _isletmeId!)
          .order('updated_at', ascending: false)
          .limit(20);

      for (final row in (recentCreated as List)) {
        final m = row as Map<String, dynamic>;
        final String name =
            '${(m['ad'] ?? '').toString()} ${(m['soyad'] ?? '').toString()}'
                .trim();
        final DateTime dt =
            DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
        activities.add({
          'title': name.isNotEmpty
              ? 'Çalışan eklendi: $name'
              : 'Çalışan eklendi',
          'time': _relativeTime(dt),
          'icon': Icons.person_add,
          'color': Colors.blue,
          'ts': dt,
        });
      }

      for (final row in (recentUpdated as List)) {
        final m = row as Map<String, dynamic>;
        if (m['updated_at'] == null) continue;
        final String name =
            '${(m['ad'] ?? '').toString()} ${(m['soyad'] ?? '').toString()}'
                .trim();
        final DateTime dt =
            DateTime.tryParse(m['updated_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
        final bool aktif = (m['aktif'] as bool?) ?? true;
        final bool isDeactivated = !aktif;
        activities.add({
          'title': name.isNotEmpty
              ? (isDeactivated
                    ? 'Çalışan silindi: $name'
                    : 'Profil bilgileri güncellendi: $name')
              : (isDeactivated
                    ? 'Çalışan silindi'
                    : 'Profil bilgileri güncellendi'),
          'time': _relativeTime(dt),
          'icon': isDeactivated ? Icons.person_remove : Icons.edit,
          'color': isDeactivated ? Colors.red : Colors.orange,
          'ts': dt,
        });
      }

      // En yeni ilk 15 kaydı tarihe göre sırala ve dön
      activities.sort(
        (a, b) => (b['ts'] as DateTime).compareTo(a['ts'] as DateTime),
      );
      final top = activities
          .take(15)
          .map(
            (e) => {
              'title': e['title'],
              'time': e['time'],
              'icon': e['icon'],
              'color': e['color'],
            },
          )
          .toList();
      return top;
    } catch (_) {
      return [];
    }
  }

  // Geçmiş aktiviteleri temizleme fonksiyonu (sadece gösterimi temizler, veri silmez)
  Future<void> _clearPastActivities() async {
    try {
      // Sadece UI'yi temizle - gerçek verileri silme
      if (mounted) {
        setState(() {
          // Aktivite listesini temizle (sadece görsel olarak)
          // Gerçek veriler veritabanında kalır
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aktivite geçmişi temizlendi (veriler korundu)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _activityTitleFromStatus(String status, dynamic customerName) {
    final name = (customerName?.toString() ?? '').trim();
    switch (status.toLowerCase()) {
      case 'approved':
      case 'tamamlandı':
      case 'onaylandı':
      case 'completed':
        return name.isNotEmpty
            ? 'Randevu tamamlandı: $name'
            : 'Randevu tamamlandı';
      case 'pending':
        return name.isNotEmpty
            ? 'Yeni randevu beklemede: $name'
            : 'Yeni randevu beklemede';
      case 'canceled':
      case 'iptal':
      case 'iptal edildi':
        return name.isNotEmpty
            ? 'Randevu iptal edildi: $name'
            : 'Randevu iptal edildi';
      default:
        return name.isNotEmpty
            ? 'Randevu güncellendi: $name'
            : 'Randevu güncellendi';
    }
  }

  IconData _activityIconFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'tamamlandı':
      case 'onaylandı':
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'canceled':
      case 'iptal':
      case 'iptal edildi':
        return Icons.cancel;
      default:
        return Icons.update;
    }
  }

  Color _activityColorFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'tamamlandı':
      case 'onaylandı':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'canceled':
      case 'iptal':
      case 'iptal edildi':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _relativeTime(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds} saniye önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 30) return '${diff.inDays} gün önce';
    final int months = (diff.inDays / 30).floor();
    if (months < 12) return '$months ay önce';
    final int years = (months / 12).floor();
    return '$years yıl önce';
  }

  // Randevuları filtrele
  List<Appointment> _getFilteredAppointments(List<Appointment> appointments) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_appointmentFilterStatus) {
      case 'Today':
        return appointments.where((appointment) {
          final appointmentDate = DateTime(
            appointment.appointmentDateTime.year,
            appointment.appointmentDateTime.month,
            appointment.appointmentDateTime.day,
          );
          return appointmentDate.isAtSameMomentAs(today);
        }).toList();
      case 'Pending':
        return appointments.where((appointment) {
          return appointment.approvalStatus.toLowerCase() == 'pending' ||
              appointment.approvalStatus.toLowerCase() == 'bekliyor';
        }).toList();
      case 'Approved':
        return appointments.where((appointment) {
          return appointment.approvalStatus.toLowerCase() == 'approved' ||
              appointment.approvalStatus.toLowerCase() == 'onaylandı' ||
              appointment.approvalStatus.toLowerCase() == 'completed' ||
              appointment.approvalStatus.toLowerCase() == 'tamamlandı';
        }).toList();
      case 'Cancelled':
        return appointments.where((appointment) {
          return appointment.approvalStatus.toLowerCase() == 'cancelled' ||
              appointment.approvalStatus.toLowerCase() == 'canceled' ||
              appointment.approvalStatus.toLowerCase() == 'iptal' ||
              appointment.approvalStatus.toLowerCase() == 'denied';
        }).toList();
      default:
        return appointments;
    }
  }

  // Ayarlar dialog'u (profile_screen ile aynı tasarım)
  void _showSettingsDialog() {
    if (!mounted) return;

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
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 600 ? 8 : 24,
                vertical: 16,
              ),
              backgroundColor: themeProvider.isDarkMode
                  ? const Color(0xFF181818).withValues(alpha: 0.95)
                  : const Color(0xFFEDECE8).withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.black87,
                        size: 24,
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
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cormorant',
                        ),
                      ),
                    ],
                  ),
                  Row(
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
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    Provider.of<LanguageProvider>(
                                      context,
                                      listen: false,
                                    ).t('dark_mode'),
                                    style: TextStyle(
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 16,
                                      fontFamily: 'Cormorant',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (value) {
                                    themeProvider.setTheme(value);
                                    setState(() {
                                      _isDarkMode = value;
                                    });
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
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 16,
                                      fontFamily: 'Cormorant',
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                            fontFamily: 'Cormorant',
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
                                            fontFamily: 'Cormorant',
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
              actions: const [],
            );
          },
        );
      },
    );
  }

  // Profil bilgi satırı oluşturucu
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
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Çıkış yap dialog'u
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
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
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

  // Admin profil bilgileri dialog'u
  void _showAdminProfileDialog() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          _dialogSetState = dialogSetState;
          return Dialog(
            backgroundColor: _isDarkMode
                ? Colors.black.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width < 600
                  ? MediaQuery.of(context).size.width * 0.95
                  : 600,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
                maxWidth: MediaQuery.of(context).size.width * 0.95,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık - Gradient arka plan ile
                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 20 : 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isDarkMode
                            ? [Colors.blueGrey[800]!, Colors.blueGrey[700]!]
                            : [Colors.blue[400]!, Colors.blue[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            MediaQuery.of(context).size.width < 600 ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: MediaQuery.of(context).size.width < 600
                                ? 20
                                : 28,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width < 600
                              ? 16
                              : 20,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isNarrow = constraints.maxWidth < 200;
                              final double titleSize = isNarrow
                                  ? 16
                                  : (MediaQuery.of(context).size.width < 600
                                        ? 18
                                        : 24);
                              final double subtitleSize = isNarrow
                                  ? 10
                                  : (MediaQuery.of(context).size.width < 600
                                        ? 11
                                        : 14);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.t('profile_info'),
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: titleSize,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lang.t('account_and_business_info'),
                                    maxLines: 3,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: subtitleSize,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Yenile ikonu kaldırıldı
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: Colors.red,
                                size: MediaQuery.of(context).size.width < 600
                                    ? 20
                                    : 24,
                              ),
                              tooltip: lang.t('close'),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // İçerik
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 16 : 20,
                      ),
                      child: currentUser != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hesap Bilgileri Kategorisi (collapsible)
                                _buildCollapsibleHeader(
                                  title: lang.t('account_info'),
                                  icon: Icons.account_circle,
                                  keyName: 'account',
                                ),
                                if (_expanded['account'] == true)
                                  _buildEditableProfileInfoRow(
                                    lang.t('email'),
                                    currentUser.email ?? 'N/A',
                                    'email',
                                    currentUser.email ?? '',
                                  ),
                                if (_expanded['account'] == true)
                                  _buildPasswordChangeRow(),

                                // Kullanıcı ID ve İşletme ID alanları kaldırıldı
                                if (_isletme != null) ...[
                                  const SizedBox(height: 16),
                                  // İşletme Bilgileri Kategorisi (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('business_info'),
                                    icon: Icons.business,
                                    keyName: 'business',
                                  ),
                                  if (_expanded['business'] == true) ...[
                                    _buildEditableProfileInfoRow(
                                      lang.t('business_name'),
                                      _isletme!['isim'] ?? 'N/A',
                                      'isletme_isim',
                                      _isletme!['isim'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('business_type'),
                                      _isletme!['tip'] ?? 'N/A',
                                      'isletme_tip',
                                      _isletme!['tip'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('description'),
                                      _isletme!['aciklama'] ?? 'N/A',
                                      'isletme_aciklama',
                                      _isletme!['aciklama'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('profile_hero_tagline'),
                                      _isletme!['hero_tagline'] ?? 'N/A',
                                      'isletme_hero_tagline',
                                      _isletme!['hero_tagline'] ?? '',
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                  // İletişim Bilgileri Kategorisi (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('contact_info'),
                                    icon: Icons.contact_phone,
                                    keyName: 'contact',
                                  ),
                                  if (_expanded['contact'] == true) ...[
                                    _buildEditableProfileInfoRow(
                                      lang.t('phone'),
                                      _isletme!['telefon'] ?? 'N/A',
                                      'isletme_telefon',
                                      _isletme!['telefon'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('email'),
                                      _isletme!['email'] ?? 'N/A',
                                      'isletme_email',
                                      _isletme!['email'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('website'),
                                      _isletme!['web_site'] ?? 'N/A',
                                      'isletme_web_site',
                                      _isletme!['web_site'] ?? '',
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                  // Adres Bilgileri Kategorisi (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('address_details'),
                                    icon: Icons.location_on,
                                    keyName: 'address',
                                  ),
                                  if (_expanded['address'] == true) ...[
                                    _buildEditableProfileInfoRow(
                                      lang.t('address'),
                                      _isletme!['adres'] ?? 'N/A',
                                      'isletme_adres',
                                      _isletme!['adres'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('city'),
                                      _isletme!['sehir'] ?? 'N/A',
                                      'isletme_sehir',
                                      _isletme!['sehir'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('district'),
                                      _isletme!['ilce'] ?? 'N/A',
                                      'isletme_ilce',
                                      _isletme!['ilce'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('postal_code'),
                                      _isletme!['posta_kodu'] ?? 'N/A',
                                      'isletme_posta_kodu',
                                      _isletme!['posta_kodu'] ?? '',
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                  // Visual & Theme Category (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('visual_and_theme'),
                                    icon: Icons.palette,
                                    keyName: 'visual',
                                  ),
                                  if (_expanded['visual'] == true) ...[
                                    // Logo (tek görsel yöneticisi)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: lang.t('logo_url'),
                                        icon: Icons.image_outlined,
                                        keyName: 'logo',
                                      ),
                                    ),
                                    if (_expanded['logo'] == true)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[200]!,
                                            ),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 56,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SizedBox(
                                                    width: 96,
                                                    height: 96,
                                                    child: Stack(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child:
                                                              ((_isletme !=
                                                                      null) &&
                                                                  ((_isletme!['logo_url']
                                                                              as String?)
                                                                          ?.isNotEmpty ==
                                                                      true))
                                                              ? Image.network(
                                                                  (((_isletme!['logo_url']
                                                                                  as String)
                                                                              .startsWith(
                                                                                'http',
                                                                              )) ||
                                                                          ((_isletme!['logo_url']
                                                                                  as String)
                                                                              .startsWith(
                                                                                'https',
                                                                              )))
                                                                      ? (_isletme!['logo_url']
                                                                            as String)
                                                                      : DbService.getPublicImageUrl(
                                                                          _isletme!['logo_url']
                                                                              as String,
                                                                        ),
                                                                  width: 96,
                                                                  height: 96,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                )
                                                              : Container(
                                                                  width: 96,
                                                                  height: 96,
                                                                  color: Colors
                                                                      .grey
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      ),
                                                                ),
                                                        ),
                                                        Positioned(
                                                          right: 4,
                                                          top: 4,
                                                          child: InkWell(
                                                            onTap: () async {
                                                              await _deleteSingleImage(
                                                                fieldType:
                                                                    'isletme_logo_url',
                                                              );
                                                            },
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await _pickAndUploadSingle(
                                                    fieldType:
                                                        'isletme_logo_url',
                                                    fileName: 'logo.jpg',
                                                  );
                                                },
                                                icon: const Icon(Icons.upload),
                                                label: Text(
                                                  lang.t('upload_logo'),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  foregroundColor:
                                                      SiriusColors.accent,
                                                  side: BorderSide(
                                                    color: SiriusColors.accent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 12),
                                    // Menu / Services
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: 'Menu / Services',
                                        icon: Icons.content_cut,
                                        keyName: 'menu_services',
                                      ),
                                    ),
                                    if (_expanded['menu_services'] == true)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: _buildMenuServicesSection(),
                                      ),
                                    const SizedBox(height: 12),
                                    // Hero/Banner (single image manager)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: 'Hero Image',
                                        icon: Icons.landscape_outlined,
                                        keyName: 'hero',
                                      ),
                                    ),
                                    if (_expanded['hero'] == true)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[200]!,
                                            ),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 56,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SizedBox(
                                                    width: 160,
                                                    height: 96,
                                                    child: Stack(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child:
                                                              ((_isletme !=
                                                                      null) &&
                                                                  ((_isletme!['banner_url']
                                                                              as String?)
                                                                          ?.isNotEmpty ==
                                                                      true))
                                                              ? Image.network(
                                                                  (((_isletme!['banner_url']
                                                                                  as String)
                                                                              .startsWith(
                                                                                'http',
                                                                              )) ||
                                                                          ((_isletme!['banner_url']
                                                                                  as String)
                                                                              .startsWith(
                                                                                'https',
                                                                              )))
                                                                      ? (_isletme!['banner_url']
                                                                            as String)
                                                                      : DbService.getPublicImageUrl(
                                                                          _isletme!['banner_url']
                                                                              as String,
                                                                        ),
                                                                  width: 160,
                                                                  height: 96,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                )
                                                              : Container(
                                                                  width: 160,
                                                                  height: 96,
                                                                  color: Colors
                                                                      .grey
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      ),
                                                                ),
                                                        ),
                                                        Positioned(
                                                          right: 4,
                                                          top: 4,
                                                          child: InkWell(
                                                            onTap: () async {
                                                              await _deleteSingleImage(
                                                                fieldType:
                                                                    'isletme_banner_url',
                                                              );
                                                            },
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await _pickAndUploadSingle(
                                                    fieldType:
                                                        'isletme_banner_url',
                                                    fileName: 'hero.jpg',
                                                  );
                                                },
                                                icon: const Icon(Icons.upload),
                                                label: Text(
                                                  Provider.of<LanguageProvider>(
                                                    context,
                                                    listen: false,
                                                  ).t('upload_hero_image'),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  foregroundColor:
                                                      SiriusColors.accent,
                                                  side: BorderSide(
                                                    color: SiriusColors.accent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // About Us tek görsel yöneticisi (arka_plan_url)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).t('about_us_image'),
                                        icon: Icons.image_rounded,
                                        keyName: 'about_image',
                                      ),
                                    ),
                                    if (_expanded['about_image'] == true)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[200]!,
                                            ),
                                          ),
                                          child: Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 56,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SizedBox(
                                                    width: 160,
                                                    height: 96,
                                                    child: Stack(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child:
                                                              ((_isletme !=
                                                                      null) &&
                                                                  ((_isletme!['arka_plan_url']
                                                                              as String?)
                                                                          ?.isNotEmpty ==
                                                                      true))
                                                              ? Image.network(
                                                                  (((_isletme!['arka_plan_url']
                                                                                  as String)
                                                                              .startsWith(
                                                                                'http',
                                                                              )) ||
                                                                          ((_isletme!['arka_plan_url']
                                                                                  as String)
                                                                              .startsWith(
                                                                                'https',
                                                                              )))
                                                                      ? (_isletme!['arka_plan_url']
                                                                            as String)
                                                                      : DbService.getPublicImageUrl(
                                                                          _isletme!['arka_plan_url']
                                                                              as String,
                                                                        ),
                                                                  width: 160,
                                                                  height: 96,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                )
                                                              : Container(
                                                                  width: 160,
                                                                  height: 96,
                                                                  color: Colors
                                                                      .grey
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      ),
                                                                ),
                                                        ),
                                                        Positioned(
                                                          right: 4,
                                                          top: 4,
                                                          child: InkWell(
                                                            onTap: () async {
                                                              await _deleteSingleImage(
                                                                fieldType:
                                                                    'isletme_arka_plan_url',
                                                              );
                                                            },
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              child: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await _pickAndUploadSingle(
                                                    fieldType:
                                                        'isletme_arka_plan_url',
                                                    fileName: 'about.jpg',
                                                  );
                                                },
                                                icon: const Icon(Icons.upload),
                                                label: Text(
                                                  Provider.of<LanguageProvider>(
                                                    context,
                                                    listen: false,
                                                  ).t('upload_about_image'),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  foregroundColor:
                                                      SiriusColors.accent,
                                                  side: BorderSide(
                                                    color: SiriusColors.accent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    // Why Choose Us metinleri
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).t('why_choose_us'),
                                        icon: Icons.recommend,
                                        keyName: 'why',
                                      ),
                                    ),
                                    if (_expanded['why'] == true) ...[
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Column(
                                          children: [
                                            _buildEditableProfileInfoRow(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('card_1_title'),
                                              _icerikBlok['why_1_title'] ?? '',
                                              'why_1_title',
                                              _icerikBlok['why_1_title'] ?? '',
                                            ),
                                            _buildEditableProfileInfoRow(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('card_1_desc'),
                                              _icerikBlok['why_1_desc'] ?? '',
                                              'why_1_desc',
                                              _icerikBlok['why_1_desc'] ?? '',
                                            ),
                                            _buildEditableProfileInfoRow(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('card_2_title'),
                                              _icerikBlok['why_2_title'] ?? '',
                                              'why_2_title',
                                              _icerikBlok['why_2_title'] ?? '',
                                            ),
                                            _buildEditableProfileInfoRow(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('card_2_desc'),
                                              _icerikBlok['why_2_desc'] ?? '',
                                              'why_2_desc',
                                              _icerikBlok['why_2_desc'] ?? '',
                                            ),
                                            _buildEditableProfileInfoRow(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('card_3_title'),
                                              _icerikBlok['why_3_title'] ?? '',
                                              'why_3_title',
                                              _icerikBlok['why_3_title'] ?? '',
                                            ),
                                            _buildEditableProfileInfoRow(
                                              Provider.of<LanguageProvider>(
                                                context,
                                                listen: false,
                                              ).t('card_3_desc'),
                                              _icerikBlok['why_3_desc'] ?? '',
                                              'why_3_desc',
                                              _icerikBlok['why_3_desc'] ?? '',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),
                                    // About Us metinleri
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: 'About Us',
                                        icon: Icons.info_outline,
                                        keyName: 'about',
                                      ),
                                    ),
                                    if (_expanded['about'] == true) ...[
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Column(
                                          children: [
                                            _buildEditableProfileInfoRow(
                                              'Paragraph 1',
                                              _isletme!['about_us_p1'] ?? '',
                                              'isletme_about_us_p1',
                                              _isletme!['about_us_p1'] ?? '',
                                            ),
                                            _buildEditableProfileInfoRow(
                                              'Paragraph 2',
                                              _isletme!['about_us_p2'] ?? '',
                                              'isletme_about_us_p2',
                                              _isletme!['about_us_p2'] ?? '',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).t('gallery'),
                                        icon: Icons.photo_library_outlined,
                                        keyName: 'gallery',
                                      ),
                                    ),
                                    if (_expanded['gallery'] == true)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.fromLTRB(
                                            0,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[200]!,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    alignment:
                                                        WrapAlignment.start,
                                                    runAlignment:
                                                        WrapAlignment.start,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .start,
                                                    children: _galeriItems.map((
                                                      e,
                                                    ) {
                                                      final String url =
                                                          (e['resim_url']
                                                              as String?) ??
                                                          '';
                                                      final double imageSize =
                                                          MediaQuery.of(
                                                                context,
                                                              ).size.width <
                                                              400
                                                          ? 72
                                                          : (MediaQuery.of(
                                                                      context,
                                                                    ).size.width <
                                                                    700
                                                                ? 84
                                                                : 96);
                                                      return Stack(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child:
                                                                url.isNotEmpty
                                                                ? Image.network(
                                                                    url.startsWith(
                                                                          'http',
                                                                        )
                                                                        ? url
                                                                        : DbService.getPublicImageUrl(
                                                                            url,
                                                                          ),
                                                                    width:
                                                                        imageSize,
                                                                    height:
                                                                        imageSize,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  )
                                                                : Container(
                                                                    width:
                                                                        imageSize,
                                                                    height:
                                                                        imageSize,
                                                                    color: Colors
                                                                        .grey
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        ),
                                                                  ),
                                                          ),
                                                          Positioned(
                                                            right: 4,
                                                            top: 4,
                                                            child: InkWell(
                                                              onTap: () =>
                                                                  _removeGalleryImage(
                                                                    e['id']
                                                                        as int,
                                                                  ),
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      4,
                                                                    ),
                                                                child: const Icon(
                                                                  Icons.close,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }).toList(),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: ElevatedButton.icon(
                                                      onPressed:
                                                          _addGalleryImage,
                                                      icon: const Icon(
                                                        Icons.upload,
                                                      ),
                                                      label: Text(
                                                        Provider.of<
                                                              LanguageProvider
                                                            >(
                                                              context,
                                                              listen: false,
                                                            )
                                                            .t(
                                                              'add_image_to_gallery',
                                                            ),
                                                      ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            foregroundColor:
                                                                SiriusColors
                                                                    .accent,
                                                            side: BorderSide(
                                                              color:
                                                                  SiriusColors
                                                                      .accent,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left:
                                            MediaQuery.of(context).size.width <
                                                600
                                            ? 12
                                            : 16,
                                      ),
                                      child: _buildCollapsibleHeader(
                                        title: 'Event Images',
                                        icon: Icons.event,
                                        keyName: 'events',
                                      ),
                                    ),
                                    if (_expanded['events'] == true)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width <
                                                  600
                                              ? 12
                                              : 16,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            MediaQuery.of(context).size.width <
                                                    600
                                                ? 12
                                                : 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: _isDarkMode
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[200]!,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    alignment:
                                                        WrapAlignment.start,
                                                    runAlignment:
                                                        WrapAlignment.start,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .start,
                                                    children: _eventItems.asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final int idx = entry.key;
                                                      final Map<String, dynamic>
                                                      e = entry.value;
                                                      final String url =
                                                          (e['image_url']
                                                              as String?) ??
                                                          (e['image_path']
                                                                  as String? ??
                                                              (e['resim_url']
                                                                      as String? ??
                                                                  ''));
                                                      final double imageSize =
                                                          MediaQuery.of(
                                                                context,
                                                              ).size.width <
                                                              400
                                                          ? 72
                                                          : (MediaQuery.of(
                                                                      context,
                                                                    ).size.width <
                                                                    700
                                                                ? 84
                                                                : 96);
                                                      return Stack(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child:
                                                                url.isNotEmpty
                                                                ? Image.network(
                                                                    url.startsWith(
                                                                          'http',
                                                                        )
                                                                        ? url
                                                                        : DbService.getPublicImageUrl(
                                                                            url,
                                                                          ),
                                                                    width:
                                                                        imageSize,
                                                                    height:
                                                                        imageSize,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                  )
                                                                : Container(
                                                                    width:
                                                                        imageSize,
                                                                    height:
                                                                        imageSize,
                                                                    color: Colors
                                                                        .grey
                                                                        .withValues(
                                                                          alpha:
                                                                              0.2,
                                                                        ),
                                                                  ),
                                                          ),
                                                          Positioned(
                                                            right: 4,
                                                            top: 4,
                                                            child: InkWell(
                                                              onTap: () =>
                                                                  _removeEventImage(
                                                                    idx,
                                                                  ),
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      4,
                                                                    ),
                                                                child: const Icon(
                                                                  Icons.close,
                                                                  color: Colors
                                                                      .white,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }).toList(),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: ElevatedButton.icon(
                                                      onPressed: _addEventImage,
                                                      icon: const Icon(
                                                        Icons.upload,
                                                      ),
                                                      label: Text(
                                                        Provider.of<
                                                              LanguageProvider
                                                            >(
                                                              context,
                                                              listen: false,
                                                            )
                                                            .t(
                                                              'add_event_image',
                                                            ),
                                                      ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            foregroundColor:
                                                                SiriusColors
                                                                    .accent,
                                                            side: BorderSide(
                                                              color:
                                                                  SiriusColors
                                                                      .accent,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                  // Tema rengi ve çalışma saatleri artık Business Information altında
                                  // Görüntüleme için birleşik satır (hizalama düzeltildi)
                                  const SizedBox.shrink(),
                                ],
                              ],
                            )
                          : Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: _isDarkMode
                                      ? Colors.red[300]
                                      : Colors.red[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Kullanıcı bilgileri yüklenemedi.',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Lütfen tekrar deneyin veya sayfayı yenileyin.',
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white54
                                        : Colors.black54,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Profil kategori başlığı widget'ı
  Widget _buildProfileCategoryHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 16,
        vertical: MediaQuery.of(context).size.width < 600 ? 8 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode
              ? [
                  Colors.blueGrey[700]!.withValues(alpha: 0.3),
                  Colors.blueGrey[600]!.withValues(alpha: 0.2),
                ]
              : [Colors.blue[100]!, Colors.blue[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.blueGrey[600]!.withValues(alpha: 0.5)
              : Colors.blue[200]!,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 280;
          final double iconSize = isNarrow ? 16 : 20;
          final double titleSize = isNarrow ? 14 : 16;
          return Row(
            children: [
              Container(
                padding: EdgeInsets.all(isNarrow ? 6 : 8),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.blue[600] : Colors.blue[500],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: iconSize),
              ),
              SizedBox(width: isNarrow ? 8 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.blue[800],
                    fontWeight: FontWeight.bold,
                    fontSize: titleSize,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Katlanabilir başlık (tıklandıkça içerik aç/kapa)
  Widget _buildCollapsibleHeader({
    required String title,
    required IconData icon,
    required String keyName,
  }) {
    final bool isOpen = _expanded[keyName] == true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final toggler = _dialogSetState ?? setState;
          toggler(() {
            _expanded[keyName] = !(_expanded[keyName] ?? false);
          });
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 16,
            vertical: MediaQuery.of(context).size.width < 600 ? 8 : 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isDarkMode
                  ? [
                      Colors.blueGrey[700]!.withValues(alpha: 0.3),
                      Colors.blueGrey[600]!.withValues(alpha: 0.2),
                    ]
                  : [Colors.blue[100]!, Colors.blue[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDarkMode
                  ? Colors.blueGrey[600]!.withValues(alpha: 0.5)
                  : Colors.blue[200]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.blue[600] : Colors.blue[500],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: MediaQuery.of(context).size.width < 280 ? 16 : 20,
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.blue[800],
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width < 280 ? 14 : 16,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: AnimatedRotation(
                    turns: isOpen ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
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

  // Profil düzenleme dialog'u
  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.blue[700]
                            : Colors.blue[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    ),
                    Expanded(
                      child: Text(
                        '${Provider.of<LanguageProvider>(context, listen: false).t('edit')} '
                        '${Provider.of<LanguageProvider>(context, listen: false).t('profile_title')}',
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 18
                              : 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // İçerik
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width < 600 ? 16 : 20,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'Ad',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            size: MediaQuery.of(context).size.width < 600
                                ? 18
                                : 24,
                          ),
                          labelStyle: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.width < 600
                            ? 12
                            : 16,
                      ),
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Soyad',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            size: MediaQuery.of(context).size.width < 600
                                ? 18
                                : 18,
                          ),
                          labelStyle: TextStyle(
                            color: _isDarkMode
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Butonlar
              Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 16 : 20,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green, width: 2),
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                            vertical: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 14
                                : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                            vertical: MediaQuery.of(context).size.width < 600
                                ? 12
                                : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 14
                                : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Düzenlenebilir profil bilgisi satırı widget'ı
  Widget _buildEditableProfileInfoRow(
    String label,
    String value,
    String fieldType,
    String currentValue,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 400;

        return Container(
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.grey[300]!
                                  : Colors.grey[600]!,
                              fontSize: MediaQuery.of(context).size.width < 600
                                  ? 12
                                  : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        fieldType == 'isletme_tema_rengi'
                            ? Container(
                                padding: EdgeInsets.all(4),
                                constraints: BoxConstraints(
                                  minWidth:
                                      MediaQuery.of(context).size.width < 600
                                      ? 32
                                      : 40,
                                  minHeight:
                                      MediaQuery.of(context).size.width < 600
                                      ? 32
                                      : 40,
                                ),
                                child: Icon(
                                  Icons.lock,
                                  color: Colors.grey,
                                  size: MediaQuery.of(context).size.width < 600
                                      ? 16
                                      : 20,
                                ),
                              )
                            : IconButton(
                                onPressed: () => _showEditFieldDialog(
                                  fieldType,
                                  currentValue,
                                  label,
                                ),
                                icon: Icon(
                                  Icons.edit,
                                  color: SiriusColors.accent,
                                  size: MediaQuery.of(context).size.width < 600
                                      ? 16
                                      : 20,
                                ),
                                padding: EdgeInsets.all(4),
                                constraints: BoxConstraints(
                                  minWidth:
                                      MediaQuery.of(context).size.width < 600
                                      ? 32
                                      : 40,
                                  minHeight:
                                      MediaQuery.of(context).size.width < 600
                                      ? 32
                                      : 40,
                                ),
                              ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.width < 600 ? 4 : 8,
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 14
                            : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 600
                          ? 110
                          : 140,
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          letterSpacing: 0.2,
                          color: _isDarkMode
                              ? Colors.grey[300]!
                              : Colors.grey[600]!,
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          value,
                          style: TextStyle(
                            height: 1.25,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                            fontSize: MediaQuery.of(context).size.width < 600
                                ? 14
                                : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    fieldType == 'isletme_tema_rengi'
                        ? Container(
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width < 600
                                  ? 32
                                  : 40,
                              minHeight: MediaQuery.of(context).size.width < 600
                                  ? 32
                                  : 40,
                            ),
                            child: Icon(
                              Icons.lock,
                              color: Colors.grey,
                              size: MediaQuery.of(context).size.width < 600
                                  ? 16
                                  : 20,
                            ),
                          )
                        : IconButton(
                            onPressed: () => _showEditFieldDialog(
                              fieldType,
                              currentValue,
                              label,
                            ),
                            icon: Icon(
                              Icons.edit,
                              color: SiriusColors.accent,
                              size: MediaQuery.of(context).size.width < 600
                                  ? 16
                                  : 20,
                            ),
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width < 600
                                  ? 32
                                  : 40,
                              minHeight: MediaQuery.of(context).size.width < 600
                                  ? 32
                                  : 40,
                            ),
                          ),
                  ],
                ),
        );
      },
    );
  }

  // Alan düzenleme dialog'u
  void _showEditFieldDialog(
    String fieldType,
    String currentValue,
    String fieldLabel,
  ) {
    final TextEditingController fieldController = TextEditingController(
      text: currentValue,
    );
    final bool isTimeField =
        fieldType == 'isletme_calisma_saati_baslangic' ||
        fieldType == 'isletme_calisma_saati_bitis';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 400,
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 16 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 8 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: SiriusColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  ),
                  Expanded(
                    child: Text(
                      '$fieldLabel ${Provider.of<LanguageProvider>(context, listen: false).t('edit')}',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 18
                            : 20,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: MediaQuery.of(context).size.width < 600 ? 16 : 20,
              ),

              // Input alanı veya görsel yükleme aksiyonu
              fieldType == 'isletme_tema_rengi'
                  ? Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.grey[850]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 32,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tema rengi artık sabit #228ae6 olarak ayarlandı',
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Bu alan düzenlenemez',
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : (fieldType == 'isletme_logo_url' ||
                        fieldType == 'isletme_banner_url' ||
                        fieldType == 'isletme_arka_plan_url')
                  ? _buildImageUploadInline(
                      fieldType,
                      fieldLabel,
                      initialText: currentValue,
                    )
                  : TextField(
                      controller: fieldController,
                      readOnly: isTimeField,
                      cursorColor: _isDarkMode ? Colors.white : Colors.black87,
                      decoration: InputDecoration(
                        labelText: fieldLabel,
                        filled: true,
                        fillColor: _isDarkMode
                            ? Colors.grey[850]
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _isDarkMode
                                ? Colors.blue[400]!
                                : Colors.blue,
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: Icon(
                          _getFieldIcon(fieldType),
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                          size: MediaQuery.of(context).size.width < 600
                              ? 18
                              : 24,
                        ),
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        suffixIcon: isTimeField
                            ? IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: () async {
                                  final initial = _parseTimeOfDay(
                                    fieldController.text,
                                  );
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: initial,
                                    builder: (context, child) {
                                      final theme = Theme.of(context);
                                      return Theme(
                                        data: theme.copyWith(
                                          colorScheme: theme.colorScheme
                                              .copyWith(
                                                primary: SiriusColors.accent,
                                                onPrimary: Colors.white,
                                                surface: _isDarkMode
                                                    ? Colors.black
                                                    : Colors.white,
                                                onSurface: _isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                onSurfaceVariant: _isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                onSecondary: _isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                secondary: SiriusColors.accent
                                                    .withValues(alpha: 0.8),
                                              ),
                                          timePickerTheme: TimePickerThemeData(
                                            backgroundColor: _isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            dialBackgroundColor: _isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            hourMinuteTextColor: _isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            helpTextStyle: TextStyle(
                                              color: _isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            dialTextColor: _isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            entryModeIconColor: _isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            hourMinuteColor: _isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            dayPeriodColor: _isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            dayPeriodTextColor: _isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            dialHandColor: _isDarkMode
                                                ? Colors.blue
                                                : Colors.blue,
                                            inputDecorationTheme:
                                                InputDecorationTheme(
                                                  fillColor: _isDarkMode
                                                      ? Colors.black
                                                      : Colors.white,
                                                  labelStyle: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                  hintStyle: TextStyle(
                                                    color: _isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                ),
                                          ),
                                          textButtonTheme: TextButtonThemeData(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  SiriusColors.accent,
                                            ),
                                          ),
                                          dialogTheme: DialogThemeData(
                                            backgroundColor: _isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            surfaceTintColor: _isDarkMode
                                                ? Colors.black
                                                : Colors.white,
                                            elevation: 8,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    final formatted = _formatTimeOfDay(picked);
                                    fieldController.text = formatted;
                                  }
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 14
                            : 16,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                      onTap: () async {
                        if (!isTimeField) return;
                        final initial = _parseTimeOfDay(fieldController.text);
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: initial,
                          builder: (context, child) {
                            final theme = Theme.of(context);
                            return Theme(
                              data: theme.copyWith(
                                colorScheme: theme.colorScheme.copyWith(
                                  primary: SiriusColors.accent,
                                  onPrimary: Colors.white,
                                  surface: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  onSurface: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  onSurfaceVariant: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  onSecondary: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  secondary: SiriusColors.accent.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  dialBackgroundColor: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  hourMinuteTextColor: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  helpTextStyle: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  dialTextColor: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  entryModeIconColor: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  hourMinuteColor: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  dayPeriodColor: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  dayPeriodTextColor: _isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  dialHandColor: _isDarkMode
                                      ? Colors.blue
                                      : Colors.blue,
                                  inputDecorationTheme: InputDecorationTheme(
                                    fillColor: _isDarkMode
                                        ? Colors.black
                                        : Colors.white,
                                    labelStyle: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    hintStyle: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: SiriusColors.accent,
                                  ),
                                ),
                                dialogTheme: DialogThemeData(
                                  backgroundColor: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  surfaceTintColor: _isDarkMode
                                      ? Colors.black
                                      : Colors.white,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              child: MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          fieldController.text = _formatTimeOfDay(picked);
                        }
                      },
                    ),

              SizedBox(
                height: MediaQuery.of(context).size.width < 600 ? 20 : 24,
              ),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // Why & About anahtarları adminden güncellenirken ilgili tabloya upsert yap
                        final text = isTimeField
                            ? _normalizeTimeForDb(fieldController.text)
                            : fieldController.text;
                        if (fieldType.startsWith('why_')) {
                          await _upsertContentKey(
                            table: 'neden_bizi_secmelisiniz_bolumu',
                            key: fieldType,
                            value: text,
                          );
                        } else if (fieldType == 'about_us_subtitle' ||
                            fieldType == 'about_us_p1' ||
                            fieldType == 'about_us_p2') {
                          await _upsertContentKey(
                            table: 'hakkimizda_bolumu',
                            key: fieldType,
                            value: text,
                          );
                        } else {
                          await _updateProfileField(fieldType, text);
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green, width: 2),
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                          vertical: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('update'),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                          vertical: MediaQuery.of(context).size.width < 600
                              ? 12
                              : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('cancel'),
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 600
                              ? 14
                              : 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Çalışan fotoğraf yükleme metodu
  Future<void> _uploadEmployeePhoto(
    Function(VoidCallback) setLocalState,
  ) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;

      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();
      final String fileName =
          'employee_${DateTime.now().millisecondsSinceEpoch}.jpg';

      String? uploadedUrl;
      try {
        uploadedUrl = await DbService.uploadIsletmeImage(
          isletmeId: _isletmeId!,
          fileBytes: bytes,
          fileName: fileName,
          contentType: 'image/jpeg',
        );

        if (mounted) {
          setLocalState(() {
            _selectedPhotoUrl = uploadedUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf başarıyla yüklendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf yüklenirken hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçilirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Görsel yükleme inline bileşeni (Logo/Banner/Arka Plan)
  Widget _buildImageUploadInline(
    String fieldType,
    String fieldLabel, {
    String? initialText,
  }) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final bool isLogo = fieldType == 'isletme_logo_url';
    final bool isBanner = fieldType == 'isletme_banner_url';
    final String fileName = isLogo
        ? 'logo.jpg'
        : isBanner
        ? 'banner.jpg'
        : 'background.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 600 ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                initialText?.isNotEmpty == true ? initialText! : '—',
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _pickAndUploadSingle(
                        fieldType: fieldType,
                        fileName: fileName,
                      );
                    },
                    icon: const Icon(Icons.upload),
                    label: Text('$fieldLabel Yükle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SiriusColors.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _deleteSingleImage(fieldType: fieldType);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(lang.t('delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadSingle({
    required String fieldType,
    required String fileName,
  }) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      String? uploadedUrl;
      try {
        uploadedUrl = await DbService.uploadIsletmeImage(
          isletmeId: _isletmeId!,
          fileBytes: bytes,
          fileName: fileName,
          contentType: 'image/jpeg',
          folder: '',
        );
        if (uploadedUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Resim yüklenirken hata oluştu. Lütfen dosya boyutunu ve formatını kontrol edin.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } catch (e) {
        print('Resim yükleme hatası: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resim yükleme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Bu projede URL ya da path kullanımı mevcut alan isimleriyle uyumlu kalsın
      final payload = {
        if (fieldType == 'isletme_logo_url') 'logo_url': uploadedUrl,
        if (fieldType == 'isletme_banner_url') 'banner_url': uploadedUrl,
        if (fieldType == 'isletme_arka_plan_url') 'arka_plan_url': uploadedUrl,
      };
      if (payload.isEmpty) return;
      await Supabase.instance.client
          .from('isletme')
          .update(payload)
          .eq('isletme_id', _isletmeId!);
      await _loadIsletme();
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Görsel güncellendi')));
      }
    } catch (_) {}
  }

  Future<void> _deleteSingleImage({required String fieldType}) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null || _isletme == null) return;
      final payload = {
        if (fieldType == 'isletme_logo_url') 'logo_url': null,
        if (fieldType == 'isletme_banner_url') 'banner_url': null,
        if (fieldType == 'isletme_arka_plan_url') 'arka_plan_url': null,
      };
      if (payload.isEmpty) return;
      await Supabase.instance.client
          .from('isletme')
          .update(payload)
          .eq('isletme_id', _isletmeId!);
      await _loadIsletme();
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Görsel kaldırıldı')));
      }
    } catch (_) {}
  }

  // Galeri yönetimi
  Future<void> _addGalleryImage() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();

      String? uploadedUrl;
      try {
        uploadedUrl = await DbService.uploadIsletmeImage(
          isletmeId: _isletmeId!,
          fileBytes: bytes,
          fileName: 'gal_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
          folder: 'galeri',
        );
        if (uploadedUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Galeri resmi yüklenirken hata oluştu. Lütfen dosya boyutunu ve formatını kontrol edin.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } catch (e) {
        print('Galeri resmi yükleme hatası: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Galeri resmi yükleme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      // Satırı doğrudan ekle
      await Supabase.instance.client.from('isletme_galeri_fotograflari').insert(
        {'isletme_id': _isletmeId!, 'resim_url': uploadedUrl},
      );

      final items = await DbService.getIsletmeResimleri(_isletmeId!);
      if (mounted) {
        setState(() {
          _galeriItems = items;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Görsel eklendi')));
      }
    } catch (_) {}
  }

  // İçerik blok upsert (Why & About)
  Future<void> _upsertContentKey({
    required String table,
    required String key,
    required String value,
  }) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final client = Supabase.instance.client;
      await client
          .from(table)
          .upsert({
            'isletme_id': _isletmeId!,
            'anahtar': key,
            'deger': value,
          }, onConflict: 'isletme_id,anahtar')
          .select()
          .maybeSingle();

      final map = await DbService.getIcerikBlokMap(_isletmeId!);
      if (mounted) {
        setState(() {
          _icerikBlok = map;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İçerik güncellendi')));
    } catch (_) {}
  }

  Future<void> _removeGalleryImage(int id) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      await Supabase.instance.client
          .from('isletme_galeri_fotograflari')
          .delete()
          .eq('id', id)
          .eq('isletme_id', _isletmeId!);
      final items = await DbService.getIsletmeResimleri(_isletmeId!);
      if (mounted) {
        setState(() {
          _galeriItems = items;
        });
      }
    } catch (_) {}
  }

  // Etkinlik görselleri yönetimi (isletme.etkinlikler JSONB)
  Future<void> _addEventImage() async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();

      String? uploadedUrl;
      try {
        uploadedUrl = await DbService.uploadIsletmeImage(
          isletmeId: _isletmeId!,
          fileBytes: bytes,
          fileName: 'event_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: 'image/jpeg',
          folder: 'etkinlik',
        );
        if (uploadedUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Etkinlik resmi yüklenirken hata oluştu. Lütfen dosya boyutunu ve formatını kontrol edin.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } catch (e) {
        print('Etkinlik resmi yükleme hatası: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Etkinlik resmi yükleme hatası: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // etkinlik tablosuna yeni satır ekle
      await Supabase.instance.client.from('etkinlik').insert({
        'isletme_id': _isletmeId!,
        'afis_url': uploadedUrl,
        'aktif': true,
      });

      // Yeniden yükle
      final list = await DbService.getEtkinlikler(_isletmeId!);
      if (mounted) {
        setState(() {
          _eventItems = list
              .map((e) => {...e, 'image_url': e['afis_url']})
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinlik görseli eklendi')),
        );
      }
    } catch (_) {}
  }

  // === MENÜ / HİZMETLER ===
  Future<void> _addOrEditMenuItem({Map<String, dynamic>? existing}) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;

      String? hizmet = existing?['hizmet'] as String?;
      String? kategori = existing?['kategori'] as String?;
      String? aciklama = existing?['aciklama'] as String?;
      int sureDk = (existing?['sure_dk'] as num?)?.toInt() ?? 30;
      double fiyat = (existing?['fiyat'] as num?)?.toDouble() ?? 0;
      String? resimUrl = existing?['resim_url'] as String?;

      final hizmetCtl = TextEditingController(text: hizmet ?? '');
      final kategoriCtl = TextEditingController(text: kategori ?? 'Genel');
      final aciklamaCtl = TextEditingController(text: aciklama ?? '');
      final sureCtl = TextEditingController(text: sureDk.toString());
      final fiyatCtl = TextEditingController(text: fiyat.toString());

      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDlg) => AlertDialog(
              backgroundColor: _isDarkMode ? Colors.black : Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    existing == null
                        ? Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('new_service')
                        : '${Provider.of<LanguageProvider>(context, listen: false).t('edit')} '
                              '${Provider.of<LanguageProvider>(context, listen: false).t('service')}',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.red),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('service'),
                      ),
                      controller: hizmetCtl,
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('category'),
                      ),
                      controller: kategoriCtl,
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('description'),
                      ),
                      controller: aciklamaCtl,
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText:
                            '${Provider.of<LanguageProvider>(context, listen: false).t('duration')} (dk)',
                      ),
                      controller: sureCtl,
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      decoration: InputDecoration(
                        labelText: Provider.of<LanguageProvider>(
                          context,
                          listen: false,
                        ).t('price'),
                      ),
                      controller: fiyatCtl,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (resimUrl?.isEmpty ?? true)
                                ? Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('no_image_selected')
                                : Provider.of<LanguageProvider>(
                                    context,
                                    listen: false,
                                  ).t('image_ready'),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final XFile? file = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 90,
                            );
                            if (file == null) return;
                            final Uint8List bytes = await file.readAsBytes();
                            try {
                              final uploaded = await DbService.uploadIsletmeImage(
                                isletmeId: _isletmeId!,
                                fileBytes: bytes,
                                fileName:
                                    'menu_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                contentType: 'image/jpeg',
                                folder: 'menu',
                              );
                              if (uploaded != null) {
                                setDlg(() => resimUrl = uploaded);
                              } else {
                                // Hata mesajı göster
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Menü resmi yüklenirken hata oluştu. Lütfen dosya boyutunu ve formatını kontrol edin.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              print('Menü resmi yükleme hatası: $e');
                              String errorMessage = 'Menü resmi yükleme hatası';

                              // HTTP hata kodlarına göre özel mesajlar
                              if (e.toString().contains('400')) {
                                errorMessage =
                                    'Geçersiz dosya formatı. Lütfen JPG, PNG veya WebP formatında bir resim seçin.';
                              } else if (e.toString().contains('413')) {
                                errorMessage =
                                    'Dosya boyutu çok büyük. Lütfen 5MB\'dan küçük bir resim seçin.';
                              } else if (e.toString().contains('415')) {
                                errorMessage =
                                    'Desteklenmeyen dosya formatı. Lütfen geçerli bir resim dosyası seçin.';
                              } else if (e.toString().contains(
                                'HTTP request failed',
                              )) {
                                errorMessage =
                                    'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.';
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: Text(
                            Provider.of<LanguageProvider>(
                              context,
                              listen: false,
                            ).t('select_image'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () async {
                    final payload = <String, dynamic>{
                      'hizmet': hizmetCtl.text.trim(),
                      'kategori': kategoriCtl.text.trim(),
                      'aciklama': aciklamaCtl.text.trim(),
                      'sure_dk': int.tryParse(sureCtl.text.trim()) ?? 30,
                      'fiyat': double.tryParse(fiyatCtl.text.trim()) ?? 0,
                      if (resimUrl != null) 'resim_url': resimUrl,
                      'aktif': true,
                    };

                    if (existing == null) {
                      await Supabase.instance.client
                          .from('menu_hizmet_icerigi')
                          .insert({...payload, 'isletme_id': _isletmeId!});
                    } else {
                      final String? menuId = existing['menu_hizmet_icerigi_id']
                          ?.toString();
                      if (menuId != null) {
                        await Supabase.instance.client
                            .from('menu_hizmet_icerigi')
                            .update(payload)
                            .eq('menu_hizmet_icerigi_id', menuId)
                            .eq('isletme_id', _isletmeId!);
                      }
                    }

                    final refreshed = await DbService.getMenuHizmetIcerigi(
                      _isletmeId!,
                    );
                    if (mounted) {
                      setState(() {
                        _menuItems = refreshed;
                      });
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green, width: 2),
                    foregroundColor: Colors.green,
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    existing == null
                        ? Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('save')
                        : Provider.of<LanguageProvider>(
                            context,
                            listen: false,
                          ).t('update'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (_) {}
  }

  Future<void> _deleteMenuItem(Map<String, dynamic> item) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      final menuId = item['menu_hizmet_icerigi_id']?.toString();
      if (menuId == null) return;
      await Supabase.instance.client
          .from('menu_hizmet_icerigi')
          .delete()
          .eq('menu_hizmet_icerigi_id', menuId)
          .eq('isletme_id', _isletmeId!);
      final refreshed = await DbService.getMenuHizmetIcerigi(_isletmeId!);
      if (mounted) {
        setState(() {
          _menuItems = refreshed;
        });
      }
    } catch (_) {}
  }

  Widget _buildMenuServicesSection() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _menuItems.map((e) {
              final String title = (e['hizmet'] as String?) ?? 'Hizmet';
              final String? img = e['resim_url'] as String?;
              final String price = ((e['fiyat'] as num?)?.toString() ?? '0');
              return Container(
                width: 280,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: img != null && img.isNotEmpty
                          ? Image.network(
                              img.startsWith('http')
                                  ? img
                                  : DbService.getPublicImageUrl(img),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$price TL',
                            style: TextStyle(color: SiriusColors.accent),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _addOrEditMenuItem(existing: e),
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.blue,
                      ),
                      tooltip: Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).t('edit'),
                    ),
                    IconButton(
                      onPressed: () => _deleteMenuItem(e),
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: lang.t('delete'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _addOrEditMenuItem(),
              icon: const Icon(Icons.add),
              label: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('add_new_service'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: SiriusColors.accent,
                side: BorderSide(color: SiriusColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeEventImage(int index) async {
    try {
      await _ensureIsletmeId();
      if (_isletmeId == null) return;
      if (index < 0 || index >= _eventItems.length) return;

      final row = _eventItems[index];
      final String? etkinlikId = row['etkinlik_id'] as String?;

      if (etkinlikId == null) {
        throw Exception('Etkinlik ID bulunamadı!');
      }

      // Resim URL'sini al
      final String? resimUrl = row['resim_url'] as String?;

      // Önce mevcut kaydı kontrol et
      print('Silme işlemi: etkinlik_id=$etkinlikId');

      // Kaydın varlığını kontrol et
      final checkResult = await Supabase.instance.client
          .from('etkinlik')
          .select('*')
          .eq('etkinlik_id', etkinlikId);
      print('Mevcut kayıt: $checkResult');

      if (checkResult.isEmpty) {
        throw Exception('Silinecek kayıt bulunamadı!');
      }

      // Veritabanından etkinlik kaydını sil
      final deleteResult = await Supabase.instance.client
          .from('etkinlik')
          .delete()
          .eq('etkinlik_id', etkinlikId);
      print('Silme sonucu: $deleteResult');

      // Silme işleminden sonra tekrar kontrol et
      final afterCheck = await Supabase.instance.client
          .from('etkinlik')
          .select('*')
          .eq('etkinlik_id', etkinlikId);
      print('Silme sonrası kontrol: $afterCheck');

      // Storage'dan resmi de sil (eğer URL varsa)
      if (resimUrl != null && resimUrl.isNotEmpty) {
        try {
          // URL'den dosya yolunu çıkar
          final uri = Uri.parse(resimUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 3) {
            // Supabase storage URL formatı: /storage/v1/object/public/bucket/path
            final filePath = pathSegments.sublist(3).join('/');
            await Supabase.instance.client.storage.from('isletme').remove([
              filePath,
            ]);
          }
        } catch (storageError) {
          // Storage silme hatası kritik değil, sadece logla
          print('Storage\'dan resim silinemedi: $storageError');
        }
      }

      // Başarılı silme işleminden sonra sadece yerel listeden kaldır
      if (mounted) {
        setState(() {
          _eventItems.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Etkinlik resmi başarıyla silindi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Etkinlik resmi silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim silinirken hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Profil alanını güncelleme
  Future<void> _updateProfileField(String fieldType, String newValue) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      if (fieldType == 'email') {
        // Email güncelleme
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: newValue),
        );

        // Email değişikliği için onay gerekebilir
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email güncellendi. Yeni email adresinizi onaylamanız gerekebilir.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (fieldType == 'firstName') {
        // İsim güncelleme (Supabase metadata'da)
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'first_name': newValue}),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İsim başarıyla güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (fieldType == 'lastName') {
        // Soyisim güncelleme (Supabase metadata'da)
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'last_name': newValue}),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soyisim başarıyla güncellendi.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (fieldType == 'isletme_tema_rengi') {
        // Tema rengi artık sabit - güncellenemez
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tema rengi artık sabit #228ae6 olarak ayarlandı ve değiştirilemez.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      } else if (fieldType.startsWith('isletme_')) {
        // İşletme bilgilerini güncelleme
        if (_isletmeId != null) {
          final fieldName = fieldType.replaceFirst('isletme_', '');

          final updateData = <String, dynamic>{};
          updateData[fieldName] = newValue;

          await Supabase.instance.client
              .from('isletme')
              .update(updateData)
              .eq('isletme_id', _isletmeId!);

          // Local state'i güncelle
          if (_isletme != null) {
            _isletme![fieldName] = newValue;
          }

          // Sunucudan tazele (kalıcılığı garanti altına al)
          await _loadIsletme();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fieldName başarıyla güncellendi.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // UI'yi yenile
      if (!mounted) return;
      final refresher = _dialogSetState ?? setState;
      refresher(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${Provider.of<LanguageProvider>(context, listen: false).t('error_occurred')} $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Alan tipine göre ikon seçimi
  IconData _getFieldIcon(String fieldType) {
    switch (fieldType) {
      case 'email':
      case 'isletme_email':
        return Icons.email;
      case 'isletme_telefon':
        return Icons.phone;
      case 'isletme_web_site':
        return Icons.web;
      case 'isletme_adres':
      case 'isletme_sehir':
      case 'isletme_ilce':
      case 'isletme_posta_kodu':
        return Icons.location_on;
      case 'isletme_logo_url':
      case 'isletme_banner_url':
      case 'isletme_arka_plan_url':
        return Icons.image;
      case 'isletme_tema_rengi':
      case 'isletme_currency':
        return Icons.palette;
      case 'isletme_tip':
        return Icons.business;
      case 'isletme_aciklama':
        return Icons.description;
      case 'isletme_hero_tagline':
        return Icons.format_quote;
      case 'isletme_isim':
        return Icons.store;
      case 'isletme_calisma_saati_baslangic':
      case 'isletme_calisma_saati_bitis':
        return Icons.access_time;
      default:
        return Icons.edit;
    }
  }

  // Toplu silme dialog'u
  void _showBulkDeleteDialog(List<Appointment> appointments) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    // Tek randevu mu yoksa birden fazla randevu mu kontrol et
    bool isSingleAppointment = appointments.length == 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
              size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
            Expanded(
              child: Text(
                isSingleAppointment
                    ? lang.t('delete_appointment')
                    : lang.t('bulk_delete'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isSingleAppointment
              ? 'Seçili randevuyu kalıcı olarak silmek istediğinizden emin misiniz?\n\n'
                    'Bu işlem geri alınamaz!'
              : 'Seçili ${appointments.length} randevuyu kalıcı olarak silmek istediğinizden emin misiniz?\n\n'
                    'Bu işlem geri alınamaz!',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _bulkDeleteAppointments(appointments);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isSingleAppointment
                  ? lang.t('delete')
                  : lang.t('bulk_delete_confirm'),
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Toplu randevu silme işlemi
  Future<void> _bulkDeleteAppointments(List<Appointment> appointments) async {
    try {
      // Supabase'den tüm randevuları sil
      for (final appointment in appointments) {
        final uuid = _localApptIdToUuid[appointment.appointmentId!];
        if (uuid != null && uuid.isNotEmpty) {
          await Supabase.instance.client
              .from('randevu')
              .delete()
              .eq('randevu_id', uuid);
        }
      }

      // Seçili randevuları temizle ve UI'yi yenile
      setState(() {
        _selectedAppointments.clear();
      });
      _fetchAppointments();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${appointments.length} randevu başarıyla silindi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Toplu silme sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Şifre değiştirme satırı
  Widget _buildPasswordChangeRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 500;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lock,
                    color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('password'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPasswordChangeDialog(),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).t('change_password'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Icon(
              Icons.lock,
              color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('password'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showPasswordChangeDialog(),
              icon: const Icon(Icons.edit, size: 16),
              label: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('change_password'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue, width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Şifre değiştirme dialog'u
  void _showPasswordChangeDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.lock_reset,
              color: Colors.blue,
              size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
            Expanded(
              child: Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('change_password'),
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Kapat',
              icon: const Icon(Icons.close, color: Colors.red),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('current_password'),
                prefixIcon: Icon(
                  Icons.lock,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('new_password'),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).t('confirm_password'),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
                hintStyle: TextStyle(
                  color: _isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ),
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeni şifreler eşleşmiyor!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Yeni şifre en az 6 karakter olmalıdır!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await _changePassword(
                currentPasswordController.text,
                newPasswordController.text,
              );
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue, width: 2),
            ),
            child: Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).t('change_password'),
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Geçmiş aktiviteleri silme dialog'u
  void _showClearActivitiesDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.t('delete_past_activities'),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: MediaQuery.of(context).size.width < 400 ? 16 : 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Aktivite geçmişi görünümünü temizlemek istediğinizden emin misiniz?\n\nGerçek veriler korunur, sadece görünüm temizlenir.',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearPastActivities();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red, width: 1),
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  // Şifre değiştirme işlemi
  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception(context.t('user_not_found'));
      }

      // Şifreyi güncelle
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifre başarıyla değiştirildi!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şifre değiştirilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Randevu çakışma kontrolü için yardımcı fonksiyon
  // ignore: unused_element
  Future<Map<String, dynamic>> _checkAppointmentConflict(
    DateTime appointmentDateTime,
    String employeeName,
    String serviceName,
  ) async {
    try {
      // Çalışan ID'sini bul
      final employee = _allEmployees.firstWhere(
        (emp) => emp.fullName == employeeName,
        orElse: () =>
            throw Exception('${context.t('employee_not_found')} $employeeName'),
      );

      if (employee.id == null) {
        return {'error': 'Çalışan ID bulunamadı'};
      }

      // Hizmet ID'sini bul (services tablosundan)
      final serviceId = await _getServiceIdByName(serviceName);
      if (serviceId == null) {
        return {'error': 'Hizmet ID bulunamadı'};
      }

      // Çakışma kontrolü yap
      final conflictDetails = await DbService.getAppointmentConflictDetails(
        appointmentDateTime,
        employee.id!,
        serviceId,
      );

      return conflictDetails;
    } catch (e) {
      return {'error': 'Çakışma kontrolü hatası: $e'};
    }
  }

  // Hizmet adından ID bulma
  Future<int?> _getServiceIdByName(String serviceName) async {
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('menu_hizmet_icerigi')
          .select('menu_hizmet_icerigi_id')
          .eq('hizmet', serviceName)
          .maybeSingle();

      if (row == null) return null;

      final dynamic rawId = row['menu_hizmet_icerigi_id'];
      if (rawId == null) return null;

      // ID bazen UUID/text olabilir; kullanıldığı yer integer beklediği için makul dönüşüm uygula
      if (rawId is int) return rawId;
      final String idStr = rawId.toString();
      if (idStr.length >= 8) {
        return int.tryParse(idStr.replaceAll('-', '').substring(0, 8));
      }
      return int.tryParse(idStr);
    } catch (e) {
      return null;
    }
  }

  // Randevu çakışma uyarısı göster
  // ignore: unused_element
  void _showConflictWarning(Map<String, dynamic> conflictDetails) {
    if (conflictDetails['hasConflict'] == true) {
      final conflicts = conflictDetails['conflicts'] as List;
      final message = conflictDetails['message'] as String;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Randevu Çakışması'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              SizedBox(height: 16),
              Text(
                'Çakışan Randevular:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ...conflicts.map(
                (conflict) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${conflict['customerName']} - ${conflict['serviceName']} '
                    '(${conflict['appointmentDateTime']})',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  void _showLanguageSelectionDialog(
    BuildContext context,
    LanguageProvider lang,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.black : Colors.white,
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
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
                  title: Text(
                    lang.t('turkish'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Turkish',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
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
                  title: Text(
                    'English',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    lang.t('english'),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
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

  // Yardımcı: TimeOfDay parse/format
  TimeOfDay _parseTimeOfDay(String input) {
    try {
      final parts = input.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _normalizeTimeForDb(String input) {
    // PostgreSQL time bekler: HH:MM:SS
    if (input.isEmpty) return '';
    final base = input.length >= 5 ? input.substring(0, 5) : input;
    return '$base:00';
  }

  // Admin Screen için özel Bottom Navigation Bar
  Widget _buildAdminBottomNavigationBar() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Sadece desktop ekranlarda navbar'ı gizle (mobil ve tablet'te göster)
    if (screenWidth > 1200) {
      return const SizedBox.shrink();
    }

    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = _isDarkMode;

    // Tablet'te de mobil boyutları kullan (overflow önlemek için)
    final itemSize = 40.0; // İkon kapsayıcı bir iki tık büyütüldü
    final iconSize = 22.0; // İkon boyutu bir iki tık büyütüldü
    final fontSize = 7.5; // (Label kaldırıldı)

    return SizedBox(
      height:
          80, // Bottom bar yüksekliğini sabitleyerek tüm ekranı kaplamasını engelle
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Ana bottom navigation bar - camsız, tamamen şeffaf overlay
          Positioned(
            bottom: 8,
            left: 16,
            right: 16,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    decoration: BoxDecoration(
                      // Daha şeffaf tint; arka planın görünmesini sağlar
                      color: (isDarkMode ? Colors.black : Colors.white)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: (isDarkMode ? Colors.white : Colors.black)
                            .withValues(alpha: 0.25),
                        width: 1,
                      ),
                      // Opak görünümü engellemek için gölgeyi kaldır
                      boxShadow: const [],
                    ),
                    child: Row(
                      children: [
                        _buildAdminNavItem(
                          0,
                          Icons.work_rounded,
                          lang.isEnglish ? 'Management' : 'Yönetim',
                          isDarkMode,
                          itemSize: itemSize,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildAdminNavItem(
                          1,
                          Icons.analytics_rounded,
                          lang.isEnglish ? 'Analysis' : 'Analiz',
                          isDarkMode,
                          itemSize: itemSize,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildAdminNavItem(
                          2,
                          Icons.person_rounded,
                          lang.t('profile_title'),
                          isDarkMode,
                          itemSize: itemSize,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildAdminNavItem(
                          3,
                          Icons.home_rounded,
                          lang.t('home_title'),
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
        ],
      ),
    );
  }

  Widget _buildAdminNavItem(
    int index,
    IconData icon,
    String label,
    bool isDarkMode, {
    double itemSize = 34.0,
    double iconSize = 18.0,
    double fontSize = 8.5,
  }) {
    final isActive = _selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (index == 2) {
              // Profil butonuna basıldığında sidebar profil bilgileri dialog'unu aç
              _showAdminProfileDialog();
            } else if (index == 3) {
              // Home butonuna basıldığında ana sayfaya yönlendir
              Navigator.pushReplacementNamed(context, '/');
            } else {
              // Diğer butonlara basıldığında ilgili bölümü aç
              setState(() => _selectedIndex = index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
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
                        ? SiriusColors.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isActive
                        ? Border.all(
                            color: SiriusColors.accent.withValues(alpha: 0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: isActive
                        ? SiriusColors.accent
                        : isDarkMode
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                // Label kaldırıldı (Management/Analysis/Profile/Home yazıları gizlendi)
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Düzenleme dialog'u
  // ignore: unused_element
  void _showEditDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final currentUser = Supabase.instance.client.auth.currentUser;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          _dialogSetState = dialogSetState;
          return Dialog(
            backgroundColor: _isDarkMode
                ? Colors.grey[900]!.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width < 600
                  ? double.infinity
                  : 600,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık - Gradient arka plan ile
                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width < 600 ? 20 : 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isDarkMode
                            ? [Colors.blueGrey[800]!, Colors.blueGrey[700]!]
                            : [Colors.blue[400]!, Colors.blue[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: MediaQuery.of(context).size.width < 600
                                ? 20
                                : 28,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width < 600
                              ? 16
                              : 20,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'İşletme Bilgileri',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                      ? 18
                                      : 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hesap ve İşletme Bilgileri',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize:
                                      MediaQuery.of(context).size.width < 600
                                      ? 11
                                      : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () async {
                                await _loadIsletme();
                                if (mounted) dialogSetState(() {});
                              },
                              icon: Icon(
                                Icons.refresh,
                                color: Colors.green,
                                size: MediaQuery.of(context).size.width < 600
                                    ? 18
                                    : 22,
                              ),
                              tooltip: lang.t('refresh'),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close,
                                color: Colors.red,
                                size: MediaQuery.of(context).size.width < 600
                                    ? 20
                                    : 24,
                              ),
                              tooltip: lang.t('close'),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // İçerik
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 16 : 20,
                      ),
                      child: currentUser != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hesap Bilgileri Kategorisi (collapsible)
                                _buildCollapsibleHeader(
                                  title: lang.t('account_info'),
                                  icon: Icons.account_circle,
                                  keyName: 'account',
                                ),
                                if (_expanded['account'] == true)
                                  _buildEditableProfileInfoRow(
                                    lang.t('email'),
                                    currentUser.email ?? 'N/A',
                                    'email',
                                    currentUser.email ?? '',
                                  ),
                                if (_expanded['account'] == true)
                                  _buildPasswordChangeRow(),

                                // Kullanıcı ID ve İşletme ID alanları kaldırıldı
                                if (_isletme != null) ...[
                                  const SizedBox(height: 20),
                                  // İşletme Bilgileri Kategorisi (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('business_info'),
                                    icon: Icons.business,
                                    keyName: 'business',
                                  ),
                                  if (_expanded['business'] == true) ...[
                                    _buildEditableProfileInfoRow(
                                      lang.t('business_name'),
                                      _isletme!['isim'] ?? 'N/A',
                                      'isletme_isim',
                                      _isletme!['isim'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('business_type'),
                                      _isletme!['tip'] ?? 'N/A',
                                      'isletme_tip',
                                      _isletme!['tip'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('description'),
                                      _isletme!['aciklama'] ?? 'N/A',
                                      'isletme_aciklama',
                                      _isletme!['aciklama'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('profile_hero_tagline'),
                                      _isletme!['hero_tagline'] ?? 'N/A',
                                      'isletme_hero_tagline',
                                      _isletme!['hero_tagline'] ?? '',
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                  // İletişim Bilgileri Kategorisi (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('contact_info'),
                                    icon: Icons.contact_phone,
                                    keyName: 'contact',
                                  ),
                                  if (_expanded['contact'] == true) ...[
                                    _buildEditableProfileInfoRow(
                                      lang.t('phone'),
                                      _isletme!['telefon'] ?? 'N/A',
                                      'isletme_telefon',
                                      _isletme!['telefon'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('email'),
                                      _isletme!['email'] ?? 'N/A',
                                      'isletme_email',
                                      _isletme!['email'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('website'),
                                      _isletme!['web_site'] ?? 'N/A',
                                      'isletme_web_site',
                                      _isletme!['web_site'] ?? '',
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                  // Adres Bilgileri Kategorisi (collapsible)
                                  _buildCollapsibleHeader(
                                    title: lang.t('address_details'),
                                    icon: Icons.location_on,
                                    keyName: 'address',
                                  ),
                                  if (_expanded['address'] == true) ...[
                                    _buildEditableProfileInfoRow(
                                      lang.t('address'),
                                      _isletme!['adres'] ?? 'N/A',
                                      'isletme_adres',
                                      _isletme!['adres'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('city'),
                                      _isletme!['sehir'] ?? 'N/A',
                                      'isletme_sehir',
                                      _isletme!['sehir'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('district'),
                                      _isletme!['ilce'] ?? 'N/A',
                                      'isletme_ilce',
                                      _isletme!['ilce'] ?? '',
                                    ),
                                    _buildEditableProfileInfoRow(
                                      lang.t('postal_code'),
                                      _isletme!['posta_kodu'] ?? 'N/A',
                                      'isletme_posta_kodu',
                                      _isletme!['posta_kodu'] ?? '',
                                    ),
                                  ],

                                  const SizedBox(height: 20),
                                  // Görsel ve Tema Kategorisi
                                  _buildProfileCategoryHeader(
                                    lang.t('visual_and_theme'),
                                    Icons.palette,
                                  ),
                                  // Logo (tek görsel yöneticisi)
                                  _buildCollapsibleHeader(
                                    title: lang.t('logo_url'),
                                    icon: Icons.image_outlined,
                                    keyName: 'logo',
                                  ),
                                  if (_expanded['logo'] == true)
                                    Container(
                                      padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await _pickAndUploadSingle(
                                                    fieldType:
                                                        'isletme_logo_url',
                                                    fileName: 'logo.jpg',
                                                  );
                                                },
                                                icon: const Icon(Icons.upload),
                                                label: Text(
                                                  lang.t('upload_logo'),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      SiriusColors.accent,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  await _deleteSingleImage(
                                                    fieldType:
                                                        'isletme_logo_url',
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: Text(lang.t('delete')),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child:
                                                        ((_isletme != null) &&
                                                            ((_isletme!['logo_url']
                                                                        as String?)
                                                                    ?.isNotEmpty ==
                                                                true))
                                                        ? Image.network(
                                                            ((_isletme!['logo_url']
                                                                            as String)
                                                                        .startsWith(
                                                                          'http',
                                                                        ) ||
                                                                    (_isletme!['logo_url']
                                                                            as String)
                                                                        .startsWith(
                                                                          'https',
                                                                        ))
                                                                ? (_isletme!['logo_url']
                                                                      as String)
                                                                : DbService.getPublicImageUrl(
                                                                    _isletme!['logo_url']
                                                                        as String,
                                                                  ),
                                                            width: 96,
                                                            height: 96,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : Container(
                                                            width: 96,
                                                            height: 96,
                                                            color: Colors.grey
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 12),
                                  // Menu / Services
                                  _buildCollapsibleHeader(
                                    title: 'Menu / Services',
                                    icon: Icons.content_cut,
                                    keyName: 'menu_services',
                                  ),
                                  if (_expanded['menu_services'] == true)
                                    _buildMenuServicesSection(),
                                  const SizedBox(height: 12),
                                  // Hero/Banner (single image manager)
                                  _buildCollapsibleHeader(
                                    title: 'Hero Image',
                                    icon: Icons.landscape_outlined,
                                    keyName: 'hero',
                                  ),
                                  if (_expanded['hero'] == true)
                                    Container(
                                      padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 56,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child:
                                                  ((_isletme != null) &&
                                                      ((_isletme!['banner_url']
                                                                  as String?)
                                                              ?.isNotEmpty ==
                                                          true))
                                                  ? Image.network(
                                                      (((_isletme!['banner_url']
                                                                      as String)
                                                                  .startsWith(
                                                                    'http',
                                                                  )) ||
                                                              ((_isletme!['banner_url']
                                                                      as String)
                                                                  .startsWith(
                                                                    'https',
                                                                  )))
                                                          ? (_isletme!['banner_url']
                                                                as String)
                                                          : DbService.getPublicImageUrl(
                                                              _isletme!['banner_url']
                                                                  as String,
                                                            ),
                                                      width: 96,
                                                      height: 96,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Container(
                                                      width: 96,
                                                      height: 96,
                                                      color: Colors.grey
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                    ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 4,
                                            top: 4,
                                            child: InkWell(
                                              onTap: () async {
                                                await _deleteSingleImage(
                                                  fieldType:
                                                      'isletme_banner_url',
                                                );
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              await _pickAndUploadSingle(
                                                fieldType: 'isletme_banner_url',
                                                fileName: 'banner.jpg',
                                              );
                                            },
                                            icon: const Icon(Icons.upload),
                                            label: const Text('Upload Banner'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor:
                                                  SiriusColors.accent,
                                              side: BorderSide(
                                                color: SiriusColors.accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 12),
                                  // About Us Image (tek görsel yöneticisi)
                                  _buildCollapsibleHeader(
                                    title: 'About Us Image',
                                    icon: Icons.image_outlined,
                                    keyName: 'about_image',
                                  ),
                                  if (_expanded['about_image'] == true)
                                    Container(
                                      padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  await _pickAndUploadSingle(
                                                    fieldType:
                                                        'isletme_about_image_url',
                                                    fileName: 'about.jpg',
                                                  );
                                                },
                                                icon: const Icon(Icons.upload),
                                                label: const Text(
                                                  'About Us Görseli Yükle',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      SiriusColors.accent,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  await _deleteSingleImage(
                                                    fieldType:
                                                        'isletme_about_image_url',
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: Text(lang.t('delete')),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child:
                                                        ((_isletme != null) &&
                                                            ((_isletme!['about_image_url']
                                                                        as String?)
                                                                    ?.isNotEmpty ==
                                                                true))
                                                        ? Image.network(
                                                            ((_isletme!['about_image_url']
                                                                            as String)
                                                                        .startsWith(
                                                                          'http',
                                                                        ) ||
                                                                    (_isletme!['about_image_url']
                                                                            as String)
                                                                        .startsWith(
                                                                          'https',
                                                                        ))
                                                                ? (_isletme!['about_image_url']
                                                                      as String)
                                                                : DbService.getPublicImageUrl(
                                                                    _isletme!['about_image_url']
                                                                        as String,
                                                                  ),
                                                            width: 96,
                                                            height: 96,
                                                            fit: BoxFit.cover,
                                                          )
                                                        : Container(
                                                            width: 96,
                                                            height: 96,
                                                            color: Colors.grey
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 12),
                                  // Why Choose Us İçeriği
                                  _buildCollapsibleHeader(
                                    title: 'Why Choose Us İçeriği',
                                    icon: Icons.thumb_up_outlined,
                                    keyName: 'why_choose_us',
                                  ),
                                  if (_expanded['why_choose_us'] == true)
                                    Container(
                                      padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          TextField(
                                            controller: TextEditingController(
                                              text:
                                                  _icerikBlok['why_choose_us'] ??
                                                  '',
                                            ),
                                            maxLines: 5,
                                            decoration: InputDecoration(
                                              labelText:
                                                  'Why Choose Us İçeriği',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              _icerikBlok['why_choose_us'] =
                                                  value;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await _saveIcerikBlok();
                                              if (mounted) {
                                                dialogSetState(() {});
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  SiriusColors.accent,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Kaydet'),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 12),
                                  // About Us İçeriği
                                  _buildCollapsibleHeader(
                                    title: 'About Us İçeriği',
                                    icon: Icons.info_outline,
                                    keyName: 'about_us',
                                  ),
                                  if (_expanded['about_us'] == true)
                                    Container(
                                      padding: EdgeInsets.all(
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isDarkMode
                                              ? Colors.grey[700]!
                                              : Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          TextField(
                                            controller: TextEditingController(
                                              text:
                                                  _icerikBlok['about_us'] ?? '',
                                            ),
                                            maxLines: 5,
                                            decoration: InputDecoration(
                                              labelText: 'About Us İçeriği',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              _icerikBlok['about_us'] = value;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: () async {
                                              await _saveIcerikBlok();
                                              if (mounted) {
                                                dialogSetState(() {});
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  SiriusColors.accent,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Kaydet'),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            )
                          : const Center(
                              child: Text('Kullanıcı bilgileri yüklenemedi'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // İçerik bloklarını kaydetme metodu
  Future<void> _saveIcerikBlok() async {
    try {
      // Bu metod profil info dialog'unda da kullanılıyor
      // Şimdilik boş bırakıyoruz, gerekirse implement edilebilir
      print('İçerik blokları kaydediliyor...');
    } catch (e) {
      print('İçerik blokları kaydedilirken hata: $e');
    }
  }
}
