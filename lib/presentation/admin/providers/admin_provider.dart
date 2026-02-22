import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/admin_users_service.dart';
import '../../../core/services/admin_service.dart';
import '../data/mock_data.dart';

class AdminProvider extends ChangeNotifier {
  // Users screen state (API-backed)
  String _usersSearch = '';
  String _usersRoleFilter = 'all';
  String _usersPlanFilter = 'all';
  String _usersStatusFilter = 'all';
  int _usersPage = 0;
  static const int usersPerPage = 20;
  bool _usersLoading = false;
  String? _usersError;
  List<Map<String, dynamic>> _usersList = [];
  int _usersTotal = 0;
  int _usersTotalPages = 1;
  bool _usersActionLoading = false;
  Timer? _searchDebounce;
  String? Function()? _tokenGetter;
  
  // Dashboard state
  bool _dashboardLoading = false;
  String? _dashboardError;
  Map<String, dynamic>? _dashboardData;

  // Projects screen state
  String _projectsSearch = '';
  String _projectsStatusFilter = 'all';

  // Marketplace screen state
  String _marketplaceCategoryFilter = 'all';
  bool _marketplaceGridView = true;
  List<Map<String, dynamic>>? _templates;
  bool _templatesLoading = false;
  String? _templatesError;

  // Builds screen state
  String _buildsStatusFilter = 'all';

  // Getters
  String get usersSearch => _usersSearch;
  String get usersRoleFilter => _usersRoleFilter;
  String get usersPlanFilter => _usersPlanFilter;
  String get usersStatusFilter => _usersStatusFilter;
  int get usersPage => _usersPage;
  bool get usersLoading => _usersLoading;
  String? get usersError => _usersError;
  bool get usersActionLoading => _usersActionLoading;
  String get projectsSearch => _projectsSearch;
  String get projectsStatusFilter => _projectsStatusFilter;
  String get marketplaceCategoryFilter => _marketplaceCategoryFilter;
  bool get marketplaceGridView => _marketplaceGridView;
  List<Map<String, dynamic>>? get templates => _templates;
  bool get templatesLoading => _templatesLoading;
  String? get templatesError => _templatesError;
  String get buildsStatusFilter => _buildsStatusFilter;
  
  // Dashboard getters
  bool get dashboardLoading => _dashboardLoading;
  String? get dashboardError => _dashboardError;
  Map<String, dynamic>? get dashboardData => _dashboardData;

  // Users from API
  List<Map<String, dynamic>> get filteredUsers => _usersList;
  List<Map<String, dynamic>> get paginatedUsers => _usersList;
  int get usersTotalPages => _usersTotalPages;
  int get usersTotal => _usersTotal;
  bool get usersHasNextPage => _usersPage < usersTotalPages - 1;
  bool get usersHasPrevPage => _usersPage > 0;

  Future<void> fetchDashboard() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _dashboardError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _dashboardLoading = true;
    _dashboardError = null;
    notifyListeners();
    try {
      final res = await AdminService.getDashboard(token: token);
      if (res['success'] == true && res['data'] != null) {
        _dashboardData = res['data'] is Map 
          ? Map<String, dynamic>.from(res['data'] as Map) 
          : {};
        _dashboardError = null;
      } else {
        _dashboardData = null;
        _dashboardError = res['message']?.toString() ?? 'Failed to load dashboard';
      }
    } catch (e) {
      _dashboardData = null;
      _dashboardError = e.toString();

    } finally {
      _dashboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTemplates() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _templatesError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _templatesLoading = true;
    _templatesError = null;
    notifyListeners();
    try {
      final res = await AdminService.getTemplates(token: token);
      if (res['success'] == true && res['data'] != null) {
        _templates = (res['data'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
        _templatesError = null;
      } else {
        _templates = [];
        _templatesError = res['message']?.toString() ?? 'Failed to load templates';
      }
    } catch (e) {
      _templates = [];
      _templatesError = 'Error loading templates';
    } finally {
      _templatesLoading = false;
      notifyListeners();
    }
  }

  void setTokenGetter(String? Function() getter) {
    _tokenGetter = getter;
  }

  Future<void> fetchUsers() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _usersError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _usersLoading = true;
    _usersError = null;
    notifyListeners();
    try {
      final res = await AdminUsersService.getUsers(
        token: token,
        page: _usersPage + 1,
        limit: usersPerPage,
        search: _usersSearch.trim().isEmpty ? null : _usersSearch.trim(),
        status: _usersStatusFilter == 'all' ? null : _usersStatusFilter,
        role: _usersRoleFilter == 'all' ? null : _usersRoleFilter,
        subscription: _usersPlanFilter == 'all' ? null : _usersPlanFilter,
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] is Map ? res['data'] as Map : {};
        final users = data['users'] is List ? data['users'] as List : [];
        _usersList = users.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
        _usersTotal = (data['total'] is int) ? data['total'] as int : 0;
        _usersTotalPages = (data['totalPages'] is int) ? (data['totalPages'] as int).clamp(1, 999999) : 1;
        _usersError = null;
      } else {
        _usersList = [];
        _usersError = res['message']?.toString() ?? 'Failed to load users';
      }
    } catch (e) {
      _usersList = [];
      _usersError = e.toString();
    } finally {
      _usersLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserStatus(String id, String status) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;
    _usersActionLoading = true;
    notifyListeners();
    try {
      final res = await AdminUsersService.updateUserStatus(id: id, status: status, token: token);
      if (res['success'] == true) {
        await fetchUsers();
        return true;
      }
      return false;
    } finally {
      _usersActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String id) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;
    _usersActionLoading = true;
    notifyListeners();
    try {
      final res = await AdminUsersService.deleteUser(id, token);
      if (res['success'] == true) {
        await fetchUsers();
        return true;
      }
      return false;
    } finally {
      _usersActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> exportUsersCsv() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;
    return AdminUsersService.downloadCsv(
      token: token,
      search: _usersSearch.trim().isEmpty ? null : _usersSearch.trim(),
      status: _usersStatusFilter == 'all' ? null : _usersStatusFilter,
      role: _usersRoleFilter == 'all' ? null : _usersRoleFilter,
      subscription: _usersPlanFilter == 'all' ? null : _usersPlanFilter,
    );
  }

  void _debouncedFetchUsers() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      fetchUsers();
    });
  }

  // Filtered projects
  List<Map<String, dynamic>> get filteredProjects {
    var list = List<Map<String, dynamic>>.from(AdminMockData.mockProjects);

    if (_projectsSearch.isNotEmpty) {
      final q = _projectsSearch.toLowerCase();
      list = list.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final owner = (p['owner'] ?? '').toString().toLowerCase();
        return title.contains(q) || owner.contains(q);
      }).toList();
    }

    if (_projectsStatusFilter != 'all') {
      list = list.where((p) => (p['status'] ?? '').toString() == _projectsStatusFilter).toList();
    }

    return list;
  }

  // Filtered templates
  List<Map<String, dynamic>> get filteredTemplates {
    var list = List<Map<String, dynamic>>.from(_templates ?? []);

    if (_marketplaceCategoryFilter != 'all') {
      list = list.where((t) => (t['category'] ?? '').toString().toLowerCase() == _marketplaceCategoryFilter.toLowerCase()).toList();
    }

    return list;
  }

  // Filtered builds
  List<Map<String, dynamic>> get filteredBuilds {
    var list = List<Map<String, dynamic>>.from(AdminMockData.mockBuilds);

    if (_buildsStatusFilter != 'all') {
      list = list.where((b) => (b['status'] ?? '').toString() == _buildsStatusFilter).toList();
    }

    return list;
  }

  // Setters
  void setUsersSearch(String value) {
    _usersSearch = value;
    _usersPage = 0;
    notifyListeners();
    _debouncedFetchUsers();
  }

  void setUsersRoleFilter(String value) {
    _usersRoleFilter = value;
    _usersPage = 0;
    notifyListeners();
    fetchUsers();
  }

  void setUsersPlanFilter(String value) {
    _usersPlanFilter = value;
    _usersPage = 0;
    notifyListeners();
    fetchUsers();
  }

  void setUsersStatusFilter(String value) {
    _usersStatusFilter = value;
    _usersPage = 0;
    notifyListeners();
    fetchUsers();
  }

  void setUsersPage(int page) {
    final max = (usersTotalPages - 1).clamp(0, 999);
    _usersPage = page.clamp(0, max);
    notifyListeners();
    fetchUsers();
  }

  void nextUsersPage() {
    if (usersHasNextPage) {
      _usersPage++;
      notifyListeners();
      fetchUsers();
    }
  }

  void prevUsersPage() {
    if (usersHasPrevPage) {
      _usersPage--;
      notifyListeners();
      fetchUsers();
    }
  }

  void setProjectsSearch(String value) {
    _projectsSearch = value;
    notifyListeners();
  }

  void setProjectsStatusFilter(String value) {
    _projectsStatusFilter = value;
    notifyListeners();
  }

  void setMarketplaceCategoryFilter(String value) {
    _marketplaceCategoryFilter = value;
    notifyListeners();
  }

  void setMarketplaceGridView(bool value) {
    _marketplaceGridView = value;
    notifyListeners();
  }

  void setBuildsStatusFilter(String value) {
    _buildsStatusFilter = value;
    notifyListeners();
  }
}
