import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';

class AdminDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<Widget>? Function(int rowIndex)? actionsBuilder;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.actionsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AdminTheme.bgTertiary),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) return AdminTheme.bgTertiary.withOpacity(0.5);
              return Colors.transparent;
            }),
            columns: [
              ...columns.map((c) => DataColumn(
                label: Text(
                  c,
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textSecondary,
                  ),
                ),
              )),
              if (actionsBuilder != null)
                const DataColumn(label: SizedBox(width: 120)),
            ],
            rows: rows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return DataRow(
                cells: [
                  ...row.map((cell) => DataCell(cell)),
                  if (actionsBuilder != null)
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actionsBuilder!(i) ?? [],
                    )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
