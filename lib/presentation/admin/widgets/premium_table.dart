import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/admin_theme.dart';
import 'premium_search.dart';

class PremiumTable<T> extends StatefulWidget {
  final List<String> columns;
  final List<T> data;
  final Widget Function(BuildContext, int, T) rowBuilder;
  final Widget Function(BuildContext, String, int)? headerBuilder;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final int? currentPage;
  final int? totalPages;
  final Function(int)? onPageChanged;
  final String? emptyMessage;
  final IconData? emptyIcon;

  const PremiumTable({
    super.key,
    required this.columns,
    required this.data,
    required this.rowBuilder,
    this.headerBuilder,
    this.onRefresh,
    this.isLoading = false,
    this.currentPage,
    this.totalPages,
    this.onPageChanged,
    this.emptyMessage,
    this.emptyIcon,
  });

  @override
  State<PremiumTable<T>> createState() => _PremiumTableState<T>();
}

class _PremiumTableState<T> extends State<PremiumTable<T>> {
  final Set<int> _hoveredRows = {};
  final Map<int, SortDirection> _sortDirections = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildContent(),
          if (widget.totalPages != null && widget.totalPages! > 1)
            _buildPagination(),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(duration: 300.ms);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgTertiary.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          bottom: BorderSide(color: AdminTheme.borderGlow),
        ),
      ),
      child: Row(
        children: [
          ...widget.columns.asMap().entries.map((entry) {
            final index = entry.key;
            final column = entry.value;
            return Expanded(
              flex: _getFlexForColumn(index),
              child: widget.headerBuilder?.call(context, column, index) ??
                  _buildDefaultHeader(column, index),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader(String column, int index) {
    final sortDirection = _sortDirections[index];
    return GestureDetector(
      onTap: () {
        setState(() {
          if (sortDirection == null) {
            _sortDirections[index] = SortDirection.ascending;
          } else if (sortDirection == SortDirection.ascending) {
            _sortDirections[index] = SortDirection.descending;
          } else {
            _sortDirections.remove(index);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              column,
              style: GoogleFonts.rajdhani(
                color: AdminTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (sortDirection != null) ...[
              const SizedBox(width: 8),
              Icon(
                sortDirection == SortDirection.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
                color: AdminTheme.accentNeon,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            color: AdminTheme.accentNeon,
          ),
        ),
      );
    }

    if (widget.data.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.emptyIcon ?? Icons.inbox_outlined,
                size: 48,
                color: AdminTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.emptyMessage ?? 'No data available',
                style: GoogleFonts.rajdhani(
                  color: AdminTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isHovered = _hoveredRows.contains(index);
        
        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredRows.add(index)),
          onExit: (_) => setState(() => _hoveredRows.remove(index)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isHovered ? AdminTheme.bgTertiary.withOpacity(0.3) : null,
              border: Border(
                bottom: BorderSide(
                  color: AdminTheme.borderGlow,
                  width: 0.5,
                ),
                left: isHovered
                    ? BorderSide(color: AdminTheme.accentNeon, width: 3)
                    : BorderSide.none,
              ),
            ),
            child: widget.rowBuilder(context, index, item),
          ).animate().fadeIn(duration: 300.ms, delay: (50 * index).ms),
        );
      }).toList(),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgTertiary.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: AdminTheme.borderGlow),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${widget.currentPage ?? 1} of ${widget.totalPages}',
            style: GoogleFonts.rajdhani(
              color: AdminTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              PremiumButton(
                text: 'Previous',
                onPressed: (widget.currentPage ?? 1) > 1
                    ? () => widget.onPageChanged?.call((widget.currentPage ?? 1) - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                final pageNumber = (widget.currentPage ?? 1) - 2 + index;
                if (pageNumber < 1 || pageNumber > (widget.totalPages ?? 1)) {
                  return const SizedBox.shrink();
                }
                final isActive = pageNumber == (widget.currentPage ?? 1);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: PremiumButton(
                    text: pageNumber.toString(),
                    onPressed: () => widget.onPageChanged?.call(pageNumber),
                    backgroundColor: isActive
                        ? AdminTheme.accentNeon
                        : AdminTheme.bgTertiary,
                    foregroundColor: isActive
                        ? AdminTheme.bgPrimary
                        : AdminTheme.textPrimary,
                    width: 40,
                  ),
                );
              }),
              const SizedBox(width: 8),
              PremiumButton(
                text: 'Next',
                onPressed: (widget.currentPage ?? 1) < (widget.totalPages ?? 1)
                    ? () => widget.onPageChanged?.call((widget.currentPage ?? 1) + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getFlexForColumn(int index) {
    // Default flex distribution - can be customized
    switch (index) {
      case 0: // First column (usually ID or primary field)
        return 1;
      case 1: // Second column (usually name or title)
        return 3;
      default:
        return 2;
    }
  }
}

enum SortDirection { ascending, descending }
