import 'package:flutter/material.dart';

class StaffAdd extends StatefulWidget {
  const StaffAdd({Key? key}) : super(key: key);

  @override
  State<StaffAdd> createState() => _StaffAddState();
}

class _StaffAddState extends State<StaffAdd> {
  final TextEditingController _nameController = TextEditingController();
  String? _category;
  String? _status;
  // sample categories and statuses
  final List<String> _categories = ['Book', 'Magazine', 'DVD'];
  final List<String> _statuses = ['Available', 'Borrowed', 'Reserved'];

  void _clearForm() {
    _nameController.clear();
    setState(() {
      _category = null;
      _status = null;
    });
  }

  void _submit() {
    // Replace with your real submit logic (API call / DB insert)
    final name = _nameController.text.trim();
    final category = _category;
    final status = _status;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name')),
      );
      return;
    }

    // For now show a simple dialog with values
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item added'),
        content: Text('Name: $name\nCategory: $category\nStatus: $status'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width * 0.86;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add',
          style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w500),
        ),
        centerTitle: false,
        // put a back arrow on the right like the screenshot: use an action that pops
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.grey),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: panelWidth,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFEAFDFD), // very light aqua like screenshot
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Upload picture box
                GestureDetector(
                  onTap: () {
                    // TODO: wire up image picker
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Upload picture tapped')),
                    );
                  },
                  child: Container(
                    width: panelWidth * 0.8,
                    height: panelWidth * 0.56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'upload\npicture',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 22),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Name field
                _roundedField(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'add name',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Category dropdown
                _roundedField(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    hint: const Padding(
                      padding: EdgeInsets.only(left: 6.0),
                      child: Text('category'),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),

                const SizedBox(height: 12),

                // Status dropdown
                _roundedField(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    hint: const Padding(
                      padding: EdgeInsets.only(left: 6.0),
                      child: Text('status'),
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),

                const SizedBox(height: 22),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Clear button (red)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _clearForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'clear',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Add button (blue)
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundedField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
