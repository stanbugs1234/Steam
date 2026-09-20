import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'share_content.dart';
import 'share_flyer.dart';
import '../../core/utils/friendly_error.dart';

/// Opens the "share outside the club" sheet: a flyer preview, an editable
/// message, and a button that hands both to the system share sheet (Messages,
/// Mail, etc.).
Future<void> showShareSheet(BuildContext context, ShareContent content) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _ShareSheet(content: content),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.content});

  final ShareContent content;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _flyerKey = GlobalKey();
  late final TextEditingController _messageCtrl;

  Future<void>? _imageReady;
  bool _includeFlyer = true;
  bool _sharing = false;

  // Capturing the flyer as an image isn't possible on web (cross-origin images
  // taint the canvas), so web shares text only.
  bool get _canShareFlyer => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(text: buildShareMessage(widget.content));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start loading the flyer photo now so it is fully painted by the time the
    // member taps Share.
    final url = widget.content.imageUrl;
    _imageReady ??= url == null
        ? Future<void>.value()
        : precacheImage(CachedNetworkImageProvider(url), context, onError: (_, _) {});
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List> _captureFlyerPng() async {
    await _imageReady;
    // Give the just-decoded image one frame to paint before capturing.
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _flyerKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _sharing = true);
    try {
      final withFlyer = _includeFlyer && _canShareFlyer;
      final files = withFlyer
          ? [XFile.fromData(await _captureFlyerPng(), mimeType: 'image/png', name: 'flyer.png')]
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          text: _messageCtrl.text.trim(),
          files: files,
          fileNameOverrides: withFlyer ? const ['flyer.png'] : null,
          sharePositionOrigin: origin,
        ),
      );
      if (result.status == ShareResultStatus.success && mounted) navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: "Couldn't open sharing. Please try again."))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewWidth = (MediaQuery.sizeOf(context).width - 48).clamp(200.0, 300.0);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share with someone outside the club', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Sends a flyer and message you can edit. Pick Messages to text it.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_canShareFlyer) ...[
            const SizedBox(height: 16),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _includeFlyer ? 1 : 0.35,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: SizedBox(
                    width: previewWidth,
                    height: previewWidth * flyerSize.height / flyerSize.width,
                    child: FittedBox(
                      child: RepaintBoundary(key: _flyerKey, child: ShareFlyer(content: widget.content)),
                    ),
                  ),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include flyer image'),
              value: _includeFlyer,
              onChanged: (v) => setState(() => _includeFlyer = v),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
            minLines: 5,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: _sharing ? null : () => _share(buttonContext),
              icon: _sharing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              label: const Text('Share'),
            ),
          ),
        ],
      ),
    );
  }
}
