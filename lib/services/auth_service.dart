//import 'package:flutter/foundation.dart';
import 'package:hairsalon_flutter/models/customer.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final logger = Logger();

class AuthService {
  // PostgreSQL kaldırıldı; sadece Supabase kullanılacak

  // === SUPABASE ADMIN AUTHENTICATION ===

  // Supabase admin girişi kontrolü
  static Future<bool> isSupabaseAdmin(String email, String password) async {
    try {
      // Supabase client'ı al
      final supabase = sb.Supabase.instance.client;

      // Email ve şifre ile giriş yap
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Kullanıcının admin rolünü kontrol et
        final userRole = await _checkUserRole(response.user!.id);
        return userRole == 'admin';
      }

      return false;
    } catch (e) {
      logger.e('Supabase admin girişi hatası.', error: e);
      return false;
    }
  }

  // Kullanıcının rolünü kontrol et
  static Future<String?> _checkUserRole(String userId) async {
    try {
      final supabase = sb.Supabase.instance.client;

      // isletme_kullanici tablosundan kullanıcının rolünü al
      final response = await supabase
          .from('isletme_kullanici')
          .select('rol')
          .eq('user_id', userId)
          .single();

      return response['rol'] as String?;
    } catch (e) {
      logger.e('Kullanıcı rolü kontrolü hatası.', error: e);
      return null;
    }
  }

  // === CUSTOMER AUTHENTICATION ===
  // PostgreSQL tabanlı legacy müşteri girişi kaldırıldı

  // === SUPABASE AUTH (EK) ===

  static sb.SupabaseClient get _supabase => sb.Supabase.instance.client;

  // Email/şifre ile Supabase oturumu aç
  static Future<bool> supabaseSignIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session != null;
    } catch (e) {
      logger.e('Supabase signIn hatası', error: e);
      return false;
    }
  }

  // Supabase oturumu kapat
  static Future<void> supabaseSignOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      logger.e('Supabase signOut hatası', error: e);
    }
  }

  // Geçerli Supabase oturumu
  static sb.Session? supabaseSession() {
    return _supabase.auth.currentSession;
  }

  // Kullanıcının herhangi bir işletmede admin/editor rolü var mı?
  static Future<bool> supabaseIsAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;
      final data = await _supabase
          .from('isletme_kullanici')
          .select('rol')
          .eq('user_id', user.id)
          .inFilter('rol', ['admin', 'editor'])
          .limit(1);
      return (data as List).isNotEmpty;
    } catch (e) {
      logger.e('supabaseIsAdmin hatası', error: e);
      return false;
    }
  }

  // Supabase ile başarıyla oturum açılmışsa, müşteri profilini garanti et (musteriler)
  static Future<Customer?> ensureCustomerProfile(String email) async {
    // Önce Supabase'teki musteriler tablosunda ara; yoksa oluştur.
    try {
      final list = await _supabase
          .from('musteriler')
          .select('customerid, firstname, lastname, email, isactive')
          .eq('email', email)
          .limit(1);

      if (list.isNotEmpty) {
        final Map<String, dynamic> row = list.first;
        return Customer(
          customerId: (row['customerid'] as num).toInt(),
          firstName: (row['firstname'] as String?) ?? '',
          lastName: (row['lastname'] as String?) ?? '',
          email: row['email'] as String,
          phone: '',
          address: '',
          birthDate: null,
          gender: null,
          createdAt: DateTime.now(),
          isActive: (row['isactive'] as bool?) ?? true,
        );
      }

      // Yoksa minimal profil oluştur
      final localPart = email.split('@').first;
      String firstName = '';
      String lastName = '';
      if (localPart.contains('.')) {
        final parts = localPart.split('.');
        if (parts.isNotEmpty) firstName = parts[0];
        if (parts.length > 1) lastName = parts[1];
      } else {
        firstName = localPart;
      }

      final user = _supabase.auth.currentUser;

      final inserted = await _supabase
          .from('musteriler')
          .insert({
            'firstname': firstName,
            'lastname': lastName,
            'email': email,
            'isactive': true,
            if (user != null) 'user_id': user.id,
          })
          .select('customerid, firstname, lastname, email, isactive')
          .single();

      return Customer(
        customerId: (inserted['customerid'] as num).toInt(),
        firstName: (inserted['firstname'] as String?) ?? '',
        lastName: (inserted['lastname'] as String?) ?? '',
        email: inserted['email'] as String,
        phone: '',
        address: '',
        birthDate: null,
        gender: null,
        createdAt: DateTime.now(),
        isActive: (inserted['isactive'] as bool?) ?? true,
      );
    } catch (e) {
      logger.e('Supabase musteriler tablo erişimi hatası', error: e);
      return null;
    }
  }

  // Supabase Auth ile kullanıcı oluştur ve musteriler tablosuna profil ekle
  static Future<bool> supabaseRegisterCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      // Ek kontrol: email formatı
      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      final trimmedEmail = email.trim();
      if (!emailRegex.hasMatch(trimmedEmail)) {
        logger.w('Geçersiz e-posta formatı: $trimmedEmail');
        return false;
      }

      // Önce Supabase Auth'ta kullanıcıyı oluştur ve metadata gönder
      final signUpRes = await _supabase.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: {
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'full_name': '$firstName $lastName',
        },
      );

      final user = signUpRes.user;
      if (user == null) {
        return false;
      }

      // Eğer email onayı açıksa session null olabilir. Bu durumda
      // RLS nedeniyle client'tan insert denemeyip true döneriz.
      // Profil kaydı için DB tarafındaki trigger devreye girecektir.
      if (signUpRes.session == null) {
        return true;
      }

      // musteriler tablosunda varsa tekrar ekleme
      final existing = await _supabase
          .from('musteriler')
          .select('customerid')
          .eq('email', trimmedEmail)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('musteriler').insert({
          'firstname': firstName,
          'lastname': lastName,
          'email': trimmedEmail,
          'phone': phone,
          'isactive': true,
          'user_id': user.id,
        });
      } else {
        // Mevcut satır varsa user_id eşitle
        if ((existing['customerid'] as num?) != null) {
          await _supabase
              .from('musteriler')
              .update({'user_id': user.id})
              .eq('customerid', (existing['customerid'] as num).toInt());
        }
      }

      return true;
    } catch (e) {
      logger.e('supabaseRegisterCustomer hatası', error: e);
      rethrow; // UI'ya gerçek Supabase hatasını yansıt
    }
  }

  // Customer register
  static Future<bool> customerRegister(
    Customer customer,
    String password,
  ) async {
    // PostgreSQL kayıt kaldırıldı; Supabase kayıt akışını kullanın (supabaseRegisterCustomer)
    return await supabaseRegisterCustomer(
      firstName: customer.firstName,
      lastName: customer.lastName,
      email: customer.email,
      phone: '',
      password: password,
    );
  }

  // === ADMIN AUTHENTICATION ===
  // Admin için Supabase tabanlı kontrol kullanılmalıdır (örn. rol kontrolü)

  // === VERİTABANI BAĞLANTI TESTİ ===
  static Future<bool> testDatabaseConnection() async {
    try {
      final user = sb.Supabase.instance.client.auth.currentUser;
      return user != null;
    } catch (_) {
      return false;
    }
  }
}
