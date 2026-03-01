import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/services/admin_users_service.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/pdf_export_helper.dart';

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
  List<Map<String, dynamic>> _projects = [];
  bool _projectsLoading = false;
  String? _projectsError;
  int _projectsPage = 0;
  static const int projectsPerPage = 12;

  // Marketplace screen state
  String _marketplaceCategoryFilter = 'all';
  bool _marketplaceGridView = true;
  List<Map<String, dynamic>>? _templates;
  bool _templatesLoading = false;
  String? _templatesError;
  int _templatesPage = 0;
  static const int templatesPerPage = 16;
  bool _uploadingTemplate = false;

  // Builds screen state
  String _buildsStatusFilter = 'all';
  String _buildsSearch = '';
  List<Map<String, dynamic>> _builds = [];
  Map<String, dynamic> _buildsSummary = {};
  bool _buildsLoading = false;
  String? _buildsError;
  int _buildsPage = 0;
  static const int buildsPerPage = 20;

  // Recent activity state
  List<Map<String, dynamic>> _recentActivity = [];
  bool _activityLoading = false;
  String? _activityError;

  // System status state
  List<Map<String, dynamic>> _systemStatus = [];
  bool _systemStatusLoading = false;
  String? _systemStatusError;

  // Notifications history state
  List<Map<String, dynamic>> _notificationsHistory = [];
  bool _notificationsHistoryLoading = false;
  String? _notificationsHistoryError;

  // AI Insights state
  String _aiInsightsSummary = '';
  bool _aiInsightsLoading = false;
  String? _aiInsightsError;

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
  bool get projectsLoading => _projectsLoading;
  String? get projectsError => _projectsError;
  List<Map<String, dynamic>> get projects => _projects;
  String get marketplaceCategoryFilter => _marketplaceCategoryFilter;
  bool get marketplaceGridView => _marketplaceGridView;
  List<Map<String, dynamic>>? get templates => _templates;
  bool get templatesLoading => _templatesLoading;
  String? get templatesError => _templatesError;
  bool get uploadingTemplate => _uploadingTemplate;
  String get buildsStatusFilter => _buildsStatusFilter;
  String get buildsSearch => _buildsSearch;
  List<Map<String, dynamic>> get builds => _builds;
  Map<String, dynamic> get buildsSummary => _buildsSummary;
  bool get buildsLoading => _buildsLoading;
  String? get buildsError => _buildsError;
  
  List<Map<String, dynamic>> get recentActivity => _recentActivity;
  bool get activityLoading => _activityLoading;
  String? get activityError => _activityError;

  List<Map<String, dynamic>> get systemStatus => _systemStatus;
  bool get systemStatusLoading => _systemStatusLoading;
  String? get systemStatusError => _systemStatusError;

  List<Map<String, dynamic>> get notificationsHistory => _notificationsHistory;
  bool get notificationsHistoryLoading => _notificationsHistoryLoading;
  String? get notificationsHistoryError => _notificationsHistoryError;

  String get aiInsightsSummary => _aiInsightsSummary;
  bool get aiInsightsLoading => _aiInsightsLoading;
  String? get aiInsightsError => _aiInsightsError;

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

  /// Upload a new template - returns true on success, false on failure
  /// Uses Uint8List for web compatibility
  Future<bool> uploadTemplate({
    required Uint8List zipFileBytes,
    required String zipFileName,
    String? name,
    String? description,
    String? category,
    String? tags,
    String? price,
    Uint8List? previewImageBytes,
    String? previewImageFileName,
    List<Uint8List>? screenshotsBytes,
    List<String>? screenshotFileNames,
  }) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      return false;
    }
    _uploadingTemplate = true;
    notifyListeners();
    try {
      final res = await AdminService.uploadTemplate(
        token: token,
        zipFileBytes: zipFileBytes,
        zipFileName: zipFileName,
        name: name,
        description: description,
        category: category,
        tags: tags,
        price: price,
        previewImageBytes: previewImageBytes,
        previewImageFileName: previewImageFileName,
        screenshotsBytes: screenshotsBytes,
        screenshotFileNames: screenshotFileNames,
      );
      if (res['success'] == true) {
        // Refresh templates list after successful upload
        await fetchTemplates();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _uploadingTemplate = false;
      notifyListeners();
    }
  }

  /// Edit an existing template - returns true on success, false on failure
  /// Uses Uint8List for web compatibility
  Future<bool> editTemplate({
    required String templateId,
    Uint8List? zipFileBytes,
    String? zipFileName,
    String? name,
    String? description,
    String? category,
    String? tags,
    String? price,
    Uint8List? previewImageBytes,
    String? previewImageFileName,
    List<Uint8List>? screenshotsBytes,
    List<String>? screenshotFileNames,
  }) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      return false;
    }
    _uploadingTemplate = true;
    notifyListeners();
    try {
      final res = await AdminService.updateTemplate(
        token: token,
        templateId: templateId,
        zipFileBytes: zipFileBytes,
        zipFileName: zipFileName,
        name: name,
        description: description,
        category: category,
        tags: tags,
        price: price,
        previewImageBytes: previewImageBytes,
        previewImageFileName: previewImageFileName,
        screenshotsBytes: screenshotsBytes,
        screenshotFileNames: screenshotFileNames,
      );
      if (res['success'] == true) {
        // Refresh templates list after successful update
        await fetchTemplates();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _uploadingTemplate = false;
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
    
    try {
      // Generate PDF with current users data
      final pdfBytes = await PdfExportHelper.generateUsersPdf(
        users: paginatedUsers,
        search: _usersSearch.trim().isEmpty ? null : _usersSearch.trim(),
        status: _usersStatusFilter == 'all' ? null : _usersStatusFilter,
        role: _usersRoleFilter == 'all' ? null : _usersRoleFilter,
        subscription: _usersPlanFilter == 'all' ? null : _usersPlanFilter,
      );
      
      // Download the PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'gameforge_users_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      
      return true;
    } catch (e) {
      print('PDF export error: $e');
      return false;
    }
  }

  void _debouncedFetchUsers() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      fetchUsers();
    });
  }

  // Filtered projects (excludes archived)
  List<Map<String, dynamic>> get filteredProjects {
    var list = List<Map<String, dynamic>>.from(_projects);
    
    // Always exclude archived projects from the main list
    list = list.where((p) => (p['status'] ?? '').toString() != 'archived').toList();

    if (_projectsSearch.isNotEmpty) {
      final q = _projectsSearch.toLowerCase();
      list = list.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final ownerDisplay = (p['ownerDisplay'] ?? '').toString().toLowerCase();
        return name.contains(q) || ownerDisplay.contains(q);
      }).toList();
    }

    if (_projectsStatusFilter != 'all') {
      list = list.where((p) => (p['status'] ?? '').toString() == _projectsStatusFilter).toList();
    }

    return list;
  }

  // Paginated projects
  List<Map<String, dynamic>> get paginatedProjects {
    final all = filteredProjects;
    final start = _projectsPage * projectsPerPage;
    final end = (start + projectsPerPage).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get projectsTotalPages => (filteredProjects.length / projectsPerPage).ceil().clamp(1, double.infinity).toInt();
  int get projectsCurrentPage => _projectsPage + 1;
  bool get projectsHasNextPage => _projectsPage < projectsTotalPages - 1;
  bool get projectsHasPrevPage => _projectsPage > 0;

  void setProjectsPage(int page) {
    _projectsPage = page.clamp(0, projectsTotalPages - 1);
    notifyListeners();
  }

  void nextProjectsPage() {
    if (projectsHasNextPage) {
      _projectsPage++;
      notifyListeners();
    }
  }

  void prevProjectsPage() {
    if (projectsHasPrevPage) {
      _projectsPage--;
      notifyListeners();
    }
  }

  Future<void> fetchProjects() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _projectsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _projectsLoading = true;
    _projectsError = null;
    notifyListeners();
    try {
      final res = await AdminService.getAdminProjects(token: token);
      if (res['success'] == true && res['data'] is List) {
        _projects = List<Map<String, dynamic>>.from(res['data'] as List);
        _projectsError = null;
      } else {
        _projects = [];
        _projectsError = res['message']?.toString() ?? 'Failed to load projects';
      }
    } catch (e) {
      _projects = [];
      _projectsError = e.toString();
    } finally {
      _projectsLoading = false;
      notifyListeners();
    }
  }

  // Filtered templates
  List<Map<String, dynamic>> get filteredTemplates {
    var list = List<Map<String, dynamic>>.from(_templates ?? []);

    if (_marketplaceCategoryFilter != 'all') {
      list = list.where((t) => (t['category'] ?? '').toString().toLowerCase() == _marketplaceCategoryFilter.toLowerCase()).toList();
    }

    return list;
  }

  // Paginated templates
  List<Map<String, dynamic>> get paginatedTemplates {
    final all = filteredTemplates;
    final start = _templatesPage * templatesPerPage;
    final end = (start + templatesPerPage).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get templatesTotalPages => (filteredTemplates.length / templatesPerPage).ceil().clamp(1, double.infinity).toInt();
  int get templatesCurrentPage => _templatesPage + 1;
  bool get templatesHasNextPage => _templatesPage < templatesTotalPages - 1;
  bool get templatesHasPrevPage => _templatesPage > 0;

  void setTemplatesPage(int page) {
    _templatesPage = page.clamp(0, templatesTotalPages - 1);
    notifyListeners();
  }

  void nextTemplatesPage() {
    if (templatesHasNextPage) {
      _templatesPage++;
      notifyListeners();
    }
  }

  void prevTemplatesPage() {
    if (templatesHasPrevPage) {
      _templatesPage--;
      notifyListeners();
    }
  }

  // Filtered builds
  List<Map<String, dynamic>> get filteredBuilds {
    var list = List<Map<String, dynamic>>.from(_builds);

    // Always exclude archived builds from the list
    list = list.where((b) => (b['status'] ?? '').toString() != 'archived').toList();

    if (_buildsSearch.isNotEmpty) {
      final q = _buildsSearch.toLowerCase();
      list = list.where((b) {
        final name = (b['name'] ?? '').toString().toLowerCase();
        final ownerDisplay = (b['ownerDisplay'] ?? '').toString().toLowerCase();
        return name.contains(q) || ownerDisplay.contains(q);
      }).toList();
    }

    if (_buildsStatusFilter != 'all') {
      list = list.where((b) => (b['status'] ?? '').toString() == _buildsStatusFilter).toList();
    }

    return list;
  }

  // Paginated builds
  List<Map<String, dynamic>> get paginatedBuilds {
    final all = filteredBuilds;
    final start = _buildsPage * buildsPerPage;
    final end = (start + buildsPerPage).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get buildsTotalPages => (filteredBuilds.length / buildsPerPage).ceil().clamp(1, double.infinity).toInt();
  int get buildsCurrentPage => _buildsPage + 1;
  bool get buildsHasNextPage => _buildsPage < buildsTotalPages - 1;
  bool get buildsHasPrevPage => _buildsPage > 0;

  void setBuildsPage(int page) {
    _buildsPage = page.clamp(0, buildsTotalPages - 1);
    notifyListeners();
  }

  void nextBuildsPage() {
    if (buildsHasNextPage) {
      _buildsPage++;
      notifyListeners();
    }
  }

  void prevBuildsPage() {
    if (buildsHasPrevPage) {
      _buildsPage--;
      notifyListeners();
    }
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
    _projectsPage = 0;
    notifyListeners();
  }

  void setProjectsStatusFilter(String value) {
    _projectsStatusFilter = value;
    _projectsPage = 0;
    notifyListeners();
  }

  void setMarketplaceCategoryFilter(String value) {
    _marketplaceCategoryFilter = value;
    _templatesPage = 0;
    notifyListeners();
  }

  void setMarketplaceGridView(bool value) {
    _marketplaceGridView = value;
    notifyListeners();
  }

  void setBuildsStatusFilter(String value) {
    _buildsStatusFilter = value;
    _buildsPage = 0;
    notifyListeners();
  }

  void setBuildsSearch(String value) {
    _buildsSearch = value;
    _buildsPage = 0;
    notifyListeners();
  }

  Future<void> fetchBuilds() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _buildsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _buildsLoading = true;
    _buildsError = null;
    notifyListeners();
    try {
      final res = await AdminService.getAdminBuilds(token: token);
      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map;
        if (data['builds'] is List) {
          _builds = List<Map<String, dynamic>>.from(data['builds'] as List);
        }
        if (data['summary'] is Map) {
          _buildsSummary = Map<String, dynamic>.from(data['summary'] as Map);
        }
        _buildsError = null;
      } else {
        _builds = [];
        _buildsSummary = {};
        _buildsError = res['message']?.toString() ?? 'Failed to load builds';
      }
    } catch (e) {
      _builds = [];
      _buildsSummary = {};
      _buildsError = e.toString();
    } finally {
      _buildsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRecentActivity() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _activityError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _activityLoading = true;
    _activityError = null;
    notifyListeners();
    try {
      final res = await AdminService.getAdminActivity(token: token);
      if (res['success'] == true && res['data'] is List) {
        _recentActivity = List<Map<String, dynamic>>.from(res['data'] as List);
        _activityError = null;
      } else {
        _recentActivity = [];
        _activityError = res['message']?.toString() ?? 'Failed to load activity';
      }
    } catch (e) {
      _recentActivity = [];
      _activityError = e.toString();
    } finally {
      _activityLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSystemStatus() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _systemStatusError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _systemStatusLoading = true;
    _systemStatusError = null;
    notifyListeners();
    try {
      final res = await AdminService.getSystemStatus(token: token);
      if (res['success'] == true && res['data'] is List) {
        _systemStatus = List<Map<String, dynamic>>.from(res['data'] as List);
        _systemStatusError = null;
      } else {
        _systemStatus = [];
        _systemStatusError = res['message']?.toString() ?? 'Failed to load system status';
      }
    } catch (e) {
      _systemStatus = [];
      _systemStatusError = e.toString();
    } finally {
      _systemStatusLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNotificationsHistory() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _notificationsHistoryError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _notificationsHistoryLoading = true;
    _notificationsHistoryError = null;
    notifyListeners();
    try {
      final res = await AdminService.getNotificationsHistory(token: token);
      if (res['success'] == true && res['data'] is List) {
        _notificationsHistory = List<Map<String, dynamic>>.from(res['data'] as List);
        _notificationsHistoryError = null;
      } else {
        _notificationsHistory = [];
        _notificationsHistoryError = res['message']?.toString() ?? 'Failed to load notifications';
      }
    } catch (e) {
      _notificationsHistory = [];
      _notificationsHistoryError = e.toString();
    } finally {
      _notificationsHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateAiInsights() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) {
      _aiInsightsError = 'Not authenticated';
      notifyListeners();
      return;
    }
    _aiInsightsLoading = true;
    _aiInsightsError = null;
    notifyListeners();
    try {
      final res = await AdminService.generateAiInsights(token: token);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map;
        _aiInsightsSummary = data['summary']?.toString() ?? 'Unable to generate insights';
        _aiInsightsError = null;
      } else {
        _aiInsightsSummary = '';
        _aiInsightsError = res['message']?.toString() ?? 'Failed to generate insights';
      }
    } catch (e) {
      _aiInsightsSummary = '';
      _aiInsightsError = e.toString();
    } finally {
      _aiInsightsLoading = false;
      notifyListeners();
    }
  }

  /// Generate AI description for a template
  Future<String?> generateAiDescription({
    required String name,
    required String category,
    String? tags,
  }) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await AdminService.generateAiDescription(
        token: token,
        name: name,
        category: category,
        tags: tags,
      );
      
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map;
        return data['description']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Analyze a build error with AI
  Future<Map<String, dynamic>?> analyzeAiBuildError({
    required String errorMessage,
    String? buildTarget,
    String? projectName,
  }) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await AdminService.analyzeAiBuildError(
        token: token,
        errorMessage: errorMessage,
        buildTarget: buildTarget,
        projectName: projectName,
      );
      
      if (res['success'] == true && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Send real-time notification to users
  Future<bool> sendRealtimeNotification({
    required String title,
    required String message,
    required String target,
  }) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;

    try {
      final res = await AdminService.sendRealtimeNotification(
        token: token,
        title: title,
        message: message,
        target: target,
      );

      if (res['success'] == true) {
        // Refresh notifications history after sending
        await fetchNotificationsHistory();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // FIX 1: Hide project from dashboard
  Future<bool> hideProject(String projectId) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;

    try {
      final res = await AdminService.hideProject(token: token, projectId: projectId);
      if (res['success'] == true) {
        // Remove from local list
        _projects.removeWhere((p) => p['_id'].toString() == projectId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // FIX 2: Archive project
  Future<bool> archiveProject(String projectId) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;

    try {
      final res = await AdminService.archiveProject(token: token, projectId: projectId);
      if (res['success'] == true) {
        // Update status in local list
        final index = _projects.indexWhere((p) => p['_id'].toString() == projectId);
        if (index != -1) {
          _projects[index]['status'] = 'archived';
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Unarchive project (restore from archive)
  Future<bool> unarchiveProject(String projectId) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;

    try {
      // Call the unarchive endpoint to restore previous status
      final res = await AdminService.unarchiveProject(token: token, projectId: projectId);
      if (res['success'] == true) {
        // Update status in local list with the restored status
        final index = _projects.indexWhere((p) => p['_id'].toString() == projectId);
        if (index != -1) {
          // Use the status returned by backend or default to 'ready'
          final restoredStatus = res['status']?.toString() ?? 'ready';
          _projects[index]['status'] = restoredStatus;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // FIX 3: Toggle template
  Future<bool> toggleTemplate(String templateId) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return false;

    try {
      final res = await AdminService.toggleTemplate(token: token, templateId: templateId);
      if (res['success'] == true) {
        // Update local template immediately with the new isActive status
        if (_templates != null) {
          final index = _templates!.indexWhere((t) => t['_id'].toString() == templateId);
          if (index != -1 && res['isActive'] != null) {
            _templates![index]['isActive'] = res['isActive'];
            notifyListeners();
          }
        }
        // Refresh templates list to ensure consistency
        await fetchTemplates();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // FIX 4: Get build logs
  Future<String?> getBuildLogs(String buildId) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await AdminService.getBuildLogs(token: token, buildId: buildId);
      if (res['success'] == true && res['data'] != null) {
        return res['data']['logs'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // FIX 6: Revoke all sessions
  Future<Map<String, dynamic>?> revokeAllSessions() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await AdminService.revokeAllSessions(token: token);
      if (res['success'] == true) {
        return res;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // FIX 7: Health metrics state
  Map<String, dynamic>? _healthMetrics;
  bool _healthLoading = false;
  
  Map<String, dynamic>? get healthMetrics => _healthMetrics;
  bool get healthLoading => _healthLoading;

  Future<void> fetchHealthMetrics() async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return;

    _healthLoading = true;
    notifyListeners();

    try {
      final res = await AdminService.getHealthMetrics(token: token);
      if (res['success'] == true && res['data'] != null) {
        _healthMetrics = res['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      _healthMetrics = null;
    }

    _healthLoading = false;
    notifyListeners();
  }

  // FIX 8: AI Search
  Future<Map<String, dynamic>?> aiSearch(String query) async {
    final token = _tokenGetter?.call();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await AdminService.aiSearch(token: token, query: query);
      if (res['success'] == true && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
