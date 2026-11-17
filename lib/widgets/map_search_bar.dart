import 'dart:async';

// Keep SDK Material types until the application migrates as a whole.
// ignore: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/place_result.dart';
import '../services/place_search_service.dart';

class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.onSelected,
    this.onCleared,
    this.service,
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  final ValueChanged<PlaceResult> onSelected;
  final VoidCallback? onCleared;
  // Injected services belong to the caller. Use a new key when changing service.
  final PlaceSearchService? service;
  final Duration debounceDuration;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scrollController = ScrollController();
  late final PlaceSearchService _service;
  late final bool _ownsService;
  Timer? _debounce;
  int _revision = 0;
  int _highlighted = -1;
  List<PlaceResult> _results = const [];
  String? _error;
  bool _loading = false;
  bool _open = false;
  bool _completed = false;
  String _lastText = '';
  bool _wasComposing = false;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service = widget.service ?? GeoapifyPlaceSearchService();
    _controller.addListener(_textChanged);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      _queue(_controller.text, composing: !_controller.value.composing.isCollapsed);
    } else {
      _dismiss();
    }
  }

  void _textChanged() {
    final value = _controller.value;
    final composing = !value.composing.isCollapsed;
    if (value.text == _lastText && composing == _wasComposing) return;
    _lastText = value.text;
    _wasComposing = composing;
    _queue(value.text, composing: composing);
  }

  void _queue(String text, {bool composing = false}) {
    _debounce?.cancel();
    // Invalidate immediately, before the next debounce timer fires.
    final revision = ++_revision;
    final query = text.trim();
    final canSearch = query.length >= 3 && !composing && _focus.hasFocus;
    setState(() {
      _results = const [];
      _highlighted = -1;
      _error = null;
      _completed = false;
      _loading = canSearch;
      _open = _focus.hasFocus && query.isNotEmpty;
    });
    if (!canSearch) return;
    _debounce = Timer(widget.debounceDuration, () => _search(query, revision));
  }

  Future<void> _search(String query, int revision) async {
    try {
      final results = await _service.search(query);
      if (!mounted || revision != _revision) return;
      setState(() {
        _results = results;
        _loading = false;
        _completed = true;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _completed = true;
        _error = error is PlaceSearchException
            ? error.message
            : 'Nie udało się wyszukać miejsca. Spróbuj ponownie.';
      });
    }
  }

  void _dismiss() {
    _debounce?.cancel();
    ++_revision;
    setState(() {
      _open = false;
      _loading = false;
    });
  }

  void _select(PlaceResult place) {
    _dismiss();
    _lastText = place.label;
    _wasComposing = false;
    _controller.value = TextEditingValue(
      text: place.label,
      selection: TextSelection.collapsed(offset: place.label.length),
    );
    _focus.unfocus();
    widget.onSelected(place);
  }

  void _clear() {
    _controller.clear();
    _dismiss();
    _focus.requestFocus();
    widget.onCleared?.call();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _dismiss();
      _focus.unfocus();
      return KeyEventResult.handled;
    }
    if (!_open || _results.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
      setState(() {
        _highlighted = _highlighted < 0
            ? (down ? 0 : _results.length - 1)
            : (_highlighted + (down ? 1 : -1)) % _results.length;
      });
      if (_scrollController.hasClients) {
        final target = (_highlighted * 72.0).clamp(
          0.0, _scrollController.position.maxScrollExtent,
        ).toDouble();
        _scrollController.jumpTo(target);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    if (_open && _results.isNotEmpty) {
      _select(_results[_highlighted < 0 ? 0 : _highlighted]);
    } else {
      _queue(_controller.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ++_revision;
    _controller.removeListener(_textChanged);
    _focus.removeListener(_focusChanged);
    _controller.dispose();
    _focus.dispose();
    _scrollController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Focus(
        onKeyEvent: _handleKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onEditingComplete: () {},
                onSubmitted: (_) => _submit(),
                onTap: () {
                  if (!_open) {
                    _queue(_controller.text,
                    composing: !_controller.value.composing.isCollapsed);
                  }
                },
                onTapOutside: (_) {
                  _dismiss();
                  _focus.unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Miasto, ulica lub miejsce…',
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  suffixIcon: _controller.text.isEmpty ? null : IconButton(
                    tooltip: 'Wyczyść wyszukiwanie',
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              Flexible(
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading) const LinearProgressIndicator(minHeight: 2),
                        if (_loading) const _SearchMessage('Szukam miejsc…'),
                        if (!_loading && _error != null) ...[
                          _SearchMessage(_error!),
                          TextButton.icon(
                            onPressed: () => _queue(_controller.text),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Spróbuj ponownie'),
                          ),
                        ],
                        if (!_loading && _error == null && _results.isEmpty)
                          _SearchMessage(_completed
                            ? 'Brak wyników. Spróbuj dodać miasto lub zmienić nazwę.'
                            : 'Wpisz co najmniej 3 znaki.'),
                        for (var index = 0; index < _results.length; index++)
                          SizedBox(
                            height: 72,
                            child: ListTile(
                              selected: index == _highlighted,
                              selectedTileColor: Colors.orange.withAlpha(30),
                              leading: const Icon(Icons.place_outlined),
                              title: Text(_results[index].title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: _results[index].subtitle.isEmpty ? null : Text(
                                _results[index].subtitle,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _select(_results[index]),
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Geoapify · © OpenStreetMap contributors',
                            style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Semantics(liveRegion: true, child: Text(message)),
  );
}
