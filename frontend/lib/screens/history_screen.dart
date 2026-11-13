import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/history_entry.dart';
import '../providers/history_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

enum _Filter { all, server, device }

/// "Your archive": staggered two-column grid of saved results, with
/// filters and search. Long-press a tile to delete it.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _filter = _Filter.all;
  bool _searching = false;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HistoryEntry> _visible(List<HistoryEntry> all) {
    final q = _query.trim().toUpperCase();
    return all.where((e) {
      final modeOk = switch (_filter) {
        _Filter.all => true,
        _Filter.server => !e.isOnDevice,
        _Filter.device => e.isOnDevice,
      };
      return modeOk && (q.isEmpty || e.name.toUpperCase().contains(q));
    }).toList();
  }

  Future<void> _confirmDelete(HistoryEntry e) async {
    final history = context.read<HistoryProvider>();
    final ok = await showConfirmSheet(
      context,
      title: 'Delete ${e.name}?',
      body: 'The original and the deblurred copy are removed from this phone.',
      action: 'Delete',
    );
    if (ok == true) await history.deleteEntry(e);
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final top = MediaQuery.paddingOf(context).top;
    final items = _visible(history.entries);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, top + 12, 24, 0),
          sliver: SliverList.list(
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: _searching
                          ? TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (v) => setState(() => _query = v),
                              style: AppText.sans(15),
                              decoration: InputDecoration(
                                hintText: 'Search by name',
                                hintStyle: AppText.sans(15, color: AppColors.textFaint),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            )
                          : MonoLabel(
                              'CACHE · ${Fmt.bytes(history.totalBytes)}'
                              ' · ${history.entries.length} PHOTOS',
                            ),
                    ),
                    IconCircleButton(
                      icon: _searching ? LucideIcons.x : LucideIcons.search,
                      semanticLabel: _searching ? 'Close search' : 'Search history',
                      onTap: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) {
                          _query = '';
                          _searchCtrl.clear();
                        }
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Headline([Headline.sans('Your ', 44), Headline.serif('archive', 50)]),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final (f, label) in const [
                    (_Filter.all, 'All'),
                    (_Filter.server, 'Server'),
                    (_Filter.device, 'On-device'),
                  ]) ...[
                    _FilterPill(
                      label: label,
                      active: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
        if (history.isLoading && history.entries.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            ),
          )
        else if (items.isEmpty)
          SliverToBoxAdapter(child: _empty(history.entries.isEmpty))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
            sliver: SliverToBoxAdapter(child: _grid(items)),
          ),
      ],
    );
  }

  Widget _grid(List<HistoryEntry> items) {
    const heights = [250.0, 170.0, 170.0, 250.0];
    final colA = <Widget>[];
    final colB = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final tile = Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _Tile(
          entry: items[i],
          height: heights[i % 4],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ResultScreen(entry: items[i], cached: true)),
          ),
          onLongPress: () => _confirmDelete(items[i]),
        ),
      );
      (i.isEven ? colA : colB).add(tile);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: colA)),
        const SizedBox(width: 10),
        Expanded(child: Column(children: colB)),
      ],
    );
  }

  Widget _empty(bool nothingSaved) {
    final text = nothingSaved
        ? 'No deblurred photos yet. Tap the lime button to start.'
        : _filter == _Filter.device
            ? 'No on-device results yet. The on-device model is coming soon.'
            : 'Nothing matches that search.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 140),
      child: Column(
        children: [
          const Icon(LucideIcons.layoutDashboard, size: 34, color: AppColors.textFaint),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: AppText.body(15)),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active ? null : Border.all(color: AppColors.textA(0.14)),
        ),
        child: Text(
          label,
          style: AppText.button(14, color: active ? AppColors.onAccent : AppColors.textMuted),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final HistoryEntry entry;
  final double height;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _Tile({
    required this.entry,
    required this.height,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: 'Open ${entry.name}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(entry.deblurredPath),
                fit: BoxFit.cover,
                cacheWidth: 500,
                errorBuilder: (_, _, _) => Container(color: AppColors.surfaceHigh),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.55, 1],
                    colors: [AppColors.bgA(0), AppColors.bgA(0.8)],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: MonoChip(
                  entry.isOnDevice ? 'ON-DEVICE' : 'SERVER',
                  fontSize: 10,
                  color: entry.isOnDevice ? AppColors.accent : AppColors.text,
                  background: AppColors.bgA(0.6),
                  radius: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.when(entry.createdAt),
                      style: AppText.mono(10, color: AppColors.textChip, spacing: 0.06),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small confirmation bottom sheet in the app's style.
Future<bool?> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9E050506),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + MediaQuery.paddingOf(ctx).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.textA(0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.title(20)),
            const SizedBox(height: 8),
            Text(body, style: AppText.body(14)),
            const SizedBox(height: 20),
            SoftButton(
              label: action,
              outlined: true,
              color: AppColors.danger,
              borderColor: AppColors.dangerBorder,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 10),
            SoftButton(label: 'Cancel', onTap: () => Navigator.of(ctx).pop(false)),
          ],
        ),
      ),
    ),
  );
}
