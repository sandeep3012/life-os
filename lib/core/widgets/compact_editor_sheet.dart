import 'package:flutter/material.dart';

Future<T?> showCompactEditorSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final media = MediaQuery.of(context);
  // Keep a deliberate gap below the app bar. A fixed viewport fraction is
  // more reliable than sizing from the sheet's intrinsic child height.
  final maxHeight = (media.size.height * 0.84).clamp(0.0, media.size.height);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: builder,
  );
}

class CompactEditorSheet extends StatelessWidget {
  const CompactEditorSheet({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}
