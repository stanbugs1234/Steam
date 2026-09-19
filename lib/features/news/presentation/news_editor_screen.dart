import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/error_state.dart';
import '../../../models/news_post.dart';
import '../../auth/domain/auth_providers.dart';
import '../../events/domain/event_providers.dart';
import '../domain/news_providers.dart';
import 'news_widgets.dart';

/// Create/edit form for a news post. Pass [postId] to edit an existing post,
/// or leave it null to create a new one.
class NewsEditorScreen extends ConsumerStatefulWidget {
  const NewsEditorScreen({super.key, this.postId});

  final String? postId;

  @override
  ConsumerState<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends ConsumerState<NewsEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String? _newPostId;
  String? _imageUrl;
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  NewsCategory _category = NewsCategory.announcement;
  bool _pinned = false;
  String? _eventId;
  NewsPost? _loadedFor;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.postId != null;

  String _postId() {
    if (widget.postId != null) return widget.postId!;
    return _newPostId ??= ref.read(newsRepositoryProvider).newPostId();
  }

  void _syncFromExisting(NewsPost post) {
    if (_loadedFor?.id == post.id) return;
    _loadedFor = post;
    _titleCtrl.text = post.title;
    _bodyCtrl.text = post.body;
    _imageUrl = post.imageUrl;
    _category = post.category;
    _pinned = post.pinned;
    _eventId = post.eventId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImage = file;
      _pickedBytes = bytes;
    });
  }

  void _removeImage() => setState(() {
        _pickedImage = null;
        _pickedBytes = null;
        _imageUrl = null;
      });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = _postId();
      var imageUrl = _imageUrl;
      if (_pickedImage != null) {
        imageUrl = await ref.read(newsImageRepositoryProvider).uploadNewsImage(id, _pickedImage!);
      }

      if (_isEditing) {
        await ref.read(newsRepositoryProvider).updatePost(id, {
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'imageUrl': imageUrl,
          'category': _category.name,
          'pinned': _pinned,
          'eventId': _eventId,
        });
      } else {
        final me = ref.read(currentAppUserProvider).value;
        await ref.read(newsRepositoryProvider).createPost(NewsPost(
              id: id,
              title: _titleCtrl.text.trim(),
              body: _bodyCtrl.text.trim(),
              authorId: me?.uid ?? '',
              authorName: me?.name ?? '',
              imageUrl: imageUrl,
              category: _category,
              pinned: _pinned,
              eventId: _eventId,
            ));
      }

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Could not save post: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final feedAsync = ref.watch(newsFeedProvider);
      return feedAsync.when(
        data: (posts) {
          final post = posts.firstWhereOrNull((p) => p.id == widget.postId);
          if (post == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('Post not found.')));
          }
          _syncFromExisting(post);
          return _buildForm(context);
        },
        loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(appBar: AppBar(), body: ErrorState(message: 'Something went wrong.', error: err)),
      );
    }
    return _buildForm(context);
  }

  /// Lets the author tie this post to an event (e.g. a speaker night) so the
  /// post shows the event's date and place and shares them too. Offers
  /// upcoming events, plus the one already attached when editing.
  Widget _buildEventPicker(BuildContext context) {
    final now = DateTime.now();
    final events = (ref.watch(eventsProvider).value ?? const [])
        .where((e) => e.endTime.isAfter(now) || e.id == _eventId)
        .sortedBy((e) => e.startTime);
    // Drop a stale link (event deleted) rather than feeding the dropdown a
    // value with no matching item.
    final selected = events.any((e) => e.id == _eventId) ? _eventId : null;

    return DropdownButtonFormField<String?>(
      key: ValueKey(selected),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Attach an event (optional)',
        prefixIcon: Icon(Icons.event_outlined),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('No event')),
        for (final e in events)
          DropdownMenuItem<String?>(
            value: e.id,
            child: Text('${DateFormat.MMMd().format(e.startTime)} · ${e.title}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _eventId = v),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Post' : 'New Post')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _pickedBytes != null
                            ? Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity)
                            : (_imageUrl != null
                                ? NewsImage(url: _imageUrl!)
                                : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 40))),
                      ),
                    ),
                  ),
                  if (_pickedBytes != null || _imageUrl != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _removeImage,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove photo'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Type', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in NewsCategory.values)
                        ChoiceChip(
                          avatar: Icon(category.icon, size: 18),
                          label: Text(category.label),
                          selected: _category == category,
                          onSelected: (_) => setState(() => _category = category),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(labelText: 'Body', alignLabelWithHint: true),
                    minLines: 6,
                    maxLines: 16,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildEventPicker(context),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pin to top of News'),
                    subtitle: const Text('Pinned posts stay first in the feed.'),
                    value: _pinned,
                    onChanged: (v) => setState(() => _pinned = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isEditing ? 'Save Changes' : 'Publish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
