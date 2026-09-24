import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Renders the original (blurred) image and the deblurred result
/// side by side, each clearly labeled.
class BeforeAfterView extends StatelessWidget {
  final File original;
  final Uint8List deblurred;

  const BeforeAfterView({
    super.key,
    required this.original,
    required this.deblurred,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _LabeledImage(
            label: 'Blurred',
            image: Image.file(original, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LabeledImage(
            label: 'Deblurred',
            image: Image.memory(deblurred, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

class _LabeledImage extends StatelessWidget {
  final String label;
  final Widget image;

  const _LabeledImage({required this.label, required this.image});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: image,
            ),
          ),
        ),
      ],
    );
  }
}
