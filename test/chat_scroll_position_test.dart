import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chat/chat_space_screen.dart';
import 'package:casama/features/chat/direct_chat_screen.dart';
import 'package:casama/features/chat/group_chat_screen.dart';
import 'package:casama/features/chat/widgets/chat_thread_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapScreen(
    MockRepository repo,
    Widget child, {
    bool disableAnimations = false,
  }) {
    return ProviderScope(
      overrides: [repositoryProvider.overrideWith((ref) => repo)],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: disableAnimations,
        ),
        child: MaterialApp(
          theme: CasamaTheme.lightTheme,
          home: child,
        ),
      ),
    );
  }

  void configurePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> scrollUpInReversedList(
    WidgetTester tester,
    Finder listFinder, {
    double deltaY = 450,
  }) async {
    await tester.drag(listFinder, Offset(0, deltaY));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'CasamaChatMessageList renders multi-day date dividers visually above each day and anchors at bottom',
    (tester) async {
      configurePhoneViewport(tester);

      final referenceNow = DateTime(2026, 11, 27, 15, 0);
      final yesterdayBase = DateTime(2026, 11, 26, 9, 0);
      final todayBase = DateTime(2026, 11, 27, 9, 0);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      final messages = <ChatMessage>[
        for (var i = 0; i < 14; i++)
          ChatMessage(
            id: 'y_$i',
            senderId: 'u2',
            senderName: 'Maria',
            content: 'Yesterday msg $i',
            createdAt: yesterdayBase.add(Duration(minutes: i * 5)),
            isCurrentUser: i.isOdd,
          ),
        for (var i = 0; i < 14; i++)
          ChatMessage(
            id: 't_$i',
            senderId: 'u2',
            senderName: 'Maria',
            content: 'Today msg $i',
            createdAt: todayBase.add(Duration(minutes: i * 5)),
            isCurrentUser: i.isOdd,
          ),
      ];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: Scaffold(
              body: CasamaChatMessageList(
                controller: controller,
                messages: messages,
                referenceNow: referenceNow,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byType(ListView);
      final listView = tester.widget<ListView>(listFinder);
      expect(listView.reverse, isTrue);
      expect(controller.offset, 0.0);

      final listRect = tester.getRect(listFinder);
      expect(find.text('Today msg 13'), findsOneWidget);
      final newestRect = tester.getRect(find.text('Today msg 13'));
      expect(newestRect.top, greaterThanOrEqualTo(listRect.top));
      expect(newestRect.bottom, lessThanOrEqualTo(listRect.bottom));
      expect(find.text('Yesterday msg 0'), findsNothing);

      // Scroll up until Today divider and Today msg 0 are visible
      for (var i = 0; i < 4 && find.text('Today').evaluate().isEmpty; i++) {
        await scrollUpInReversedList(tester, listFinder);
      }
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Today msg 0'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Today')).dy,
        lessThan(tester.getTopLeft(find.text('Today msg 0')).dy),
      );

      // Scroll up further to Yesterday msg 0 and Yesterday divider
      for (
        var i = 0;
        i < 8 && find.text('Yesterday').evaluate().isEmpty;
        i++
      ) {
        await scrollUpInReversedList(tester, listFinder);
      }
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Yesterday msg 0'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Yesterday')).dy,
        lessThan(tester.getTopLeft(find.text('Yesterday msg 0')).dy),
      );
    },
  );

  testWidgets(
    'GroupChatScreen opens at newest message, preserves scroll when reading history, and auto-scrolls on send/near-bottom Realtime',
    (tester) async {
      configurePhoneViewport(tester);
      final repo = MockRepository()..login();
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 0, 1);
      final seededFirst = repo.groupMessages.first.content;

      for (var i = 0; i < 28; i++) {
        repo.addGroupMessageForTest(
          ChatMessage(
            id: 'grp_scroll_$i',
            senderId: '22222222-2222-2222-2222-222222222222',
            senderName: 'Maria',
            content: 'Group scroll msg $i',
            createdAt: base.add(Duration(minutes: i + 1)),
            isCurrentUser: false,
          ),
        );
      }

      await tester.pumpWidget(wrapScreen(repo, const GroupChatScreen()));
      await tester.pumpAndSettle();

      final listFinder = find.byType(ListView);
      final listView = tester.widget<ListView>(listFinder);
      expect(listView.reverse, isTrue);
      final controller = listView.controller!;
      expect(controller.offset, 0.0);

      final listRect = tester.getRect(listFinder);
      expect(find.text('Group scroll msg 27'), findsOneWidget);
      final newestRect = tester.getRect(find.text('Group scroll msg 27'));
      expect(newestRect.top, greaterThanOrEqualTo(listRect.top));
      expect(newestRect.bottom, lessThanOrEqualTo(listRect.bottom));
      expect(find.text(seededFirst), findsNothing);

      // Scroll up to read older messages (> 120.0 offset)
      await scrollUpInReversedList(tester, listFinder, deltaY: 500);
      final offsetAfterScrollUp = controller.offset;
      expect(offsetAfterScrollUp, greaterThan(120.0));

      // Incoming Realtime message while scrolled up must NOT yank user down
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'grp_realtime_while_up',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Incoming while reading up',
          createdAt: base.add(const Duration(minutes: 40)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(120.0));

      // Sending a message as current user returns to 0.0 and shows new bubble
      await tester.enterText(find.byType(TextField), 'My new group reply');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(controller.offset, 0.0);
      expect(find.text('My new group reply'), findsOneWidget);

      // Incoming Realtime message while near bottom stays anchored at 0.0
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'grp_realtime_at_bottom',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Incoming at bottom',
          createdAt: base.add(const Duration(minutes: 45)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 0.0);
      expect(find.text('Incoming at bottom'), findsOneWidget);
    },
  );

  testWidgets(
    'DirectChatScreen opens at newest message, preserves scroll when reading history, and auto-scrolls on send/near-bottom Realtime',
    (tester) async {
      configurePhoneViewport(tester);
      final repo = MockRepository()..login();
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 0, 1);
      final seededFirst = repo.getDirectMessages('maria').first.content;

      for (var i = 0; i < 28; i++) {
        repo.addIncomingDirectMessageForTest(
          'maria',
          ChatMessage(
            id: 'dm_scroll_$i',
            senderId: '22222222-2222-2222-2222-222222222222',
            senderName: 'Maria',
            content: 'DM scroll msg $i',
            createdAt: base.add(Duration(minutes: i + 1)),
            isCurrentUser: false,
          ),
        );
      }

      await tester.pumpWidget(
        wrapScreen(
          repo,
          const DirectChatScreen(contactKey: 'maria', contactName: 'Maria'),
        ),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byType(ListView);
      final listView = tester.widget<ListView>(listFinder);
      expect(listView.reverse, isTrue);
      final controller = listView.controller!;
      expect(controller.offset, 0.0);

      final listRect = tester.getRect(listFinder);
      expect(find.text('DM scroll msg 27'), findsOneWidget);
      final newestRect = tester.getRect(find.text('DM scroll msg 27'));
      expect(newestRect.top, greaterThanOrEqualTo(listRect.top));
      expect(newestRect.bottom, lessThanOrEqualTo(listRect.bottom));
      expect(find.text(seededFirst), findsNothing);

      // Scroll up (> 120.0)
      await scrollUpInReversedList(tester, listFinder, deltaY: 500);
      expect(controller.offset, greaterThan(120.0));

      // Incoming DM while scrolled up does not yank user to bottom
      repo.addIncomingDirectMessageForTest(
        'maria',
        ChatMessage(
          id: 'dm_realtime_while_up',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'DM while reading up',
          createdAt: base.add(const Duration(minutes: 40)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(120.0));

      // Send DM returns to 0.0
      await tester.enterText(find.byType(TextField), 'My DM reply');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(controller.offset, 0.0);
      expect(find.text('My DM reply'), findsOneWidget);

      // Incoming DM while near bottom stays at 0.0
      repo.addIncomingDirectMessageForTest(
        'maria',
        ChatMessage(
          id: 'dm_realtime_at_bottom',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'DM incoming at bottom',
          createdAt: base.add(const Duration(minutes: 45)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 0.0);
      expect(find.text('DM incoming at bottom'), findsOneWidget);
    },
  );

  testWidgets(
    'ChatSpaceScreen opens at newest message, preserves scroll when reading history, and auto-scrolls on send/near-bottom Realtime',
    (tester) async {
      configurePhoneViewport(tester);
      final repo = MockRepository()..login();
      final space = repo.chatSpaces.first;
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 0, 1);
      final seededFirst = space.messages.first.content;

      for (var i = 0; i < 28; i++) {
        repo.addSpaceMessageForTest(
          space.id,
          ChatMessage(
            id: 'spc_scroll_$i',
            senderId: '22222222-2222-2222-2222-222222222222',
            senderName: 'Maria',
            content: 'Space scroll msg $i',
            createdAt: base.add(Duration(minutes: i + 1)),
            isCurrentUser: false,
          ),
        );
      }

      await tester.pumpWidget(
        wrapScreen(repo, ChatSpaceScreen(spaceId: space.id)),
      );
      await tester.pumpAndSettle();

      final listFinder = find.byType(ListView);
      final listView = tester.widget<ListView>(listFinder);
      expect(listView.reverse, isTrue);
      final controller = listView.controller!;
      expect(controller.offset, 0.0);

      final listRect = tester.getRect(listFinder);
      expect(find.text('Space scroll msg 27'), findsOneWidget);
      final newestRect = tester.getRect(find.text('Space scroll msg 27'));
      expect(newestRect.top, greaterThanOrEqualTo(listRect.top));
      expect(newestRect.bottom, lessThanOrEqualTo(listRect.bottom));
      expect(find.text(seededFirst), findsNothing);

      // Scroll up (> 120.0)
      await scrollUpInReversedList(tester, listFinder, deltaY: 500);
      expect(controller.offset, greaterThan(120.0));

      // Incoming Space message while scrolled up does not yank user down
      repo.addSpaceMessageForTest(
        space.id,
        ChatMessage(
          id: 'spc_realtime_while_up',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Space while reading up',
          createdAt: base.add(const Duration(minutes: 40)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(120.0));

      // Send Space message returns to 0.0 (with reduced motion enabled)
      await tester.enterText(find.byType(TextField), 'My Space reply');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(controller.offset, 0.0);
      expect(find.text('My Space reply'), findsOneWidget);

      // Incoming Space message while near bottom stays at 0.0
      repo.addSpaceMessageForTest(
        space.id,
        ChatMessage(
          id: 'spc_realtime_at_bottom',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Space incoming at bottom',
          createdAt: base.add(const Duration(minutes: 45)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 0.0);
      expect(find.text('Space incoming at bottom'), findsOneWidget);
    },
  );

  testWidgets(
    'CasamaMessageBubble reserves 230x170 attachment box and reduced-motion send jumps to 0.0 cleanly',
    (tester) async {
      configurePhoneViewport(tester);
      final repo = MockRepository()..login();
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 0, 1);

      for (var i = 0; i < 20; i++) {
        repo.addGroupMessageForTest(
          ChatMessage(
            id: 'rm_msg_$i',
            senderId: '22222222-2222-2222-2222-222222222222',
            senderName: 'Maria',
            content: 'Reduced motion msg $i',
            attachmentUrl: i == 19 ? 'https://example.com/photo.jpg' : null,
            createdAt: base.add(Duration(minutes: i + 1)),
            isCurrentUser: false,
          ),
        );
      }

      await tester.pumpWidget(
        wrapScreen(repo, const GroupChatScreen(), disableAnimations: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final clipFinder = find.byType(ClipRRect).first;
      expect(tester.getSize(clipFinder), const Size(230, 170));

      final listFinder = find.byType(ListView);
      final controller = tester.widget<ListView>(listFinder).controller!;
      await tester.drag(listFinder, const Offset(0, 450));
      await tester.pump();
      expect(controller.offset, greaterThan(120.0));

      await tester.enterText(find.byType(TextField), 'Reduced motion jump');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump();

      expect(controller.offset, 0.0);
      expect(find.text('Reduced motion jump'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
