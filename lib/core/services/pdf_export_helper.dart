import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportHelper {
  // GameForge AI theme colors
  static const _primaryColor = PdfColor.fromInt(0xFF00FFF7); // Neon cyan
  static const _backgroundColor = PdfColor.fromInt(0xFF0A0E27); // Dark blue
  static const _secondaryBg = PdfColor.fromInt(0xFF141B3D); // Lighter dark blue
  static const _textPrimary = PdfColor.fromInt(0xFFE8EAF6); // Light text
  static const _textSecondary = PdfColor.fromInt(0xFF9CA3BE); // Gray text
  static const _accentRed = PdfColor.fromInt(0xFFFF4757);
  static const _accentGreen = PdfColor.fromInt(0xFF2ED573);

  /// Generate a themed PDF for users export
  static Future<Uint8List> generateUsersPdf({
    required List<Map<String, dynamic>> users,
    String? search,
    String? status,
    String? role,
    String? subscription,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.rajdhaniRegular();
    final fontBold = await PdfGoogleFonts.rajdhaniBold();
    final logoFont = await PdfGoogleFonts.orbitronBold();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: fontBold,
          ),
          buildBackground: (context) {
            return pw.Container(
              decoration: const pw.BoxDecoration(
                color: _backgroundColor,
              ),
            );
          },
        ),
        build: (context) => [
          // Header with branding
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'GAMEFORGE AI',
                      style: pw.TextStyle(
                        font: logoFont,
                        fontSize: 24,
                        color: _primaryColor,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Users Report',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 16,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: ${DateTime.now().toString().substring(0, 19)}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Total Users: ${users.length}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Filters applied (if any)
          if (search != null || status != null || role != null || subscription != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _secondaryBg,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Filters Applied:',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color: _textPrimary,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (search != null)
                        _buildFilterChip('Search: $search', font),
                      if (status != null)
                        _buildFilterChip('Status: $status', font),
                      if (role != null)
                        _buildFilterChip('Role: $role', font),
                      if (subscription != null)
                        _buildFilterChip('Plan: $subscription', font),
                    ],
                  ),
                ],
              ),
            ),
          if (search != null || status != null || role != null || subscription != null)
            pw.SizedBox(height: 20),

          // Table
          pw.Table(
            border: pw.TableBorder.all(
              color: _secondaryBg,
              width: 1,
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: _secondaryBg,
                ),
                children: [
                  _buildHeaderCell('#', fontBold),
                  _buildHeaderCell('Name', fontBold),
                  _buildHeaderCell('Email', fontBold),
                  _buildHeaderCell('Role', fontBold),
                  _buildHeaderCell('Status', fontBold),
                  _buildHeaderCell('Joined', fontBold),
                ],
              ),
              // Data rows
              ...users.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;
                final isEven = index % 2 == 0;
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? _backgroundColor : const PdfColor.fromInt(0xFF1A2347),
                  ),
                  children: [
                    _buildDataCell((index + 1).toString(), font),
                    _buildDataCell(user['name']?.toString() ?? '-', font),
                    _buildDataCell(user['email']?.toString() ?? '-', font),
                    _buildDataCell(user['role']?.toString() ?? '-', font),
                    _buildStatusCell(user['status']?.toString() ?? 'inactive', font),
                    _buildDataCell(_formatDate(user['createdAt']), font),
                  ],
                );
              }).toList(),
            ],
          ),

          pw.SizedBox(height: 30),

          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _secondaryBg, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'GameForge AI - Admin Dashboard',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: _textSecondary,
                  ),
                ),
                pw.Text(
                  'Confidential',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: _accentRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildFilterChip(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF1A3A3A),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: _primaryColor, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: _primaryColor,
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 11,
          color: _primaryColor,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: _textPrimary,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _buildStatusCell(String status, pw.Font font) {
    PdfColor color;
    switch (status.toLowerCase()) {
      case 'active':
        color = _accentGreen;
        break;
      case 'inactive':
        color = _textSecondary;
        break;
      case 'banned':
        color = _accentRed;
        break;
      default:
        color = _textSecondary;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _secondaryBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: color, width: 0.5),
        ),
        child: pw.Text(
          status.toUpperCase(),
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            color: color,
          ),
        ),
      ),
    );
  }

  static String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }
}
