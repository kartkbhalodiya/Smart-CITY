import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/complaint_service.dart';

class CategoryProvider with ChangeNotifier {
  List<Category> _categories = [];
  List<Subcategory> _subcategories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => _categories;
  List<Subcategory> get subcategories => _subcategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();

    final response = await ComplaintService.getCategories();

    _isLoading = false;
    if (response['success'] == true) {
      final categoriesData = response['categories'] ?? [];
      _categories = (categoriesData as List)
          .map((json) => Category.fromJson(json))
          .toList();
    } else {
      _error = response['message'];
    }
    notifyListeners();
  }

  Future<void> loadSubcategories(String categoryKey) async {
    _isLoading = true;
    notifyListeners();

    final response = await ComplaintService.getSubcategories(categoryKey);

    _isLoading = false;
    if (response['success'] == true) {
      final subcategoriesData = response['subcategories'] ?? [];
      _subcategories = (subcategoriesData as List)
          .map((json) => Subcategory.fromJson(json))
          .toList();
    } else {
      _error = response['message'];
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
