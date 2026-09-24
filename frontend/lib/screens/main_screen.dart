import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/deblur_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/bottom_action_bar.dart';
import 'history_screen.dart';
import 'home_screen.dart';

enum _Tab { home, history }

/// App shell: switches between the home (pick/deblur) content and the
/// history grid, via the bottom action bar (gallery left, camera centre,
/// history right).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  _Tab _tab = _Tab.home;

  Future<void> _pickAndSave(ImageSource source) async {
    setState(() => _tab = _Tab.home);

    final deblur = context.read<DeblurProvider>();
    await deblur.pickAndSubmit(source);
    if (!mounted) return;

    if (deblur.resultImage != null && deblur.pickedImage != null) {
      await context.read<HistoryProvider>().addEntry(
        original: deblur.pickedImage!,
        deblurredBytes: deblur.resultImage!,
        processingTimeMs: deblur.processingTimeMs,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == _Tab.home ? 'AI Image Deblurring' : 'History'),
      ),
      body: IndexedStack(
        index: _tab == _Tab.home ? 0 : 1,
        children: const [HomeScreen(), HistoryScreen()],
      ),
      bottomNavigationBar: BottomActionBar(
        historySelected: _tab == _Tab.history,
        onGallery: () => _pickAndSave(ImageSource.gallery),
        onCamera: () => _pickAndSave(ImageSource.camera),
        onHistory: () => setState(() => _tab = _Tab.history),
      ),
    );
  }
}
