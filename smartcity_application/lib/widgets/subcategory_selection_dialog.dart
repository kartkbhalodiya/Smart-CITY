import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows subcategories in a proper selection dialog
class SubcategorySelectionDialog extends StatefulWidget {
  final String categoryName;
  final String categoryEmoji;
  final List<String> subcategories;
  final Function(String) onSelected;

  const SubcategorySelectionDialog({
    Key? key,
    required this.categoryName,
    required this.categoryEmoji,
    required this.subcategories,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<SubcategorySelectionDialog> createState() => _SubcategorySelectionDialogState();
}

class _SubcategorySelectionDialogState extends State<SubcategorySelectionDialog> {
  String? _selectedSubcategory;
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredSubcategories = [];

  @override
  void initState() {
    super.initState();
    _filteredSubcategories = widget.subcategories;
  }

  void _filterSubcategories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSubcategories = widget.subcategories;
      } else {
        _filteredSubcategories = widget.subcategories
            .where((sub) => sub.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B1020), Color(0xFF2F80ED)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.categoryName,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select the specific issue type',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSubcategories,
                decoration: InputDecoration(
                  hintText: 'Search issue type...',
                  hintStyle: GoogleFonts.inter(fontSize: 14),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Subcategories list
            Expanded(
              child: _filteredSubcategories.isEmpty
                  ? Center(
                      child: Text(
                        'No matching issues found',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSubcategories.length,
                      itemBuilder: (context, index) {
                        final subcategory = _filteredSubcategories[index];
                        final isSelected = _selectedSubcategory == subcategory;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedSubcategory = subcategory;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2F80ED).withOpacity(0.1)
                                      : (isDark ? Colors.grey[850] : Colors.grey[100]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2F80ED)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? const Color(0xFF2F80ED)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        subcategory,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? const Color(0xFF2F80ED)
                                              : (isDark ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Confirm button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedSubcategory == null
                      ? null
                      : () {
                          widget.onSelected(_selectedSubcategory!);
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F80ED),
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirm Selection',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Helper function to show the dialog
Future<void> showSubcategoryDialog({
  required BuildContext context,
  required String categoryName,
  required String categoryEmoji,
  required List<String> subcategories,
  required Function(String) onSelected,
}) async {
  await showDialog(
    context: context,
    builder: (context) => SubcategorySelectionDialog(
      categoryName: categoryName,
      categoryEmoji: categoryEmoji,
      subcategories: subcategories,
      onSelected: onSelected,
    ),
  );
}
