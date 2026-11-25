import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/chat/chat_space_screen.dart';
import 'package:casama/features/chat/direct_chat_screen.dart';
import 'package:casama/features/chat/group_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ChatDirectoryScreen renders split hero, pinned household, spaces, and launches Space / Meetup sheets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      final initialSpaceCount = repo.chatSpaces.length;
      final initialGroupMsgs = repo.groupMessages.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const ChatDirectoryScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chat'), findsOneWidget);
      expect(find.textContaining('CONNECT'), findsOneWidget);
      expect(find.text('Household Group Chat'), findsOneWidget);
      expect(find.text('Grocery & Supplies'), findsOneWidget);

      // Open Create Chat Space sheet
      await tester.tap(find.text('+ Space'));
      await tester.pumpAndSettle();
      expect(find.text('Create Chat Space'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Weekend Movie Club',
      );
      await tester.tap(find.text('Create Space & Generate Code'));
      await tester.pumpAndSettle();
      expect(repo.chatSpaces.length, initialSpaceCount + 1);
      expect(
        repo.chatSpaces.any((s) => s.name == 'Weekend Movie Club'),
        isTrue,
      );

      // Open Plan a Meet-up sheet from header action button
      await tester.tap(find.bySemanticsLabel('Plan a Meet-up'));
      await tester.pumpAndSettle();
      expect(find.text('Plan a Meet-up'), findsOneWidget);
      expect(
        find.text('Manual spot label only — zero GPS tracking used.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();
      expect(repo.groupMessages.length, initialGroupMsgs + 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GroupChatScreen updates inline RSVP chips and opens attachment sheet in Dark Mode',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const GroupChatScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MEET-UP INVITATION'), findsOneWidget);
      await tester.tap(find.textContaining('Maybe ('));
      await tester.pumpAndSettle();
      expect(repo.activeMeetUp.currentUserResponse, 'maybe');

      // Open attachment modal sheet
      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Share in Chat'), findsOneWidget);
      expect(find.text('Propose Meet-up Activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ChatSpaceScreen and DirectChatScreen render cleanly in Dark Mode with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      final firstSpace = repo.chatSpaces.first;
      final initialSpaceMsgCount = firstSpace.messages.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: ChatSpaceScreen(spaceId: firstSpace.id),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(firstSpace.name), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Grabbed olive oil!');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      final updatedSpace = repo.chatSpaces.firstWhere(
        (s) => s.id == firstSpace.id,
      );
      expect(updatedSpace.messages.length, initialSpaceMsgCount + 1);

      // Open Space details sheet
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('SPACE INVITATION CODE'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close ${firstSpace.iconEmoji} ${firstSpace.name}'));
      await tester.pumpAndSettle();

      // Pump DirectChatScreen in Dark Mode
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const DirectChatScreen(
                contactKey: 'maria',
                contactName: 'Maria',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maria'), findsWidgets);
      expect(find.text('In living room'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
