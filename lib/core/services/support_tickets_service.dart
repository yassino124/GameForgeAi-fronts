import 'api_service.dart';

class SupportTicketsService {
  static Future<Map<String, dynamic>> listMyTickets({
    required String token,
  }) {
    return ApiService.get('/support/tickets/me', token: token);
  }

  static Future<Map<String, dynamic>> listTickets({
    required String token,
    String? status,
    String? priority,
    String? q,
  }) {
    final qp = <String, String>{
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (priority != null && priority.trim().isNotEmpty)
        'priority': priority.trim(),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };

    final uri = Uri(path: '/support/tickets', queryParameters: qp.isEmpty ? null : qp);
    return ApiService.get(uri.toString(), token: token);
  }

  static Future<Map<String, dynamic>> createTicket({
    required String token,
    required String subject,
    required String body,
    String? category,
    String priority = 'normal',
    List<Map<String, dynamic>> attachments = const [],
  }) {
    return ApiService.post(
      '/support/tickets',
      token: token,
      data: {
        'subject': subject.trim(),
        'body': body.trim(),
        'priority': priority,
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
  }

  static Future<Map<String, dynamic>> getTicket({
    required String token,
    required String ticketId,
  }) {
    return ApiService.get('/support/tickets/$ticketId', token: token);
  }

  static Future<Map<String, dynamic>> listMessages({
    required String token,
    required String ticketId,
  }) {
    return ApiService.get('/support/tickets/$ticketId/messages', token: token);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String token,
    required String ticketId,
    required String body,
    String? macroKey,
    List<Map<String, dynamic>> attachments = const [],
  }) {
    return ApiService.post(
      '/support/tickets/$ticketId/messages',
      token: token,
      data: {
        'body': body.trim(),
        if (macroKey != null && macroKey.trim().isNotEmpty) 'macroKey': macroKey,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );
  }

  static Future<Map<String, dynamic>> updateTicket({
    required String token,
    required String ticketId,
    required String status,
    String? priority,
  }) {
    return ApiService.patch(
      '/support/tickets/$ticketId/status',
      token: token,
      data: {
        'status': status,
        if (priority != null && priority.trim().isNotEmpty)
          'priority': priority.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> assignMe({
    required String token,
    required String ticketId,
  }) {
    return ApiService.patch('/support/tickets/$ticketId/assign-me', token: token);
  }

  static Future<Map<String, dynamic>> listMacros({
    required String token,
  }) {
    return ApiService.get('/support/macros', token: token);
  }
}
