// lib/core/keyboard/pos_keyboard_system.dart
//
// High-ROI POS keyboard system.
// Packages: hotkey_manager (F-keys + global shortcuts), flutter built-ins
// (Shortcuts/Actions/Focus) for navigation, Enter, Escape, Delete, arrows.
//
// What's wired up:
//   Ctrl+F       → focus product search
//   F1           → open new order / focus POS
//   F2           → open cart / checkout panel
//   F3           → hold order
//   F4           → add customer
//   F5           → refresh inventory
//   Enter        → confirm / add focused item
//   Escape       → cancel dialog / clear search
//   Delete       → remove focused cart item
//   Ctrl+Z       → undo last cart action
//   Arrow keys   → navigate product list / cart list
//   Tab          → move forward between fields
//   Shift+Tab    → move backward between fields
//   Ctrl+→/←     → next / previous category
//   Ctrl+Enter   → proceed to checkout
//   Ctrl+Delete  → clear entire cart
//   Shift+/  (?) → show shortcut help

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// INTENT DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════════════

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ClearSearchIntent extends Intent {
  const ClearSearchIntent();
}

class NextCategoryIntent extends Intent {
  const NextCategoryIntent();
}

class PrevCategoryIntent extends Intent {
  const PrevCategoryIntent();
}

class CheckoutIntent extends Intent {
  const CheckoutIntent();
}

class KitchenIntent extends Intent {
  const KitchenIntent();
}

class ClearCartIntent extends Intent {
  const ClearCartIntent();
}

class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent();
}

class ConfirmItemIntent extends Intent {
  const ConfirmItemIntent();
}

class DeleteItemIntent extends Intent {
  const DeleteItemIntent();
}

class UndoCartIntent extends Intent {
  const UndoCartIntent();
}

class ArrowUpIntent extends Intent {
  const ArrowUpIntent();
}

class ArrowDownIntent extends Intent {
  const ArrowDownIntent();
}

class ArrowLeftIntent extends Intent {
  const ArrowLeftIntent();
}

class ArrowRightIntent extends Intent {
  const ArrowRightIntent();
}

class NumpadKeyIntent extends Intent {
  final String key;
  const NumpadKeyIntent(this.key);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHORTCUT MAPS — covers every built-in Flutter shortcut (no hidden fields)
// ═══════════════════════════════════════════════════════════════════════════════════════

class PosShortcuts {
  /// POS screen shortcuts (handled by Shortcuts widget + Actions)
  static Map<ShortcutActivator, Intent> posScreen = {
    // Search
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.slash): const FocusSearchIntent(),

    // Clear / cancel
    const SingleActivator(LogicalKeyboardKey.escape): const ClearSearchIntent(),

    // Category navigation
    const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
        const NextCategoryIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
        const PrevCategoryIntent(),

    // Cart
    const SingleActivator(LogicalKeyboardKey.enter, control: true):
        const CheckoutIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true):
        const KitchenIntent(),
    const SingleActivator(LogicalKeyboardKey.delete, control: true):
        const ClearCartIntent(),
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
        const UndoCartIntent(),

    // Item actions
    const SingleActivator(LogicalKeyboardKey.enter): const ConfirmItemIntent(),
    const SingleActivator(LogicalKeyboardKey.delete): const DeleteItemIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const ConfirmItemIntent(),

    // Arrow navigation
    const SingleActivator(LogicalKeyboardKey.arrowUp): const ArrowUpIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const ArrowDownIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const ArrowLeftIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const ArrowRightIntent(),

    // Help
    const SingleActivator(LogicalKeyboardKey.slash, shift: true):
        const ShowShortcutsIntent(),
  };

  /// Checkout numpad shortcuts
  static Map<ShortcutActivator, Intent> numpad = {
    const SingleActivator(LogicalKeyboardKey.digit0): NumpadKeyIntent('0'),
    const SingleActivator(LogicalKeyboardKey.digit1): NumpadKeyIntent('1'),
    const SingleActivator(LogicalKeyboardKey.digit2): NumpadKeyIntent('2'),
    const SingleActivator(LogicalKeyboardKey.digit3): NumpadKeyIntent('3'),
    const SingleActivator(LogicalKeyboardKey.digit4): NumpadKeyIntent('4'),
    const SingleActivator(LogicalKeyboardKey.digit5): NumpadKeyIntent('5'),
    const SingleActivator(LogicalKeyboardKey.digit6): NumpadKeyIntent('6'),
    const SingleActivator(LogicalKeyboardKey.digit7): NumpadKeyIntent('7'),
    const SingleActivator(LogicalKeyboardKey.digit8): NumpadKeyIntent('8'),
    const SingleActivator(LogicalKeyboardKey.digit9): NumpadKeyIntent('9'),
    const SingleActivator(LogicalKeyboardKey.backspace): NumpadKeyIntent('⌫'),
    const SingleActivator(LogicalKeyboardKey.numpadDecimal):
        NumpadKeyIntent('.'),
    const SingleActivator(LogicalKeyboardKey.period): NumpadKeyIntent('.'),
    const SingleActivator(LogicalKeyboardKey.escape): NumpadKeyIntent('ESC'),
    const SingleActivator(LogicalKeyboardKey.enter): ConfirmItemIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): ConfirmItemIntent(),
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL HOTKEY REGISTRY  (hotkey_manager — F-keys work even outside focus tree)
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Call PosHotkeyRegistry.init() in main() after WidgetsFlutterBinding.
/// Call PosHotkeyRegistry.register(...) once per screen's initState.
/// Call PosHotkeyRegistry.unregisterAll() in dispose.
class PosHotkeyRegistry {
  PosHotkeyRegistry._();

  static final List<HotKey> _registered = [];

  /// Must be called in main() before runApp():
  ///   await PosHotkeyRegistry.init();
  static Future<void> init() async {
    await hotKeyManager.unregisterAll();
  }

  static Future<void> register({
    required VoidCallback onF1NewOrder,
    required VoidCallback onF2Cart,
    required VoidCallback onF3HoldOrder,
    required VoidCallback onF4AddCustomer,
    required VoidCallback onF5Refresh,
    required VoidCallback onF6Kitchen,
    required VoidCallback onCtrlF,
  }) async {
    await unregisterAll();

    final hotkeys = <(HotKey, VoidCallback)>[
      (
        HotKey(key: PhysicalKeyboardKey.f1, scope: HotKeyScope.inapp),
        onF1NewOrder
      ),
      (HotKey(key: PhysicalKeyboardKey.f2, scope: HotKeyScope.inapp), onF2Cart),
      (
        HotKey(key: PhysicalKeyboardKey.f3, scope: HotKeyScope.inapp),
        onF3HoldOrder
      ),
      (
        HotKey(key: PhysicalKeyboardKey.f4, scope: HotKeyScope.inapp),
        onF4AddCustomer
      ),
      (
        HotKey(key: PhysicalKeyboardKey.f5, scope: HotKeyScope.inapp),
        onF5Refresh
      ),
      (
        HotKey(key: PhysicalKeyboardKey.f6, scope: HotKeyScope.inapp),
        onF6Kitchen
      ),
      (
        HotKey(
            key: PhysicalKeyboardKey.keyF,
            modifiers: [HotKeyModifier.control],
            scope: HotKeyScope.inapp),
        onCtrlF
      ),
    ];

    for (final (hotkey, callback) in hotkeys) {
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (_) => callback(),
      );
      _registered.add(hotkey);
    }
  }

  static Future<void> unregisterAll() async {
    for (final hk in _registered) {
      await hotKeyManager.unregister(hk);
    }
    _registered.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNDO STACK — lightweight cart undo (Ctrl+Z)
// ═══════════════════════════════════════════════════════════════════════════════════════

class CartUndoStack {
  static final CartUndoStack instance = CartUndoStack._();
  CartUndoStack._();

  final List<_UndoEntry> _stack = [];
  static const int _maxEntries = 20;

  void push(String description, VoidCallback undoFn) {
    if (_stack.length >= _maxEntries) _stack.removeAt(0);
    _stack.add(_UndoEntry(description, undoFn));
  }

  bool get canUndo => _stack.isNotEmpty;

  String? get lastDescription =>
      _stack.isEmpty ? null : _stack.last.description;

  void undo() {
    if (_stack.isEmpty) return;
    _stack.removeLast().undoFn();
  }

  void clear() => _stack.clear();
}

class _UndoEntry {
  final String description;
  final VoidCallback undoFn;
  _UndoEntry(this.description, this.undoFn);
}

// ═══════════════════════════════════════════════════════════════════════════════
// POS KEYBOARD SCOPE  — wraps the POS screen body
// ═══════════════════════════════════════════════════════════════════════════════════════

class PosKeyboardScope extends StatelessWidget {
  final Widget child;
  final GlobalKey<PosSearchBarState>? searchBarKey;
  final GlobalKey<PosCategoryChipsState>? categoryChipsKey;
  final VoidCallback? onCheckout;
  final VoidCallback? onKitchen;
  final VoidCallback? onClearCart;
  final VoidCallback? onDeleteFocusedItem;
  final VoidCallback? onUndoCart;
  final VoidCallback? onConfirmFocusedItem;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;

  const PosKeyboardScope({
    super.key,
    required this.child,
    this.searchBarKey,
    this.categoryChipsKey,
    this.onCheckout,
    this.onKitchen,
    this.onClearCart,
    this.onDeleteFocusedItem,
    this.onUndoCart,
    this.onConfirmFocusedItem,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: PosShortcuts.posScreen,
      child: Actions(
        actions: {
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) {
              searchBarKey?.currentState?.requestFocus();
              return null;
            },
          ),
          ClearSearchIntent: CallbackAction<ClearSearchIntent>(
            onInvoke: (_) {
              final nav = Navigator.of(context, rootNavigator: false);
              if (nav.canPop()) {
                nav.pop();
              } else {
                searchBarKey?.currentState?.clear();
              }
              return null;
            },
          ),
          NextCategoryIntent: CallbackAction<NextCategoryIntent>(
            onInvoke: (_) {
              categoryChipsKey?.currentState?.nextCategory();
              return null;
            },
          ),
          PrevCategoryIntent: CallbackAction<PrevCategoryIntent>(
            onInvoke: (_) {
              categoryChipsKey?.currentState?.prevCategory();
              return null;
            },
          ),
          CheckoutIntent: CallbackAction<CheckoutIntent>(
            onInvoke: (_) {
              onCheckout?.call();
              return null;
            },
          ),
          KitchenIntent: CallbackAction<KitchenIntent>(
            onInvoke: (_) {
              onKitchen?.call();
              return null;
            },
          ),
          ClearCartIntent: CallbackAction<ClearCartIntent>(
            onInvoke: (_) {
              onClearCart?.call();
              return null;
            },
          ),
          DeleteItemIntent: CallbackAction<DeleteItemIntent>(
            onInvoke: (_) {
              onDeleteFocusedItem?.call();
              return null;
            },
          ),
          UndoCartIntent: CallbackAction<UndoCartIntent>(
            onInvoke: (_) {
              onUndoCart?.call();
              return null;
            },
          ),
          ConfirmItemIntent: CallbackAction<ConfirmItemIntent>(
            onInvoke: (_) {
              onConfirmFocusedItem?.call();
              return null;
            },
          ),
          ArrowUpIntent: CallbackAction<ArrowUpIntent>(
            onInvoke: (_) {
              onArrowUp?.call();
              return null;
            },
          ),
          ArrowDownIntent: CallbackAction<ArrowDownIntent>(
            onInvoke: (_) {
              onArrowDown?.call();
              return null;
            },
          ),
          ArrowLeftIntent: CallbackAction<ArrowLeftIntent>(
            onInvoke: (_) {
              onArrowLeft?.call();
              return null;
            },
          ),
          ArrowRightIntent: CallbackAction<ArrowRightIntent>(
            onInvoke: (_) {
              onArrowRight?.call();
              return null;
            },
          ),
          ShowShortcutsIntent: CallbackAction<ShowShortcutsIntent>(
            onInvoke: (_) {
              PosShortcutHelp.show(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHECKOUT KEYBOARD SCOPE
// ═══════════════════════════════════════════════════════════════════════════════════════

class CheckoutKeyboardScope extends StatelessWidget {
  final Widget child;
  final TextEditingController? cashController;
  final FocusNode? cashFocusNode;
  final ValueChanged<String>? onCashChanged;
  final VoidCallback? onBack;
  final VoidCallback? onConfirm;

  const CheckoutKeyboardScope({
    super.key,
    required this.child,
    this.cashController,
    this.cashFocusNode,
    this.onCashChanged,
    this.onBack,
    this.onConfirm,
  });

  void _handleNumpad(String key) {
    if (key == 'ESC') {
      onBack?.call();
      return;
    }
    final ctrl = cashController;
    if (ctrl == null) return;
    cashFocusNode?.requestFocus();
    final current = ctrl.text;
    late String next;
    if (key == '⌫') {
      next = current.isEmpty ? '' : current.substring(0, current.length - 1);
    } else if (key == '.') {
      next = current.contains('.') ? current : '$current.';
    } else {
      next = current.isEmpty || current == '0' ? key : '$current$key';
    }
    ctrl.text = next;
    ctrl.selection = TextSelection.collapsed(offset: next.length);
    onCashChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: PosShortcuts.numpad,
      child: Actions(
        actions: {
          NumpadKeyIntent: CallbackAction<NumpadKeyIntent>(
            onInvoke: (intent) {
              _handleNumpad(intent.key);
              return null;
            },
          ),
          ConfirmItemIntent: CallbackAction<ConfirmItemIntent>(
            onInvoke: (_) {
              onConfirm?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOCUS INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════════════

class PosFocusIndicator extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color focusColor;

  const PosFocusIndicator({
    super.key,
    required this.child,
    this.focusNode,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.focusColor = const Color(0xFF534AB7),
  });

  @override
  State<PosFocusIndicator> createState() => _PosFocusIndicatorState();
}

class _PosFocusIndicatorState extends State<PosFocusIndicator> {
  late FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    if (widget.focusNode == null) _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _node.requestFocus();
        widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: widget.focusColor.withValues(alpha: 0.35),
                    blurRadius: 0,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Focus(focusNode: _node, child: widget.child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// POS SEARCH BAR
// ═══════════════════════════════════════════════════════════════════════════════════════

class PosSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String hintText;

  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText = 'Search items…  ( / or Ctrl+F )',
  });

  @override
  State<PosSearchBar> createState() => PosSearchBarState();
}

class PosSearchBarState extends State<PosSearchBar> {
  final FocusNode focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = focusNode.hasFocus);
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChange);
    focusNode.dispose();
    super.dispose();
  }

  void requestFocus() => focusNode.requestFocus();

  void clear() {
    widget.controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
    focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focused ? const Color(0xFF534AB7) : const Color(0xFFE4E4E8),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: const Color(0xFF534AB7).withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: focusNode,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14, color: Color(0xFF111118)),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Color(0xFF9999AE), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF6B6B80), size: 18),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF9999AE), size: 16),
                  onPressed: clear,
                  tooltip: 'Clear (Esc)',
                )
              : !_focused
                  ? Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _KeyBadge('/'),
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY CHIPS
// ═══════════════════════════════════════════════════════════════════════════════

class PosCategoryChips extends StatefulWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const PosCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<PosCategoryChips> createState() => PosCategoryChipsState();
}

class PosCategoryChipsState extends State<PosCategoryChips> {
  final ScrollController _scroll = ScrollController();
  static const double _estimatedChipWidth = 100.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void nextCategory() {
    final i = widget.categories.indexOf(widget.selected);
    if (i < widget.categories.length - 1) {
      widget.onSelected(widget.categories[i + 1]);
      _scrollToIndex(i + 1);
    }
  }

  void prevCategory() {
    final i = widget.categories.indexOf(widget.selected);
    if (i > 0) {
      widget.onSelected(widget.categories[i - 1]);
      _scrollToIndex(i - 1);
    }
  }

  void _scrollToIndex(int i) {
    if (!_scroll.hasClients) return;
    final offset =
        (i * _estimatedChipWidth).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(offset,
        duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = widget.categories[index];
          final isSelected = widget.selected == cat;
          return _CategoryChip(
            label: cat,
            isSelected: isSelected,
            onTap: () => widget.onSelected(cat),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.isSelected, required this.onTap});
  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF534AB7)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF534AB7)
                  : widget.isSelected
                      ? const Color(0xFF534AB7)
                      : const Color(0xFFE4E4E8),
              width: _focused ? 2 : 0.5,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                        color: const Color(0xFF534AB7).withValues(alpha: 0.2),
                        blurRadius: 6)
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              color: widget.isSelected ? Colors.white : const Color(0xFF6B6B80),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NUMERIC KEYPAD
// ═══════════════════════════════════════════════════════════════════════════════

class PosNumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<double> quickAmounts;

  const PosNumericKeypad({
    super.key,
    required this.controller,
    required this.onChanged,
    this.quickAmounts = const [500, 1000, 2000, 5000],
  });

  void _press(String key) {
    final current = controller.text;
    late String next;
    if (key == '⌫') {
      next = current.isEmpty ? '' : current.substring(0, current.length - 1);
    } else if (key == 'C') {
      next = '';
    } else if (key == '.') {
      next = current.contains('.') ? current : '$current.';
    } else {
      next = current.isEmpty || current == '0' ? key : '$current$key';
    }
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: quickAmounts
              .map((amount) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _QuickAmountButton(
                        label: 'Rs ${amount.toInt()}',
                        onTap: () {
                          final text = amount.toInt().toString();
                          controller.text = text;
                          controller.selection =
                              TextSelection.collapsed(offset: text.length);
                          onChanged(text);
                        },
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 2.2,
          children: ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '⌫']
              .map((k) => _NumpadKey(label: k, onPress: _press))
              .toList(),
        ),
      ],
    );
  }
}

class _NumpadKey extends StatefulWidget {
  final String label;
  final ValueChanged<String> onPress;
  const _NumpadKey({required this.label, required this.onPress});
  @override
  State<_NumpadKey> createState() => _NumpadKeyState();
}

class _NumpadKeyState extends State<_NumpadKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isDelete => widget.label == '⌫';

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onPress(widget.label);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onPress(widget.label);
        },
        onTapCancel: () => _ctrl.reverse(),

        // IMPORTANT FIX:
        // Replace ScaleTransition with AnimatedBuilder so we don't re-subscribe
        // to a potentially disposed Animation during didUpdateWidget windows.
        child: AnimatedBuilder(
          animation: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: _isDelete
                  ? const Color(0xFFFFEDE8)
                  : _focused
                      ? const Color(0xFFEEEDFE)
                      : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? const Color(0xFF534AB7)
                    : const Color(0xFFE4E4E8),
                width: _focused ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: _isDelete
                  ? const Icon(Icons.backspace_outlined,
                      color: Color(0xFFD85A30), size: 18)
                  : Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _focused
                            ? const Color(0xFF534AB7)
                            : const Color(0xFF111118),
                      ),
                    ),
            ),
          ),
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountButton({required this.label, required this.onTap});
  @override
  State<_QuickAmountButton> createState() => _QuickAmountButtonState();
}

class _QuickAmountButtonState extends State<_QuickAmountButton> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF534AB7) : const Color(0xFFEEEDFE),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF534AB7)
                  : const Color(0xFF534AB7).withValues(alpha: 0.3),
              width: _focused ? 1.5 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _focused ? Colors.white : const Color(0xFF534AB7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHORTCUT HELP OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════

class PosShortcutHelp extends StatelessWidget {
  const PosShortcutHelp({super.key});

  static void show(BuildContext context) {
    showDialog(context: context, builder: (_) => const PosShortcutHelp());
  }

  @override
  Widget build(BuildContext context) {
    const groups = [
      (
        'Navigation',
        [
          ('Ctrl+F  or  /', 'Focus product search'),
          ('Ctrl+K', 'Go to kitchen'),
          ('Ctrl+→ / Ctrl+←', 'Next / prev category'),
          ('↑ ↓ ← →', 'Navigate product list'),
          ('Tab / Shift+Tab', 'Move between fields'),
        ]
      ),
      (
        'F-Keys',
        [
          ('F1', 'New order / go to POS'),
          ('F2', 'Open cart'),
          ('F3', 'Hold current order'),
          ('F4', 'Add / edit customer'),
          ('F5', 'Refresh inventory'),
          ('F6', 'Go to kitchen'),
        ]
      ),
      (
        'Actions',
        [
          ('Enter', 'Confirm / add focused item'),
          ('Escape', 'Cancel dialog / clear search'),
          ('Delete', 'Remove focused item'),
          ('Ctrl+Z', 'Undo last cart action'),
          ('Ctrl+Enter', 'Go to checkout'),
          ('Ctrl+Delete', 'Clear entire cart'),
        ]
      ),
      (
        'Checkout',
        [
          ('0–9 / Numpad', 'Enter cash amount'),
          ('Backspace', 'Delete last digit'),
          ('Enter', 'Confirm payment'),
          ('Escape', 'Back to POS'),
        ]
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFFFFFF),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.keyboard_rounded,
                        color: Color(0xFF534AB7), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text('Keyboard Shortcuts',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111118))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close (Esc)',
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF9999AE), size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: groups.map((group) {
                  return SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.$1,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF534AB7),
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ...group.$2.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  _KeyBadge(s.$1),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(s.$2,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B6B80))),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Press  ?  anytime to show this',
                    style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF9999AE),
                        fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String label;
  const _KeyBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFCCCCD4), width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111118),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
