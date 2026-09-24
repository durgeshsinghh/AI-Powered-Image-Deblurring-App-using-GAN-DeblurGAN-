import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deblur_provider.dart';
import '../widgets/before_after_view.dart';

/// The home tab's content: empty prompt, loading state, or the before/after
/// result. Picking a photo (gallery or camera) is driven by the bottom
/// [BottomActionBar] in [MainScreen], not by buttons in here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeblurProvider>(
      builder: (context, provider, _) {
        // Show the error as a SnackBar once, right after it appears.
        if (provider.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage!),
                duration: const Duration(seconds: 6),
              ),
            );
          });
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.resultImage != null &&
                    provider.pickedImage != null) ...[
                  BeforeAfterView(
                    original: provider.pickedImage!,
                    deblurred: provider.resultImage!,
                  ),
                  const SizedBox(height: 12),
                  if (provider.processingTimeMs != null)
                    Text(
                      'Processed in ${provider.processingTimeMs} ms',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.read<DeblurProvider>().reset(),
                    child: const Text('Try another photo'),
                  ),
                ] else if (provider.isLoading) ...[
                  const SizedBox(height: 100),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  const Text('Restoring image…', textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    'First request after a while can take up to a '
                    'minute or two while the AI engine wakes up.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  const SizedBox(height: 100),
                  Icon(
                    Icons.image_search,
                    size: 72,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick a blurred photo to get started',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use the gallery or camera button below.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
