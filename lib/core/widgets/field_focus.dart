import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Lets go of a text field the way a phone should.
///
/// On Android, Flutter keeps a field focused until something else asks for
/// the focus. A tap beside it, or the back gesture that only closes the
/// keyboard, left the cursor blinking - and a page you came back to handed
/// the focus back to that field, keyboard and all. Here a tap outside the
/// field lets go of it, and so does the keyboard closing while a field still
/// has the focus.
///
/// A tap, not a scroll: a finger that moves is reading the page, and the
/// field stays. Something that belongs with a field, like the send button of
/// the chat, sits in a [TextFieldTapRegion] and counts as part of it.
class ReleaseFieldFocus extends StatefulWidget {
  const ReleaseFieldFocus({super.key, required this.child});

  final Widget child;

  @override
  State<ReleaseFieldFocus> createState() => _ReleaseFieldFocusState();
}

class _ReleaseFieldFocusState extends State<ReleaseFieldFocus>
    with WidgetsBindingObserver {
  PointerDownEvent? _down;
  double? _keyboard;

  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: _tapDownOutside,
    ),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(onInvoke: _tapUpOutside),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Object? _tapDownOutside(EditableTextTapOutsideIntent intent) {
    switch (intent.pointerDownEvent.kind) {
      case PointerDeviceKind.touch:
        // Whether it was a tap shows when the finger comes up.
        _down = intent.pointerDownEvent;
      default:
        // A mouse or a pen lets go at once, as Flutter itself does.
        intent.focusNode.unfocus();
    }
    return null;
  }

  Object? _tapUpOutside(EditableTextTapUpOutsideIntent intent) {
    final down = _down;
    _down = null;
    final up = intent.pointerUpEvent;
    if (down == null || down.pointer != up.pointer) return null;
    if ((up.position - down.position).distance < kTouchSlop) {
      intent.focusNode.unfocus();
    }
    return null;
  }

  @override
  void didChangeMetrics() {
    final keyboard = View.of(context).viewInsets.bottom;
    final was = _keyboard;
    _keyboard = keyboard;
    if (was == null || was == 0 || keyboard > 0) return;

    // The keyboard went away, and a field still has the focus: the back
    // gesture closed it, and that is leaving the field too.
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      focus!.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    _keyboard ??= View.of(context).viewInsets.bottom;
    return Actions(actions: _actions, child: widget.child);
  }
}
