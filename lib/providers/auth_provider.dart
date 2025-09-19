import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/employee.dart';

class AuthProvider extends ChangeNotifier {
  Customer? _currentCustomer;
  Employee? _currentEmployee;
  bool _isAuthenticated = false;
  bool _isAdmin = false;

  Customer? get currentCustomer => _currentCustomer;
  Employee? get currentEmployee => _currentEmployee;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _isAdmin;

  void setCustomer(Customer customer) {
    _currentCustomer = customer;
    _currentEmployee = null;
    _isAuthenticated = true;
    _isAdmin = false;
    notifyListeners();
  }

  void setEmployee(Employee employee, bool isAdmin) {
    _currentEmployee = employee;
    _currentCustomer = null;
    _isAuthenticated = true;
    _isAdmin = isAdmin;
    notifyListeners();
  }

  // Customer login sonrası state güncelleme
  void loginCustomer(Customer customer) {
    setCustomer(customer);
  }

  // Admin login sonrası state güncelleme
  void loginAdmin(Employee employee) {
    setEmployee(employee, true);
  }

  void logout() {
    _currentCustomer = null;
    _currentEmployee = null;
    _isAuthenticated = false;
    _isAdmin = false;
    notifyListeners();
  }

  void updateCustomer(Customer updatedCustomer) {
    _currentCustomer = updatedCustomer;
    notifyListeners();
  }
}
