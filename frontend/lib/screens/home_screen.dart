import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/deblur_provider.dart';
import '../widgets/before_after_view.dart';

/// The main (and only) screen of the app: pick a blurred photo, send it to
/// the backend, and show the before/after comparison.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Image Deblurring')),
      body: Consumer<DeblurProvider>(
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
                  action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () => provider.submitForDeblur(),
                  ),
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              provider.isLoading
                                  ? null
                                  : () => context
                                      .read<DeblurProvider>()
                                      .pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Pick from Gallery'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              provider.isLoading
                                  ? null
                                  : () => context
                                      .read<DeblurProvider>()
                                      .pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Take Photo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  ] else if (provider.pickedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        provider.pickedImage!,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (provider.isLoading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text('Restoring image…'),
                      const SizedBox(height: 4),
                      Text(
                        'First request after a while can take up to a '
                        'minute or two while the AI engine wakes up.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else
                      ElevatedButton(
                        onPressed:
                            () =>
                                context
                                    .read<DeblurProvider>()
                                    .submitForDeblur(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Deblur Image'),
                      ),
                  ] else ...[
                    const SizedBox(height: 60),
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
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
