import 'package:flutter/material.dart';
import '../data/mock_data.dart';

class AdminProvider extends ChangeNotifier {
  // Users screen state
  String _usersSearch = '';
  String _usersRoleFilter = 'all';
  String _usersPlanFilter = 'all';
  int _usersPage = 0;
  static const int usersPerPage = 10;

  // Projects screen state
  String _projectsSearch = '';
  String _projectsStatusFilter = 'all';

  // Marketplace screen state
  String _marketplaceCategoryFilter = 'all';
  bool _marketplaceGridView = true;

  // Builds screen state
  String _buildsStatusFilter = 'all';

  // Getters
  String get usersSearch => _usersSearch;
  String get usersRoleFilter => _usersRoleFilter;
  String get usersPlanFilter => _usersPlanFilter;
  int get usersPage => _usersPage;
  String get projectsSearch => _projectsSearch;
  String get projectsStatusFilter => _projectsStatusFilter;
  String get marketplaceCategoryFilter => _marketplaceCategoryFilter;
  bool get marketplaceGridView => _marketplaceGridView;
  String get buildsStatusFilter => _buildsStatusFilter;

  // Filtered users
  List<Map<String, dynamic>> get filteredUsers {
    var list = List<Map<String, dynamic>>.from(AdminMockData.mockUsers);

    if (_usersSearch.isNotEmpty) {
      final q = _usersSearch.toLowerCase();
      list = list.where((u) {
        final username = (u['username'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return username.contains(q) || email.contains(q);
      }).toList();
    }

    if (_usersRoleFilter != 'all') {
      list = list.where((u) => (u['role'] ?? '').toString().toLowerCase() == _usersRoleFilter).toList();
    }

    if (_usersPlanFilter != 'all') {
      list = list.where((u) => (u['subscription'] ?? '').toString().toLowerCase() == _usersPlanFilter).toList();
    }

    return list;
  }

  List<Map<String, dynamic>> get paginatedUsers {
    final filtered = filteredUsers;
    final start = _usersPage * usersPerPage;
    final end = (start + usersPerPage).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  int get usersTotalPages => (filteredUsers.length / usersPerPage).ceil();
  bool get usersHasNextPage => _usersPage < usersTotalPages - 1;
  bool get usersHasPrevPage => _usersPage > 0;

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
    var list = List<Map<String, dynamic>>.from(AdminMockData.mockTemplates);

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

  // Toggle user active state (local mock)
  final Set<String> _toggledUserIds = {};

  bool isUserActive(String id) {
    final user = AdminMockData.mockUsers.firstWhere((u) => u['id'] == id, orElse: () => {});
    final baseActive = user['isActive'] == true;
    if (_toggledUserIds.contains(id)) {
      return !baseActive;
    }
    return baseActive;
  }

  void toggleUserActive(String id) {
    _toggledUserIds.contains(id) ? _toggledUserIds.remove(id) : _toggledUserIds.add(id);
    notifyListeners();
  }

  // Setters
  void setUsersSearch(String value) {
    _usersSearch = value;
    _usersPage = 0;
    notifyListeners();
  }

  void setUsersRoleFilter(String value) {
    _usersRoleFilter = value;
    _usersPage = 0;
    notifyListeners();
  }

  void setUsersPlanFilter(String value) {
    _usersPlanFilter = value;
    _usersPage = 0;
    notifyListeners();
  }

  void setUsersPage(int page) {
    final max = (usersTotalPages - 1).clamp(0, 999);
    _usersPage = page.clamp(0, max);
    notifyListeners();
  }

  void nextUsersPage() {
    if (usersHasNextPage) {
      _usersPage++;
      notifyListeners();
    }
  }

  void prevUsersPage() {
    if (usersHasPrevPage) {
      _usersPage--;
      notifyListeners();
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
