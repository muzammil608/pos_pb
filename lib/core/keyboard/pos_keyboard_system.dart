// lib/core/keyboard/pos_keyboard_system.dart
//
// High-ROI POS keyboard system.
// Packages: hotkey_manager (F-keys + global shortcuts), flutter built-ins
// (Shortcuts/Actions/Focus) for navigation, Enter, Escape, Delete, arrows.
//
// ── FIXES IN THIS VERSION ──────────────────────────────────────────────────
//
// FIX 1 — ESC corrupts nav state and blocks Ready Orders sheet from reopening.
//   Root cause: ClearSearchIntent's onInvoke called nav.pop() whenever
//   canPop() was true, which consumed the bottom-sheet route. The next ESC
//   then popped a screen-level route, leaving the navigator in a broken state
//   so _showReadyOrdersSheet could never push again.
//   Fix: ClearSearchIntent now ONLY clears the search bar text. It never
//   touches the navigator. Bottom sheets and dialogs handle their own ESC
//   dismiss via Flutter's built-in PopScope / barrierDismissible behaviour.
//
// FIX 2 — Physical numpad keys (right side, Numpad0–Numpad9) ignored in cash field.
//   Root cause: PosShortcuts.numpad only mapped LogicalKeyboardKey.digit0–9.
//   Physical numpad keys produce LogicalKeyboardKey.numpad0–numpad9 which are
//   completely different logical codes that were never in the map.
//   Fix: Added all numpad logical keys (numpad0–numpad9, numpadDecimal, etc.)
//   to the shortcut map alongside the existing top-row digit entries.
//
// FIX 3 — Top-row digit keys wrote to cash field even when it was not focused.
//   Root cause: CheckoutKeyboardScope._handleNumpad called
//   cashFocusNode?.requestFocus() unconditionally before writing, so pressing
//   any digit anywhere always stole focus and wrote to the cash field —
//   including while typing in the Customer Name text field.
//   Fix: _handleNumpad now writes only when cashFocusNode.hasFocus is already
//   true. Focus is never stolen. The cash field works normally once the user
//   clicks or Tabs into it.
//
// FIX 4 — MissingPluginException on Android/iOS.
//   hotkey_manager is a desktop-only plugin (Windows, macOS, Linux).
//   All hotKeyManager calls are now guarded by _isDesktop so the app runs
//   safely on mobile without crashing.
//
// FIX 5 — RenderFlex overflow in PosShortcutHelp on small screens.
//   _KeyBadge now has a maxWidth constraint + TextOverflow.ellipsis.
//   The dialog body is wrapped in SingleChildScrollView to handle vertical
//   overflow on small viewports.
//
// FIX 6 — Keyboard shortcut button + dialog shown on mobile.
//   ShowShortcutsIntent is now guarded by _isDesktop so pressing '?' on a
//   physical keyboard connected to a phone does nothing.
//   The AppBar button is hidden on mobile — callers should also guard it
//   (see pos_screen.dart).
//
// FIX 7 — F7/F8 not working on POS screen cash/card buttons.
//   Root cause: SelectPaymentMethodIntent (F7/F8) was only registered in
//   CheckoutKeyboardScope's numpad shortcut map and Actions. When the
//   cash/card buttons live on the POS screen, PosKeyboardScope never saw
//   those intents — posScreen map had no F7/F8 entries and PosKeyboardScope
//   had no SelectPaymentMethodIntent action handler.
//   Fix: Added F7/F8 to PosShortcuts.posScreen and wired
//   SelectPaymentMethodIntent + onSelectPaymentMethod callback into
//   PosKeyboardScope.
//
// FIX 8 — Double-ESC breaks navigator state so F2 Ready Orders sheet won't open.
//   Root cause: PosShortcuts.numpad mapped Escape → NumpadKeyIntent('ESC'),
//   and _handleNumpad called widget.onBack?.call() for that key. When
//   CheckoutKeyboardScope was anywhere in the widget tree it intercepted every
//   ESC — including ESCs meant to dismiss a bottom sheet — and called onBack
//   which popped an extra route. A second ESC left the navigator in a broken
//   state where _showReadyOrdersSheet could no longer push.
//   Fix: Removed Escape from PosShortcuts.numpad entirely. Removed the ESC
//   branch from _handleNumpad. Checkout back-navigation is now handled solely
//   by PopScope / WillPopScope on the checkout route (barrierDismissible) so
//   no double-pop is possible.
//
// ADDITION 1 — CheckoutKeyboardScope auto-focuses cash field on mount.
//   Uses addPostFrameCallback so the focus system is ready before requesting.
//
// ADDITION 2 — Kitchen screen keyboard intents + KitchenKeyboardScope widget.
//   Wrap your kitchen screen body with KitchenKeyboardScope and supply the
//   five callbacks (onNavigate, onEdit, onDelete, onConfirm, onReadyOrder).
//   Shortcuts: ↑/↓ navigate, E edit, Delete remove, Enter = Mark Ready.
//
// ADDITION 3 — SelectPaymentMethodIntent for checkout payment method selection.
//   F7 = Cash, F8 = Card. Now works from BOTH PosKeyboardScope and
//   CheckoutKeyboardScope. Wire onSelectPaymentMethod on whichever scope
//   wraps your cash/card buttons.
// ──────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PLATFORM HELPER
// ═══════════════════════════════════════════════════════════════════════════════

/// True only on desktop platforms that support hotkey_manager.
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

// ═══════════════════════════════════════════════════════════════════════════════
// INTENT DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

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

// ── ADDITION 3: Payment method selection intent ───────────────────────────────

/// Selects a payment method on the checkout screen.
/// [method] is 'cash' or 'card' (or any other method string your app supports).
/// Triggered by F7 (cash) and F8 (card).
/// FIX 7: Now also registered in PosKeyboardScope so buttons on the POS
/// screen respond to F7/F8 without needing CheckoutKeyboardScope in the tree.
class SelectPaymentMethodIntent extends Intent {
  final String method;
  const SelectPaymentMethodIntent(this.method);
}

// ── Kitchen-specific intents ──────────────────────────────────────────────────

/// Navigate up/down through the kitchen order list.
class KitchenNavigateIntent extends Intent {
  final bool up;
  const KitchenNavigateIntent({required this.up});
}

/// Open the edit-quantity dialog for the focused kitchen order item.
class KitchenEditItemIntent extends Intent {
  const KitchenEditItemIntent();
}

/// Delete / remove the focused kitchen order item.
class KitchenDeleteItemIntent extends Intent {
  const KitchenDeleteItemIntent();
}

/// Called when Enter is pressed (legacy confirm — kept for compatibility).
class KitchenConfirmItemIntent extends Intent {
  const KitchenConfirmItemIntent();
}

/// Mark the focused kitchen order as READY (Enter key on kitchen screen).
class KitchenReadyOrderIntent extends Intent {
  const KitchenReadyOrderIntent();
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHORTCUT MAPS
// ═══════════════════════════════════════════════════════════════════════════════

class PosShortcuts {
  /// POS screen shortcuts (handled by Shortcuts widget + Actions).
  static Map<ShortcutActivator, Intent> posScreen = {
    // Search
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FocusSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.slash): const FocusSearchIntent(),

    // Clear / cancel — FIX 1: handler no longer calls nav.pop()
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

    // ── FIX 7: Payment method selection on the POS screen (F7/F8) ────────────
    // These are also in PosShortcuts.numpad for the checkout scope.
    // Duplicating here ensures they work wherever PosKeyboardScope is the
    // active scope — i.e. when your cash/card buttons are on the POS screen.
    const SingleActivator(LogicalKeyboardKey.f7):
        SelectPaymentMethodIntent('cash'),
    const SingleActivator(LogicalKeyboardKey.f8):
        SelectPaymentMethodIntent('card'),
  };

  // ── FIX 2: Added physical numpad logical keys (right side of keyboard). ────
  // ── FIX 8: Removed Escape from this map — see FIX 8 note above. ──────────
  // ── ADDITION 3: F7/F8 payment method shortcuts. ───────────────────────────
  static Map<ShortcutActivator, Intent> numpad = {
    // Top-row digit keys (above letter keys)
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

    // Physical numpad keys (right-side number pad) — FIX 2
    const SingleActivator(LogicalKeyboardKey.numpad0): NumpadKeyIntent('0'),
    const SingleActivator(LogicalKeyboardKey.numpad1): NumpadKeyIntent('1'),
    const SingleActivator(LogicalKeyboardKey.numpad2): NumpadKeyIntent('2'),
    const SingleActivator(LogicalKeyboardKey.numpad3): NumpadKeyIntent('3'),
    const SingleActivator(LogicalKeyboardKey.numpad4): NumpadKeyIntent('4'),
    const SingleActivator(LogicalKeyboardKey.numpad5): NumpadKeyIntent('5'),
    const SingleActivator(LogicalKeyboardKey.numpad6): NumpadKeyIntent('6'),
    const SingleActivator(LogicalKeyboardKey.numpad7): NumpadKeyIntent('7'),
    const SingleActivator(LogicalKeyboardKey.numpad8): NumpadKeyIntent('8'),
    const SingleActivator(LogicalKeyboardKey.numpad9): NumpadKeyIntent('9'),
    const SingleActivator(LogicalKeyboardKey.numpadDecimal):
        NumpadKeyIntent('.'),
    const SingleActivator(LogicalKeyboardKey.numpadAdd): NumpadKeyIntent('+'),

    // Common keys
    const SingleActivator(LogicalKeyboardKey.backspace): NumpadKeyIntent('⌫'),
    const SingleActivator(LogicalKeyboardKey.period): NumpadKeyIntent('.'),
    // ── FIX 8: Escape intentionally NOT mapped here. ──────────────────────
    // Checkout back-navigation must go through the route's PopScope so the
    // navigator pops exactly once. Mapping ESC → NumpadKeyIntent('ESC') and
    // then calling onBack in _handleNumpad caused a double-pop that corrupted
    // the navigator, preventing the Ready Orders sheet from reopening.
    // Add a PopScope(onPopInvoked: ...) to your checkout screen/dialog instead.
    const SingleActivator(LogicalKeyboardKey.enter): ConfirmItemIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter): ConfirmItemIntent(),

    // ADDITION 3: Payment method selection — F7 = Cash, F8 = Card
    const SingleActivator(LogicalKeyboardKey.f7):
        SelectPaymentMethodIntent('cash'),
    const SingleActivator(LogicalKeyboardKey.f8):
        SelectPaymentMethodIntent('card'),
  };

  /// Kitchen screen shortcuts.
  static Map<ShortcutActivator, Intent> kitchen = {
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        KitchenNavigateIntent(up: true),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        KitchenNavigateIntent(up: false),
    const SingleActivator(LogicalKeyboardKey.keyE):
        const KitchenEditItemIntent(),
    const SingleActivator(LogicalKeyboardKey.delete):
        const KitchenDeleteItemIntent(),
    const SingleActivator(LogicalKeyboardKey.enter):
        const KitchenReadyOrderIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const KitchenReadyOrderIntent(),
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL HOTKEY REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

class PosHotkeyRegistry {
  PosHotkeyRegistry._();

  static final List<HotKey> _registered = [];

  /// FIX 4: Guard every hotKeyManager call with _isDesktop.
  static Future<void> init() async {
    if (!_isDesktop) return;
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
    if (!_isDesktop) return; // FIX 4: no-op on mobile/web
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
    if (!_isDesktop) return; // FIX 4: no-op on mobile/web
    final copy = List<HotKey>.from(_registered);
    _registered.clear();
    for (final hk in copy) {
      await hotKeyManager.unregister(hk);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNDO STACK
// ═══════════════════════════════════════════════════════════════════════════════

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
// POS KEYBOARD SCOPE
// ═══════════════════════════════════════════════════════════════════════════════

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

  // ── FIX 7: Added onSelectPaymentMethod so POS-screen cash/card buttons
  //    respond to F7/F8 when wrapped by PosKeyboardScope. ──────────────────
  final ValueChanged<String>? onSelectPaymentMethod;

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
    this.onSelectPaymentMethod, // FIX 7
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

          // ── FIX 1 ──────────────────────────────────────────────────────────
          ClearSearchIntent: CallbackAction<ClearSearchIntent>(
            onInvoke: (_) {
              searchBarKey?.currentState?.clear();
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

          // ── FIX 6: Only show shortcut help on desktop ─────────────────────
          ShowShortcutsIntent: CallbackAction<ShowShortcutsIntent>(
            onInvoke: (_) {
              if (_isDesktop) {
                PosShortcutHelp.show(context);
              }
              return null;
            },
          ),

          // ── FIX 7: Handle F7/F8 payment method selection on POS screen ────
          SelectPaymentMethodIntent: CallbackAction<SelectPaymentMethodIntent>(
            onInvoke: (intent) {
              onSelectPaymentMethod?.call(intent.method);
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
// ═══════════════════════════════════════════════════════════════════════════════

class CheckoutKeyboardScope extends StatefulWidget {
  final Widget child;
  final TextEditingController? cashController;
  final FocusNode? cashFocusNode;
  final ValueChanged<String>? onCashChanged;
  final VoidCallback? onBack;
  final VoidCallback? onConfirm;

  // ADDITION 3: Callback to switch payment method via keyboard (F7/F8).
  // Receives 'cash' or 'card' as the method string.
  final ValueChanged<String>? onSelectPaymentMethod;

  const CheckoutKeyboardScope({
    super.key,
    required this.child,
    this.cashController,
    this.cashFocusNode,
    this.onCashChanged,
    this.onBack,
    this.onConfirm,
    this.onSelectPaymentMethod, // ADDITION 3
  });

  @override
  State<CheckoutKeyboardScope> createState() => _CheckoutKeyboardScopeState();
}

class _CheckoutKeyboardScopeState extends State<CheckoutKeyboardScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.cashFocusNode?.requestFocus();
    });
  }

  // ── FIX 8: Removed the ESC → onBack branch entirely. ─────────────────────
  // ESC is no longer in PosShortcuts.numpad so this method is never called
  // with key == 'ESC'. Back/dismiss must be handled by the checkout route's
  // PopScope so the navigator pops exactly once and the Ready Orders sheet
  // can be reopened normally afterwards.
  void _handleNumpad(String key) {
    final ctrl = widget.cashController;
    if (ctrl == null) return;

    // ── FIX 3: only write when cash field is already focused ─────────────────
    final hasFocus =
        widget.cashFocusNode == null || widget.cashFocusNode!.hasFocus;
    if (!hasFocus) return;

    final current = ctrl.text;
    late String next;
    if (key == '⌫') {
      next = current.isEmpty ? '' : current.substring(0, current.length - 1);
    } else if (key == '.') {
      next = current.contains('.') ? current : '$current.';
    } else if (key == '+') {
      return;
    } else {
      next = current.isEmpty || current == '0' ? key : '$current$key';
    }
    ctrl.text = next;
    ctrl.selection = TextSelection.collapsed(offset: next.length);
    widget.onCashChanged?.call(next);
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
              widget.onConfirm?.call();
              return null;
            },
          ),

          // ADDITION 3: Handle F7/F8 to select payment method ─────────────────
          SelectPaymentMethodIntent: CallbackAction<SelectPaymentMethodIntent>(
            onInvoke: (intent) {
              widget.onSelectPaymentMethod?.call(intent.method);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KITCHEN KEYBOARD SCOPE
// ═══════════════════════════════════════════════════════════════════════════════

class KitchenKeyboardScope extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool>? onNavigate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onConfirm;
  final VoidCallback? onReadyOrder;

  const KitchenKeyboardScope({
    super.key,
    required this.child,
    this.onNavigate,
    this.onEdit,
    this.onDelete,
    this.onConfirm,
    this.onReadyOrder,
  });

  @override
  State<KitchenKeyboardScope> createState() => _KitchenKeyboardScopeState();
}

class _KitchenKeyboardScopeState extends State<KitchenKeyboardScope> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'KitchenKeyboardScope');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onNavigate?.call(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onNavigate?.call(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      (widget.onReadyOrder ?? widget.onConfirm)?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      widget.onEdit?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      widget.onDelete?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOCUS INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════

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
// ═══════════════════════════════════════════════════════════════════════════════

class PosSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  // FIX 6: null means "auto" — resolved at build time so _isDesktop (non-const) is safe
  final String? hintText;

  const PosSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.hintText,
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
          hintText: widget.hintText ??
              (_isDesktop ? 'Search items…  ( / or Ctrl+F )' : 'Search items…'),
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
              // FIX 6: only show the '/' key badge on desktop
              : (!_focused && _isDesktop)
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
    // FIX 6: guard at the call site too — safe to call from anywhere
    if (!_isDesktop) return;
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
          // ADDITION 3: Payment method shortcuts in help dialog
          ('F7', 'Select Cash payment'),
          ('F8', 'Select Card payment'),
        ]
      ),
      (
        'Kitchen',
        [
          ('↑ / ↓', 'Navigate order list'),
          ('E', 'Edit quantity of focused item'),
          ('Delete', 'Remove focused item'),
          ('Enter / Numpad ↵', 'Mark order as Ready'),
          ('Escape', 'Go back'),
        ]
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFFFFFFF),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          // ── FIX 5: wrap in SingleChildScrollView to prevent vertical overflow
          child: SingleChildScrollView(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── FIX 5: constrained badge ──────────
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
                const Center(
                  child: Text('Press  ?  anytime to show this',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9999AE),
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── FIX 5: _KeyBadge now has maxWidth + ellipsis to prevent horizontal overflow
class _KeyBadge extends StatelessWidget {
  final String label;
  const _KeyBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
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
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
