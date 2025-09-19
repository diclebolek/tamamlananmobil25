// ignore_for_file: unintended_html_in_doc_comment
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Simple language provider to toggle and read translations.
///
/// Usage pattern inside widgets:
///   final lang = context.watch<LanguageProvider>();
///   Text(lang.t('appointment_title'))
///
/// Keep keys consistent across the app. Add new keys to both `en` and `tr` maps.
class LanguageProvider extends ChangeNotifier {
  LanguageProvider({AppLanguage initialLanguage = AppLanguage.en})
    : _currentLanguage = initialLanguage;

  AppLanguage _currentLanguage;

  /// Current selected language
  AppLanguage get currentLanguage => _currentLanguage;

  /// Convenience flags
  bool get isTurkish => _currentLanguage == AppLanguage.tr;
  bool get isEnglish => _currentLanguage == AppLanguage.en;

  /// Flutter `Locale` to be used by `MaterialApp.locale`
  Locale get locale => isTurkish ? const Locale('tr') : const Locale('en');

  /// Switch language at runtime
  void setLanguage(AppLanguage language) {
    if (language == _currentLanguage) return;
    _currentLanguage = language;
    notifyListeners();
  }

  /// Translate by key. Falls back to the key itself if missing.
  String t(String key) {
    final table = _translations[_currentLanguage] ?? const {};
    return table[key] ?? key;
  }

  /// Core translation tables.
  ///
  /// IMPORTANT:
  /// - Add every new key to BOTH languages to keep parity.
  /// - Keep keys lowercase_with_underscores.
  static const Map<AppLanguage, Map<String, String>> _translations = {
    AppLanguage.en: {
      // Titles / Headers
      'app_title': 'Hair Salon',
      'home_title': 'Home',
      'appointment_title': 'Appointments',
      'services_title': 'Services',
      'stylists_title': 'Stylists',
      'profile_title': 'Profile',

      // Common actions / Buttons
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'update': 'Update',
      'select_employee': 'Select Employee',
      'confirm': 'Confirm',
      'book_now': 'Book Now',
      'refresh': 'Refresh',
      'filter': 'Filter',
      'new_employee': 'New Employee',
      'change_language': 'Change Language',
      'advanced_options': 'Advanced Options',
      // Admin specific
      'employee_management': 'Employee Management',
      'name_surname_and_actions': 'Name, Surname and Actions',
      'enter_new_employee_info': 'Please Enter New Employee Information',
      'welcome': 'Welcome!',
      'admin_panel': 'Admin Panel',
      'search_employee_hint': 'Search employee (name, surname)...',
      'search_appointment_hint': 'Search appointment...',
      'select_all': 'Select All',
      'employee_performance_analysis': 'Employee Performance Analysis',
      'refresh_performance_data': 'Refresh Performance Data',
      'refresh_employees': 'Refresh Employees',
      'clear_performance_data': 'Clear Performance Data',
      'performance_data_cleared': 'Performance data cleared',
      'employee_performance_help': 'Employee Performance Help',
      'employees': 'Employees',
      'total_employees': 'Total Employees',
      'total_earnings': 'Total Earnings',
      'average_efficiency': 'Average Efficiency',
      'efficiency': 'Efficiency',
      'hourly_earnings': 'Hourly Earnings',
      'per_appointment': 'Per Appointment',
      'expertise': 'Expertise',
      'skills': 'Skills',
      'general': 'General',
      'account_and_business_info': 'Account and Business Information',
      'manage_appointments_and_employees':
          'Manage appointments and edit employee information',
      'track_and_analyze_performance': 'Track and analyze employee performance',
      'performance_data_loading': 'Loading performance data...',
      'no_performance_data': 'No performance data found',

      // Status labels
      'waiting': 'Waiting',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'unknown': 'Unknown',

      // Form labels / helpers
      'name': 'Name',
      'surname': 'Surname',
      'email': 'Email',
      'phone': 'Phone',
      'date': 'Date',
      'time': 'Time',
      'notes': 'Notes',
      'select_service': 'Select Service',
      'select_stylist': 'Select Stylist',

      // Paragraphs / Explanations
      'appointment_description':
          'Choose your preferred service and stylist to book an appointment.',
      'no_appointments': 'You have no upcoming appointments.',

      // Footer / Misc
      'footer_rights': 'All rights reserved.',
      'footer_contact': 'Contact',
      'footer_terms': 'Terms',
      'footer_privacy': 'Privacy',

      // Appointment screen
      'back': 'Back',
      'create_appointment': 'Create Appointment',
      'create_appointment_request': 'Create Appointment Request',
      'select_service_label': 'Select Service',
      'loading': 'Loading...',
      'refresh_services': 'Refresh Services',
      'select_service_hint': 'Select a service',
      'select_service_validate': 'Please select a service',
      'select_employee_label': 'Select Employee',
      'select_employee_validate': 'Please select an employee',
      'select_service_first': 'Please select a service first',
      'no_employee_for_service': 'No available employee for this service',
      'notes_optional': 'Notes (Optional)',
      'enter_notes': 'Enter your notes...',
      'date_time': 'Date & Time',
      'make_appointment': 'Make Appointment',
      'service': 'Service',
      'employee': 'Employee',
      'pick_date': 'Pick Date',
      'pick_time': 'Pick Time',
      'appointment_created_success': 'Appointment created successfully!',
      'error_occurred': 'Error occurred:',
      'error_loading_data': 'Error loading data',
      'error_loading_performance': 'Error loading performance data',
      'error_loading_employees': 'Error loading employees',
      'please_fill_all_fields': 'Please fill all fields!',
      'employee_added_success': 'Employee added successfully!',
      'employee_updated_success': 'Employee updated successfully!',
      'employee_deleted_success': 'Employee deleted successfully!',
      'please_fill_required': 'Please fill all required fields',
      'business_id_not_found': 'Business ID not found',
      'user_not_logged_in': 'User is not logged in',
      'customer_not_found': 'Customer information not found',
      'appointment_conflict_title': 'Appointment Conflict',
      'employee_not_available':
          'The employee is not available at the selected time:',
      'conflicting_appointments': 'Conflicting Appointments:',
      'ok': 'OK',
      'appointment_cancellation': 'Appointment Cancellation',
      'edit_appointment': 'Edit Appointment',
      'cancel_appointment': 'Cancel Appointment',

      // Login screen
      'welcome_to': 'Welcome to',
      'sign_in_to_your': 'Sign in to your',
      'account': 'account',
      'email_address': 'Email Address',
      'enter_email': 'Enter your email',
      'password': 'Password',
      'enter_password': 'Enter your password',
      'password_min': 'Password must be at least 6 characters',
      'new_password': 'New Password',
      'confirm_password': 'Confirm Password',
      'new_password_min': 'New Password (min 6 characters)',
      'remember_me': 'Remember me',
      'forgot_password': 'Forgot Password?',
      'or': 'OR',
      'sign_in': 'Sign In',
      'sign_up': 'Sign Up',
      'join': 'Join',
      'create_account': 'Create Account',
      'create_account_description':
          'Create your {business} account to book appointments',
      'already_have_account': 'Already have an account?',
      'forgot_password_title': 'Forgot Password',
      'password_reset_sent': 'Password reset link sent to your email!',
      'send': 'Send',

      // Services screen
      'our_services': 'Our Services',
      'try_again': 'Try Again',
      'no_services': 'No services available yet.',
      'minute_suffix': 'min',
      // Dynamic categories
      'fitness': 'Fitness',
      'nutrition': 'Nutrition',
      'wellness': 'Wellness',

      // Admin / Navigation labels
      'employee_and_appointment': 'Employees & Appointments',
      'performance_analysis': 'Performance Analysis',
      'profile_info': 'Profile Info',
      'account_info': 'Account Information',
      'user_id': 'User ID',
      'business_id': 'Business ID',
      'business_info': 'Business Information',
      'business_name': 'Business Name',
      'business_type': 'Business Type',
      'description': 'Description',
      'website': 'Website',
      'address_details': 'Address Details',
      'city': 'City',
      'district': 'District',
      'postal_code': 'Postal Code',
      'visual_and_theme': 'Visual & Theme',
      'logo_url': 'Logo URL',
      'banner_url': 'Banner URL',
      'background_url': 'Background URL',
      'theme_color': 'Theme Color',
      'work_start': 'Work Start',
      'work_end': 'Work End',
      'created_and_last_login': 'Created / Last Login',
      'about_us': 'About Us',
      'about_description':
          'At Sirius Beauty & Spa, we believe that true beauty comes from within, and we\'re here to help you shine like the star you are.',
      'turkish': 'Turkish',
      'english': 'English',

      // Login screen additional translations
      'customer': 'Customer',
      'admin': 'Admin',
      'dont_have_account': 'Don\'t have an account?',
      'register': 'Register',

      // Sidebar and navigation
      'logout': 'Logout',
      'exit': 'Exit',

      // Why Choose Us section
      'why_choose_us': 'Why Choose Us',
      'why_choose_us_description':
          'We provide the best service with our experienced team',
      'professional_service': 'Professional Service',
      'professional_service_description':
          'Our team consists of experts in their field',
      'quality_products': 'Quality Products',
      'quality_products_description':
          'We use only the highest quality products',
      'customer_satisfaction': 'Customer Satisfaction',
      'customer_satisfaction_description': 'Your satisfaction is our priority',

      // Menu services
      'hair_cut': 'Hair Cut',
      'hair_styling': 'Hair Styling',
      'hair_coloring': 'Hair Coloring',
      'hair_treatment': 'Hair Treatment',
      'manicure': 'Manicure',
      'pedicure': 'Pedicure',
      'facial': 'Facial',
      'massage': 'Massage',

      // Footer
      'contact_us': 'Contact Us',
      'address': 'Address',
      'footer_phone': 'Phone',
      'footer_email': 'Email',
      'working_hours': 'Working Hours',
      'monday_friday': 'Monday - Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
      'all_rights_reserved': 'All Rights Reserved',

      // Profile screen story buttons
      'edit_profile_info': 'Edit Profile Info',
      'profile_contact_us': 'Contact Us',
      'profile_create_appointment': 'Create Appointment',
      'get_directions': 'Get Directions',

      // Dialog titles and content
      'directions_dialog_title': 'Get Directions',
      'contact_dialog_title': 'Contact',
      'address_label': 'Address',
      'district_label': 'District',
      'city_label': 'City',
      'postal_code_label': 'Postal Code',
      'phone_label': 'Phone',
      'email_label': 'Email',
      'working_hours_label': 'Working Hours',
      'public_transport_title': 'Public Transportation',
      'public_transport_info':
          'Metro: M4 Kadıköy-Kartal line\nBus: 10A, 15F, 16A\nMarmaray: Ayrılık Çeşmesi station',
      'cancel_button': 'Cancel',
      'open_on_map': 'Open on Map',

      // Home screen additional translations
      'sirius_hair_salon': 'Sirius Hair Salon',
      'navbar_home': 'Home',
      'navbar_about': 'About Us',
      'navbar_menu': 'Menu',
      'navbar_team': 'Team',
      'navbar_contact': 'Contact',
      'events': 'Events',
      'our_team': 'Our Team',
      'gallery': 'Gallery',
      'contact': 'Contact',
      'ad_soyad': 'Name Surname',
      'no_appointments_found': 'No appointments found',
      'appointments': 'Appointments',
      'profile_settings': 'Page Settings',
      'profile_settings_dialog': 'Profile Settings',
      'page_settings': 'Page Settings',
      'dark_mode': 'Dark Mode',
      'light_mode': 'Light Mode',
      'language': 'Language',
      'status': 'Status',
      'approved': 'Approved',
      'pending': 'Pending',
      'canceled': 'Canceled',
      'cancelled': 'Cancelled',
      'light_theme': 'Light Theme',
      'dark_theme': 'Dark Theme',
      'close': 'Close',
      'change_password': 'Change Password',
      'contact_info': 'Contact Information',
      'get_directions_info': 'Get directions to our salon',
      'working_hours_info': 'Monday - Saturday: 07:00 - 23:00',
      'phone_info': '+905348956232',
      'email_info': 'gymOrion@gmail.com',
      'website_info': 'www.oriongym.com',
      'address_info': 'Istanbul, Kadıköy, Istanbul 34744',

      // Form fields
      'subject': 'Subject',
      'message': 'Message',
      'send_message': 'Send Message',
      'message_sent': 'Message sent!',

      // Appointment filter buttons
      'all': 'All',
      'past': 'Past',
      'confirmed': 'Confirmed',

      // Sorting buttons
      'newest_to_oldest': 'Newest to Oldest',
      'oldest_to_newest': 'Oldest to Newest',

      // Menu buttons and card texts
      'book_appointment': 'Book Appointment',
      'view_services': 'View Services',
      'meet_team': 'Meet Our Team',
      'view_gallery': 'View Gallery',
      'menu_contact_us': 'Contact Us',
      'learn_more': 'Learn More',
      'read_more': 'Read More',
      'see_all': 'See All',
      'view_details': 'View Details',

      // Card content texts
      'beauty_meets_serenity': 'Where Beauty Meets Serenity',
      'beauty_meets_serenity_desc':
          'At Sirius, we create a peaceful escape from the hustle of daily life. Our tranquil atmosphere and expert care are designed to help you relax, rejuvenate, and rediscover your inner calm.',
      'your_beauty_our_galaxy': 'Your Beauty, Our Galaxy',
      'your_beauty_our_galaxy_desc':
          'You are at the center of everything we do. Our personalized treatments celebrate your unique beauty, enhancing your natural radiance with the finest products and techniques.',
      'glow_beyond_stars': 'Glow Beyond the Stars with Sirius',
      'glow_beyond_stars_desc':
          'We go beyond ordinary beauty care to make you feel extraordinary. At Sirius, every treatment is crafted to leave you glowing with confidence.',

      // About Us section
      'home_about_us': 'About Us',
      'home_about_us_description':
          'At Sirius Beauty & Spa, we believe that true beauty comes from within, and we\'re here to help you shine like the star you are.',
      'about_us_subtitle':
          'Our mission is to empower you to look and feel your best.',
      'about_us_p1':
          'At Sirius, we combine our passion for beauty with advanced techniques to deliver exceptional services. Our team of skilled professionals is dedicated to providing a personalized experience tailored to your unique needs.',
      'about_us_p2':
          'From hair styling and makeup to relaxing spa treatments, we use only the highest quality products to ensure lasting results. Step into our salon and let us guide you on a journey to radiance and rejuvenation.',

      // Our Services section
      'home_our_services': 'Our Services',
      'home_our_services_description':
          'We offer a wide range of beauty and wellness services to help you look and feel your best.',

      // Hero section
      'hero_subtitle': 'Beauty Salon & Spa',
      'hero_tagline': 'Feel Beautiful, Be Sirius',

      // Menu buttons
      'menu_book_appointment': 'Book Appointment',
      'menu_view_services': 'View Services',
      'menu_meet_team': 'Meet Our Team',
      'menu_view_gallery': 'View Gallery',

      // Service names
      'service_hair_cut': 'Hair Cut',
      'service_hair_styling': 'Hair Styling',
      'service_hair_coloring': 'Hair Coloring',
      'service_hair_treatment': 'Hair Treatment',
      'service_manicure': 'Manicure',
      'service_pedicure': 'Pedicure',
      'service_facial': 'Facial',
      'service_massage': 'Massage',

      // Footer additional texts
      'footer_website': 'Website',
      'footer_working_hours_info': 'Monday - Saturday: 07:00 - 23:00',
      'footer_phone_info': '+905348956232',
      'footer_email_info': 'gymOrion@gmail.com',
      'footer_address_info': 'Istanbul, Kadıköy, Istanbul 34744',

      // Additional error messages and notifications
      'passwords_do_not_match': 'Passwords do not match!',
      'photo_uploading': 'Uploading photo...',
      'profile_photo_updated_success': 'Profile photo updated successfully!',
      'photo_upload_error': 'Error uploading photo:',
      'profile_updated_success': 'Profile information updated successfully!',
      'profile_update_error': 'Error updating profile:',
      'logout_tooltip': 'Logout',
      'appointments_loading': 'Loading appointments...',
      'my_appointments': 'My Appointments',
      'appointment_loading_error':
          'Error loading appointment information. Please try again.',
      'password_min_length': 'Password must be at least 6 characters',
      'new_passwords_do_not_match': 'New passwords do not match',
      'user_session_not_found': 'User session not found',
      'current_password_incorrect': 'Current password is incorrect',
      'password_updated_success': 'Password updated successfully',
      'password_update_error': 'Password could not be updated:',
      'not_specified': 'Not specified',
      'cancel_appointment_confirm':
          'Are you sure you want to cancel this appointment?',
      'customer_id_not_found': 'Customer ID not found',
      'appointment_cancelled_success': 'Appointment cancelled successfully',
      'logout_error': 'Could not logout:',
      'appointment_updated_success': 'Appointment updated successfully',
      'appointment_update_error': 'Appointment could not be updated:',
      'profile_updated_success_alt': 'Profile information updated successfully',
      'profile_update_error_alt': 'Profile could not be updated:',
      'appointment_could_not_be_created': 'Appointment could not be created',
      'business_id_resolving': 'Resolving Business ID...',
      'business_id_value': 'Business ID:',
      'business_id_resolve_error': 'Business ID resolution error:',
      'business_id_already_exists': 'Business ID already exists:',
      'appointment_table_test_error': 'Appointment table test error:',
      'main_appointment_query_running': 'Running main appointment query...',
      'appointment_list_error': 'Appointment list error:',
      'appointment_status_changing':
          'Changing appointment status - Appointment ID:',
      'appointment_status_change_error':
          'Error changing appointment status cyclically:',
      'supabase_update_result': 'Supabase update result:',
      'appointment_status_update_error': 'Error updating appointment status:',
      'business_id_not_found_alt': 'Business ID not found',
      'employee_id_not_found': 'Employee ID not found',
      'user_not_found': 'User not found',
      'employee_not_found': 'Employee not found:',

      // Profile Info Dialog
      'profile_hero_tagline': 'Hero Tagline',
      'upload_logo': 'Upload Logo',
      'delete_selected_appointments': 'Delete Selected Appointments',
      'delete_employee': 'Delete Employee',
      'delete_employee_confirm':
          'Are you sure you want to delete this employee?',
      'delete_past_activities': 'Delete Past Activities',
      'delete_appointment': 'Delete Appointment',
      'bulk_delete': 'Bulk Delete',
      'bulk_delete_confirm': 'Bulk Delete',
      // Admin profile images & gallery
      'upload_hero_image': 'Upload Hero Image',
      'about_us_image': 'About Us Image',
      'upload_about_image': 'Upload About Image',
      'add_image_to_gallery': 'Add Image to Gallery',
      // Admin edit dialogs/buttons
      'add_event_image': 'Add Event Image',
      'select_image': 'Select Image',
      'new_service': 'New Service',
      // Why choose us editable cards
      'card_1_title': 'Card 1 Title',
      'card_1_desc': 'Card 1 Desc',
      'card_2_title': 'Card 2 Title',
      'card_2_desc': 'Card 2 Desc',
      'card_3_title': 'Card 3 Title',
      'card_3_desc': 'Card 3 Desc',
      // New service dialog fields
      'category': 'Category',
      'duration': 'Duration',
      'price': 'Price',
      'no_image_selected': 'No image selected',
      'image_ready': 'Image ready',
      'add_new_service': 'Add New Service',
      'employee_name_hint': 'Employee name',
      'employee_surname_hint': 'Employee surname',
      'email_hint': 'example@company.com',
      'skills_hint': 'E.g: Hair coloring, Cutting, Blow-dry',
      'upload_photo': 'Upload Photo',
      'change_photo': 'Change Photo',
      'first_name': 'First Name',
      'last_name': 'Last Name',
      'select_category': 'Select Category',
      'add': 'Add',
      'select_photo': 'Select Photo',
    },
    AppLanguage.tr: {
      // Titles / Headers
      'app_title': 'Kuaför Salonu',
      'home_title': 'Ana Sayfa',
      'appointment_title': 'Randevular',
      'services_title': 'Hizmetler',
      'stylists_title': 'Uzmanlar',
      'profile_title': 'Profil',

      // Common actions / Buttons
      'save': 'Kaydet',
      'cancel': 'İptal',
      'delete': 'Sil',
      'edit': 'Düzenle',
      'update': 'Güncelle',
      'select_employee': 'Çalışan Seç',
      'confirm': 'Onayla',
      'book_now': 'Hemen Randevu Al',
      'refresh': 'Yenile',
      'filter': 'Filtrele',
      'new_employee': 'Yeni Çalışan',
      'change_language': 'Dili Değiştir',
      // Admin specific
      'employee_management': 'Çalışan Yönetimi',
      'name_surname_and_actions': 'Ad, Soyad ve İşlemler',
      'enter_new_employee_info': 'Yeni Çalışan Bilgilerini Lütfen Girin',
      'welcome': 'Hoş Geldiniz!',
      'admin_panel': 'Yönetim Paneli',
      'search_employee_hint': 'Çalışan ara (ad, soyad)...',
      'search_appointment_hint': 'Randevu ara...',
      'select_all': 'Tümünü Seç',
      'employee_performance_analysis': 'Çalışan Performans Analizi',
      'refresh_performance_data': 'Performans Verilerini Yenile',
      'refresh_employees': 'Çalışanları Yenile',
      'clear_performance_data': 'Performans Verilerini Temizle',
      'performance_data_cleared': 'Performans verileri temizlendi',
      'employee_performance_help': 'Çalışan Performans Analizi Yardım',
      'employees': 'Çalışanlar',
      'total_employees': 'Toplam Çalışan',
      'total_earnings': 'Toplam Kazanç',
      'average_efficiency': 'Ortalama Verimlilik',
      'efficiency': 'Verimlilik',
      'hourly_earnings': 'Saatlik Kazanç',
      'per_appointment': 'Randevu Başına',
      'expertise': 'Uzmanlık',
      'skills': 'Beceriler',
      'general': 'Genel',
      'account_and_business_info': 'Hesap ve İşletme Bilgileri',
      'manage_appointments_and_employees':
          'Randevuları yönetin ve çalışan bilgilerini düzenleyin',
      'track_and_analyze_performance':
          'Çalışan performansını takip edin ve analiz edin',
      'performance_data_loading': 'Performans verileri yükleniyor...',
      'no_performance_data': 'Performans verisi bulunamadı',

      // Status labels
      'waiting': 'Bekliyor',
      'in_progress': 'Devam Ediyor',
      'completed': 'Tamamlandı',
      'unknown': 'Bilinmeyen',

      // Form labels / helpers
      'name': 'Ad',
      'surname': 'Soyad',
      'email': 'E-posta',
      'phone': 'Telefon',
      'date': 'Tarih',
      'time': 'Saat',
      'notes': 'Notlar',
      'select_service': 'Hizmet Seçin',
      'select_stylist': 'Uzman Seçin',

      // Paragraphs / Explanations
      'appointment_description':
          'Randevu oluşturmak için tercih ettiğiniz hizmeti ve uzmanı seçin.',
      'no_appointments': 'Yaklaşan bir randevunuz yok.',

      // Footer / Misc
      'footer_rights': 'Tüm hakları saklıdır.',
      'footer_contact': 'İletişim',
      'footer_terms': 'Şartlar',
      'footer_privacy': 'Gizlilik',

      // Appointment screen
      'back': 'Geri',
      'create_appointment': 'Randevu Oluştur',
      'create_appointment_request': 'Randevu Talebi Oluştur',
      'select_service_label': 'Hizmet Seçin',
      'loading': 'Yükleniyor...',
      'refresh_services': 'Hizmetleri Yenile',
      'select_service_hint': 'Hizmet seçin',
      'select_service_validate': 'Lütfen bir hizmet seçin',
      'select_employee_label': 'Çalışan Seçin',
      'select_employee_validate': 'Lütfen bir çalışan seçin',
      'select_service_first': 'Önce bir hizmet seçin',
      'no_employee_for_service': 'Bu hizmet için uygun çalışan bulunamadı',
      'notes_optional': 'Notlar (Opsiyonel)',
      'enter_notes': 'Notlarınızı yazın...',
      'date_time': 'Tarih ve Saat',
      'make_appointment': 'Randevu Al',
      'service': 'Hizmet',
      'employee': 'Çalışan',
      'pick_date': 'Tarih Seç',
      'pick_time': 'Saat Seç',
      'appointment_created_success': 'Randevu başarıyla oluşturuldu!',
      'error_occurred': 'Hata oluştu:',
      'error_loading_data': 'Veri yüklenirken hata oluştu',
      'error_loading_performance':
          'Performans verileri yüklenirken hata oluştu',
      'error_loading_employees': 'Çalışanlar yüklenirken hata oluştu',
      'please_fill_all_fields': 'Lütfen tüm alanları doldurun!',
      'employee_added_success': 'Çalışan başarıyla eklendi!',
      'employee_updated_success': 'Çalışan başarıyla güncellendi!',
      'employee_deleted_success': 'Çalışan başarıyla silindi!',
      'please_fill_required': 'Lütfen tüm gerekli alanları doldurun',
      'business_id_not_found': 'İşletme ID bulunamadı',
      'user_not_logged_in': 'Kullanıcı girişi yapılmamış',
      'customer_not_found': 'Müşteri bilgileri bulunamadı',
      'appointment_conflict_title': 'Randevu Çakışması',
      'employee_not_available': 'Seçilen saatte çalışan müsait değil:',
      'conflicting_appointments': 'Çakışan Randevular:',
      'ok': 'Tamam',
      'appointment_cancellation': 'Randevu İptali',
      'edit_appointment': 'Randevu Düzenle',
      'cancel_appointment': 'İptal Et',

      // Login screen
      'welcome_to': 'Hoş geldiniz',
      'sign_in_to_your': 'Hesabınıza giriş yapın',
      'account': 'hesabı',
      'email_address': 'E-posta Adresi',
      'enter_email': 'E-postanızı girin',
      'password': 'Şifre',
      'enter_password': 'Şifrenizi girin',
      'password_min': 'Şifre en az 6 karakter olmalıdır',
      'new_password': 'Yeni Şifre',
      'confirm_password': 'Yeni Şifre (Tekrar)',
      'new_password_min': 'Yeni Şifre (min 6 karakter)',
      'remember_me': 'Beni hatırla',
      'forgot_password': 'Şifremi Unuttum?',
      'or': 'VEYA',
      'sign_in': 'Giriş Yap',
      'sign_up': 'Kayıt Ol',
      'join': 'Katıl',
      'create_account': 'Hesap Oluştur',
      'create_account_description':
          '{business} hesabınızı oluşturun ve randevu alın',
      'already_have_account': 'Zaten hesabınız var mı?',
      'forgot_password_title': 'Şifremi Unuttum',
      'password_reset_sent':
          'Şifre sıfırlama bağlantısı e-postanıza gönderildi!',
      'send': 'Gönder',

      // Services screen
      'our_services': 'Hizmetlerimiz',
      'try_again': 'Tekrar Dene',
      'no_services': 'Henüz hizmet bulunmamaktadır.',
      'minute_suffix': 'dk',
      // Dynamic categories
      'fitness': 'Fitness',
      'nutrition': 'Beslenme',
      'wellness': 'Wellness',

      // Admin / Navigation labels
      'employee_and_appointment': 'Çalışan & Randevu',
      'performance_analysis': 'Performans Analizi',
      'profile_info': 'Profil Bilgileri',
      'account_info': 'Hesap Bilgileri',
      'user_id': 'Kullanıcı ID',
      'business_id': 'İşletme ID',
      'business_info': 'İşletme Bilgileri',
      'business_name': 'İşletme Adı',
      'business_type': 'İşletme Türü',
      'description': 'Açıklama',
      'website': 'Web Sitesi',
      'address_details': 'Adres Bilgileri',
      'city': 'Şehir',
      'district': 'İlçe',
      'postal_code': 'Posta Kodu',
      'visual_and_theme': 'Görsel ve Tema',
      'logo_url': 'Logo URL',
      'banner_url': 'Banner URL',
      'background_url': 'Arka Plan URL',
      'theme_color': 'Tema Rengi',
      'work_start': 'Çalışma Saati Başlangıç',
      'work_end': 'Çalışma Saati Bitiş',
      'created_and_last_login': 'Oluşturulma / Son Giriş',
      'about_us': 'Hakkımızda',
      'about_description':
          'Sirius Beauty & Spa\'da, gerçek güzelliğin içten geldiğine inanıyoruz ve yıldız gibi parlamanıza yardım etmek için buradayız.',
      'turkish': 'Türkçe',
      'english': 'İngilizce',

      // Login screen additional translations
      'customer': 'Müşteri',
      'admin': 'Yönetici',
      'dont_have_account': 'Hesabınız yok mu?',
      'register': 'Kayıt Ol',

      // Sidebar and navigation
      'logout': 'Çıkış Yap',
      'exit': 'Çıkış',

      // Why Choose Us section
      'why_choose_us': 'Neden Bizi Seçmelisiniz',
      'why_choose_us_description':
          'Deneyimli ekibimizle en iyi hizmeti sunuyoruz',
      'professional_service': 'Profesyonel Hizmet',
      'professional_service_description':
          'Ekibimiz alanında uzman kişilerden oluşur',
      'quality_products': 'Kaliteli Ürünler',
      'quality_products_description':
          'Sadece en yüksek kalitede ürünler kullanıyoruz',
      'customer_satisfaction': 'Müşteri Memnuniyeti',
      'customer_satisfaction_description': 'Memnuniyetiniz önceliğimizdir',

      // Menu services
      'hair_cut': 'Saç Kesimi',
      'hair_styling': 'Saç Şekillendirme',
      'hair_coloring': 'Saç Boyama',
      'hair_treatment': 'Saç Bakımı',
      'manicure': 'Manikür',
      'pedicure': 'Pedikür',
      'facial': 'Cilt Bakımı',
      'massage': 'Masaj',

      // Footer
      'contact_us': 'Bize Ulaşın',
      'address': 'Adres',
      'footer_phone': 'Telefon',
      'footer_email': 'E-posta',
      'working_hours': 'Çalışma Saatleri',
      'monday_friday': 'Pazartesi - Cuma',
      'saturday': 'Cumartesi',
      'sunday': 'Pazar',
      'all_rights_reserved': 'Tüm Hakları Saklıdır',

      // Profile screen story buttons
      'edit_profile_info': 'Profil Bilgilerimi Düzenle',
      'profile_contact_us': 'İletişime Geç',
      'profile_create_appointment': 'Randevu Oluştur',
      'get_directions': 'Yol Tarifi',

      // Dialog titles and content
      'directions_dialog_title': 'Yol Tarifi',
      'contact_dialog_title': 'İletişim',
      'address_label': 'Adres',
      'district_label': 'İlçe',
      'city_label': 'Şehir',
      'postal_code_label': 'Posta Kodu',
      'phone_label': 'Telefon',
      'email_label': 'Email',
      'working_hours_label': 'Çalışma Saatleri',
      'public_transport_title': 'Toplu Taşıma ile Ulaşım',
      'public_transport_info':
          'Metro: M4 Kadıköy-Kartal hattı\nOtobüs: 10A, 15F, 16A\nMarmaray: Ayrılık Çeşmesi durağı',
      'cancel_button': 'Vazgeç',
      'open_on_map': 'Haritada Aç',

      // Home screen additional translations
      'sirius_hair_salon': 'Sirius Kuaför Salonu',
      'navbar_home': 'Anasayfa',
      'navbar_about': 'Hakkımızda',
      'navbar_menu': 'Menu',
      'navbar_team': 'Ekip Üyeleri',
      'navbar_contact': 'İletişim',
      'events': 'Etkinlikler',
      'our_team': 'Ekibimiz',
      'gallery': 'Galeri',
      'contact': 'İletişim',
      'ad_soyad': 'Ad Soyad',
      'no_appointments_found': 'Randevu bulunamadı',
      'appointments': 'Randevular',
      'profile_settings': 'Sayfa Ayarları',
      'profile_settings_dialog': 'Profil Ayarları',
      'page_settings': 'Sayfa Ayarları',
      'dark_mode': 'Karanlık Mod',
      'light_mode': 'Açık Mod',
      'language': 'Dil',
      'status': 'Durum',
      'approved': 'Onaylandı',
      'pending': 'Beklemede',
      'canceled': 'İptal Edildi',
      'cancelled': 'İptal Edildi',
      'light_theme': 'Açık Tema',
      'dark_theme': 'Koyu Tema',
      'close': 'Kapat',
      'change_password': 'Şifre Değiştir',
      'contact_info': 'İletişim Bilgileri',
      'get_directions_info': 'Salonumuza yol tarifi alın',
      'working_hours_info': 'Pazartesi - Cumartesi: 07:00 - 23:00',
      'phone_info': '+905348956232',
      'email_info': 'gymOrion@gmail.com',
      'website_info': 'www.oriongym.com',
      'address_info': 'İstanbul, Kadıköy, İstanbul 34744',

      // Form fields
      'subject': 'Konu',
      'message': 'Mesajınız',
      'send_message': 'Mesaj Gönder',
      'message_sent': 'Mesaj Gönderildi!',

      // Appointment filter buttons
      'all': 'Tümü',
      'past': 'Geçmiş',
      'confirmed': 'Onaylanan',

      // Sorting buttons
      'newest_to_oldest': 'Yeniden Eskiye',
      'oldest_to_newest': 'Eskiden Yeniye',

      // Menu buttons and card texts
      'book_appointment': 'Randevu Al',
      'view_services': 'Hizmetleri Görüntüle',
      'meet_team': 'Ekibimizle Tanışın',
      'view_gallery': 'Galeriyi Görüntüle',
      'menu_contact_us': 'Bize Ulaşın',
      'learn_more': 'Daha Fazla Bilgi',
      'read_more': 'Devamını Oku',
      'see_all': 'Tümünü Gör',
      'view_details': 'Detayları Görüntüle',

      // Card content texts
      'beauty_meets_serenity': 'Güzellik Huzurla Buluşuyor',
      'beauty_meets_serenity_desc':
          'Sirius\'ta, günlük hayatın koşuşturmasından huzurlu bir kaçamak yaratıyoruz. Huzurlu atmosferimiz ve uzman bakımımız, rahatlamanıza, yenilenmenize ve iç huzurunuzu yeniden keşfetmenize yardımcı olmak için tasarlanmıştır.',
      'your_beauty_our_galaxy': 'Güzelliğiniz, Galaksimiz',
      'your_beauty_our_galaxy_desc':
          'Yaptığımız her şeyin merkezinde siz varsınız. Kişiselleştirilmiş tedavilerimiz, benzersiz güzelliğinizi kutlar ve en kaliteli ürünler ve tekniklerle doğal parlaklığınızı artırır.',
      'glow_beyond_stars': 'Sirius ile Yıldızlardan Öteye Parlayın',
      'glow_beyond_stars_desc':
          'Sıradan güzellik bakımının ötesine geçerek kendinizi olağanüstü hissetmenizi sağlıyoruz. Sirius\'ta, her tedavi güvenle parlamanız için özenle hazırlanmıştır.',

      // About Us section
      'home_about_us': 'Hakkımızda',
      'home_about_us_description':
          'Sirius Beauty & Spa\'da, gerçek güzelliğin içten geldiğine inanıyoruz ve yıldız gibi parlamanıza yardım etmek için buradayız.',
      'about_us_subtitle':
          'Misyonumuz, en iyi görünmenizi ve hissetmenizi sağlamaktır.',
      'about_us_p1':
          'Sirius\'ta, güzelliğe olan tutkumuzu ileri tekniklerle birleştirerek üstün hizmetler sunuyoruz. Uzman ekibimiz, benzersiz ihtiyaçlarınıza göre kişiselleştirilmiş bir deneyim sunmaya adanmıştır.',
      'about_us_p2':
          'Saç şekillendirmeden makyaja ve rahatlatıcı spa uygulamalarına kadar yalnızca en kaliteli ürünleri kullanıyoruz. Salonumuza adım atın ve sizi ışıltı ve yenilenme yolculuğunda yönlendirelim.',

      // Our Services section
      'home_our_services': 'Hizmetlerimiz',
      'home_our_services_description':
          'En iyi görünmeniz ve hissetmeniz için geniş bir güzellik ve sağlık hizmetleri yelpazesi sunuyoruz.',

      // Hero section
      'hero_subtitle': 'Güzellik Salonu & Spa',
      'hero_tagline': 'Güzel Hisset, Sirius Ol',

      // Menu buttons
      'menu_book_appointment': 'Randevu Al',
      'menu_view_services': 'Hizmetleri Görüntüle',
      'menu_meet_team': 'Ekibimizle Tanışın',
      'menu_view_gallery': 'Galeriyi Görüntüle',

      // Service names
      'service_hair_cut': 'Saç Kesimi',
      'service_hair_styling': 'Saç Şekillendirme',
      'service_hair_coloring': 'Saç Boyama',
      'service_hair_treatment': 'Saç Bakımı',
      'service_manicure': 'Manikür',
      'service_pedicure': 'Pedikür',
      'service_facial': 'Cilt Bakımı',
      'service_massage': 'Masaj',

      // Footer additional texts
      'footer_website': 'Web Sitesi',
      'footer_working_hours_info': 'Pazartesi - Cumartesi: 07:00 - 23:00',
      'footer_phone_info': '+905348956232',
      'footer_email_info': 'gymOrion@gmail.com',
      'footer_address_info': 'İstanbul, Kadıköy, İstanbul 34744',

      // Additional error messages and notifications
      'passwords_do_not_match': 'Şifreler eşleşmiyor!',
      'photo_uploading': 'Fotoğraf yükleniyor...',
      'profile_photo_updated_success':
          'Profil fotoğrafı başarıyla güncellendi!',
      'photo_upload_error': 'Fotoğraf yüklenirken hata oluştu:',
      'profile_updated_success': 'Profil bilgileri başarıyla güncellendi!',
      'profile_update_error': 'Profil güncellenirken hata oluştu:',
      'logout_tooltip': 'Çıkış Yap',
      'appointments_loading': 'Randevular yükleniyor...',
      'my_appointments': 'Randevularım',
      'appointment_loading_error':
          'Randevu bilgileri yüklenirken bir hata oluştu. Lütfen tekrar deneyin.',
      'password_min_length': 'Şifre en az 6 karakter olmalı',
      'new_passwords_do_not_match': 'Yeni şifreler eşleşmiyor',
      'user_session_not_found': 'Kullanıcı oturumu bulunamadı',
      'current_password_incorrect': 'Mevcut şifre hatalı',
      'password_updated_success': 'Şifre başarıyla güncellendi',
      'password_update_error': 'Şifre güncellenemedi:',
      'not_specified': 'Belirtilmemiş',
      'cancel_appointment_confirm':
          'Bu randevuyu iptal etmek istediğinizden emin misiniz?',
      'customer_id_not_found': 'Müşteri ID bulunamadı',
      'appointment_cancelled_success': 'Randevu başarıyla iptal edildi',
      'logout_error': 'Çıkış yapılamadı:',
      'appointment_updated_success': 'Randevu başarıyla güncellendi',
      'appointment_update_error': 'Randevu güncellenemedi:',
      'profile_updated_success_alt': 'Profil bilgileri başarıyla güncellendi',
      'profile_update_error_alt': 'Profil güncellenemedi:',
      'appointment_could_not_be_created': 'Randevu oluşturulamadı',
      'business_id_resolving': 'İşletme ID çözümleniyor...',
      'business_id_value': 'İşletme ID:',
      'business_id_resolve_error': 'İşletme ID çözümleme hatası:',
      'business_id_already_exists': 'İşletme ID zaten mevcut:',
      'appointment_table_test_error': 'Randevu tablosu test hatası:',
      'main_appointment_query_running': 'Ana randevu sorgusu çalıştırılıyor...',
      'appointment_list_error': 'Randevu listesi hatası:',
      'appointment_status_changing':
          'Randevu durumu değiştiriliyor - Appointment ID:',
      'appointment_status_change_error':
          'Randevu durumu döngüsel olarak değiştirilirken hata:',
      'supabase_update_result': 'Supabase güncelleme sonucu:',
      'appointment_status_update_error': 'Randevu durumu güncellenirken hata:',
      'business_id_not_found_alt': 'İşletme ID bulunamadı',
      'employee_id_not_found': 'Çalışan ID bulunamadı',
      'user_not_found': 'Kullanıcı bulunamadı',
      'employee_not_found': 'Çalışan bulunamadı:',

      // Profile Info Dialog
      'profile_hero_tagline': 'Ana Başlık',
      'upload_logo': 'Logo Yükle',
      'delete_selected_appointments': 'Seçili Randevuları Sil',
      'delete_employee': 'Çalışan Sil',
      'delete_employee_confirm':
          'Bu çalışanı silmek istediğinizden emin misiniz?',
      'delete_past_activities': 'Geçmiş Aktiviteleri Sil',
      'delete_appointment': 'Randevuyu Sil',
      'bulk_delete': 'Toplu Silme',
      'bulk_delete_confirm': 'Toplu Sil',
      // Admin profile images & gallery
      'upload_hero_image': 'Hero Görseli Yükle',
      'about_us_image': 'Hakkımızda Görseli',
      'upload_about_image': 'Hakkımızda Görseli Yükle',
      'add_image_to_gallery': 'Galeriye Görsel Ekle',
      // Admin edit dialogs/buttons
      'add_event_image': 'Etkinlik Görseli Ekle',
      'select_image': 'Görsel Seç',
      'new_service': 'Yeni Hizmet',
      // Why choose us editable cards
      'card_1_title': 'Kart 1 Başlığı',
      'card_1_desc': 'Kart 1 Açıklaması',
      'card_2_title': 'Kart 2 Başlığı',
      'card_2_desc': 'Kart 2 Açıklaması',
      'card_3_title': 'Kart 3 Başlığı',
      'card_3_desc': 'Kart 3 Açıklaması',
      // New service dialog fields
      'category': 'Kategori',
      'duration': 'Süre',
      'price': 'Fiyat',
      'no_image_selected': 'Görsel seçilmedi',
      'image_ready': 'Görsel hazır',
      'add_new_service': 'Yeni Hizmet Ekle',
      'employee_name_hint': 'Çalışanın adı',
      'employee_surname_hint': 'Çalışanın soyadı',
      'email_hint': 'ornek@firma.com',
      'skills_hint': 'Örn: Boya, Kesim, Fön',
      'upload_photo': 'Fotoğraf Yükle',
      'change_photo': 'Fotoğrafı Değiştir',
      'first_name': 'Ad',
      'last_name': 'Soyad',
      'select_category': 'Kategori seçin',
      'add': 'Ekle',
      'select_photo': 'Fotoğraf Seç',
    },
  };
}

/// Supported application languages
enum AppLanguage { en, tr }

/// Extension to add translation method to BuildContext
extension LanguageExtension on BuildContext {
  String t(String key) {
    return Provider.of<LanguageProvider>(this, listen: false).t(key);
  }
}
