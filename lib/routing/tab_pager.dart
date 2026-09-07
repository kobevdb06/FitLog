/// The four tabs, side by side, so a swipe drags the next one into view.
///
/// This replaces the `IndexedStack` that `StatefulShellRoute.indexedStack`
/// puts around the branch navigators. The stack shows one branch and hides the
/// rest, which is why a swipe could only ever jump; a [PageView] lays them out
/// next to each other, so the page follows your finger and settles where you
/// let go.
///
/// The stack held all four branches at once and hid three of them behind an
/// `Offstage`. The pager holds what you can see and lets go of the rest, which
/// is why nothing here has to switch animations off for the tabs you are not
/// looking at: they are not there to animate.
///
/// What that does not cost is your place. go_router keeps each branch's
/// navigator across being dropped and picked up again, so coming back to a tab
/// finds its scroll position, its open sheet and its half-typed note where
/// they were left. `tab_pager_test.dart` holds both halves of that down.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TabPager extends StatefulWidget {
  const TabPager({super.key, required this.shell, required this.branches});

  final StatefulNavigationShell shell;

  /// One navigator per tab, in the order of the navigation bar.
  final List<Widget> branches;

  @override
  State<TabPager> createState() => _TabPagerState();
}

class _TabPagerState extends State<TabPager> {
  late final PageController _controller = PageController(
    initialPage: widget.shell.currentIndex,
  );

  @override
  void didUpdateWidget(TabPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The tab can also change from the navigation bar, or from a link that
    // lands in another branch. Swiping already moved the page itself, so this
    // only has to catch up when something else did the moving.
    final index = widget.shell.currentIndex;
    if (!_controller.hasClients) return;
    if ((_controller.page ?? _controller.initialPage.toDouble()).round() ==
        index) {
      return;
    }
    _controller.jumpToPage(index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      // Where you let go is where you meant to be; the router is told after
      // the page has settled rather than during the drag, so a swipe you pull
      // back does not leave a trail of branch switches behind it.
      onPageChanged: (index) {
        if (index == widget.shell.currentIndex) return;
        widget.shell.goBranch(index);
      },
      children: widget.branches,
    );
  }
}
