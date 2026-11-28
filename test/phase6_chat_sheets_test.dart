import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/calendar/household_calendar_view.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/chat/chat_space_screen.dart';
import 'package:casama/features/chat/direct_chat_screen.dart';
import 'package:casama/features/chat/group_chat_screen.dart';
import 'package:casama/features/chat/widgets/chat_thread_components.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets(
    'ChatDirectoryScreen renders split hero, pinned household, spaces, and launches Space / Housemates Agenda sheets',
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
      expect(find.text('Join Code'), findsNothing);
      expect(find.text('SPC-101'), findsNothing);
      expect(find.text('+ Space'), findsNothing);

      // Open Create Chat Space sheet
      await tester.tap(find.text('Space'));
      await tester.pumpAndSettle();
      expect(find.text('Create Chat Space'), findsOneWidget);
      expect(
        find.textContaining('automatically included in this space'),
        findsOneWidget,
      );
      expect(find.textContaining('ADD HOUSEMATES DIRECTLY'), findsNothing);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Weekend Movie Club',
      );
      await tester.tap(find.text('Create Space'));
      await tester.pumpAndSettle();
      expect(repo.chatSpaces.length, initialSpaceCount + 1);
      expect(
        repo.chatSpaces.any((s) => s.name == 'Weekend Movie Club'),
        isTrue,
      );

      // Top-right Add Housemate / Plan Housemates Agenda header buttons are removed
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
      expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);

      // Open Plan Housemates Agenda sheet from in-body Housemates Agenda 'New' pill
      await tester.ensureVisible(find.text('New'));
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('Plan Housemates Agenda'), findsOneWidget);
      expect(find.text('INVITEES'), findsNothing);
      expect(find.text('All Housemates'), findsNothing);
      expect(
        find.text(
          'Manual location or link label only — zero GPS tracking used.',
        ),
        findsOneWidget,
      );

      // Empty submit is blocked until Activity & Location / Link are filled
      final beforeCreateCount = repo.housematesAgendaInvitations.length;
      await tester.tap(find.text('Send Agenda'));
      await tester.pumpAndSettle();
      expect(repo.housematesAgendaInvitations.length, beforeCreateCount);
      expect(
        find.text('Please enter an activity and location or link.'),
        findsWidgets,
      );

      // Tap quick-fill suggestion chips for Activity and Location / Link
      await tester.ensureVisible(find.text('Online Hangout / Call'));
      await tester.tap(find.text('Online Hangout / Call'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Online / Discord'));
      await tester.tap(find.text('Online / Discord'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Agenda'));
      await tester.pumpAndSettle();
      expect(repo.groupMessages.length, initialGroupMsgs);
      expect(
        repo.housematesAgendaInvitations.length,
        beforeCreateCount + 1,
      );
      final created = repo.housematesAgendaInvitations.firstWhere(
        (m) => m.activity == 'Online Hangout / Call',
      );
      expect(created.location, 'Online / Discord');
      expect(created.creatorId, repo.currentUser.id);
      expect(created.goingCount, 1);
      expect(
        created.maybeCount,
        repo.members.where((m) => m.profile.id != repo.currentUser.id).length,
      );
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

      expect(find.text('HOUSEMATES AGENDA'), findsNothing);

      // Open attachment modal sheet
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Share in Chat'), findsOneWidget);
      expect(find.text('Plan Housemates Agenda'), findsOneWidget);
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
      expect(find.text('SPACE INVITATION CODE'), findsNothing);
      expect(
        find.textContaining('automatically included in this space'),
        findsOneWidget,
      );
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

  testWidgets(
    'ChatDirectoryScreen hides phantom Housemates Agenda card when empty and opens RSVP sheet from View',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyRepo = MockRepository()..login();
      await emptyRepo.createHousematesAgendaInvitation(
        activity: '   ',
        location: '',
        scheduledTime: DateTime.now(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => emptyRepo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('No active agendas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No active agendas'), findsOneWidget);
      expect(find.text('View'), findsNothing);

      final activeRepo = MockRepository()..login();
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [repositoryProvider.overrideWith((ref) => activeRepo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active agendas'), findsNothing);
      expect(find.text('View'), findsNothing);
      expect(find.text('Tap to view'), findsOneWidget);
      await tester.ensureVisible(find.text('Study Session 🎓'));
      await tester.tap(find.text('Study Session 🎓'));
      await tester.pumpAndSettle();

      expect(find.text('Housemates Agenda'), findsWidgets);
      expect(find.text('None yet'), findsOneWidget);
      expect(find.byType(Tooltip), findsWidgets);

      await tester.tap(find.textContaining('Maybe (').first);
      await tester.pumpAndSettle();
      expect(activeRepo.activeHousematesAgenda.currentUserResponse, 'maybe');
      expect(
        activeRepo.activeHousematesAgenda.maybeResponders
            .any((r) => r.userId == activeRepo.currentUser.id),
        isTrue,
      );
      expect(
        activeRepo.activeHousematesAgenda.goingResponders
            .any((r) => r.userId == activeRepo.currentUser.id),
        isFalse,
      );

      await tester.tap(find.byKey(const Key('agenda_responders_Maybe')));
      await tester.pumpAndSettle();
      expect(find.text(activeRepo.currentUser.preferredName), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CasamaMessageBubble renders sending, delivered, and failed states with tap-to-retry',
    (tester) async {
      var retried = false;

      Widget buildBubble(
        MessageDeliveryStatus status, {
        ThemeMode themeMode = ThemeMode.light,
        bool disableAnimations = false,
      }) {
        return MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: disableAnimations,
          ),
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: themeMode,
            home: Scaffold(
              body: CasamaMessageBubble(
                message: ChatMessage(
                  id: 'm1',
                  senderId: 'u1',
                  senderName: 'Alex',
                  content: 'Testing delivery state',
                  createdAt: DateTime(2026, 1, 1, 19, 0),
                  isCurrentUser: true,
                  deliveryStatus: status,
                ),
                timeLabel: '7:00 PM',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildBubble(MessageDeliveryStatus.sending));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);

      await tester.pumpWidget(
        buildBubble(MessageDeliveryStatus.sending, disableAnimations: true),
      );
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      await tester.pumpWidget(buildBubble(MessageDeliveryStatus.delivered));
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

      await tester.pumpWidget(
        buildBubble(MessageDeliveryStatus.failed, themeMode: ThemeMode.dark),
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Failed to send · Tap to retry'), findsOneWidget);

      await tester.tap(find.text('Failed to send · Tap to retry'));
      await tester.pump();
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Plan Housemates Agenda opens native Date and Time pickers',
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
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('New'));
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.schedule_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CasamaChatComposer enforces single-slot attachment staging, replace, remove, and photo-only send',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      XFile? staged = XFile('/tmp/first.jpg');
      var sendCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: CasamaTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CasamaChatComposer(
                  controller: controller,
                  hintText: 'Message...',
                  pendingAttachment: staged,
                  onAttach: () {},
                  onReplaceAttachment: () =>
                      setState(() => staged = XFile('/tmp/second.jpg')),
                  onRemoveAttachment: () => setState(() => staged = null),
                  onSend: () {
                    if (controller.text.trim().isEmpty && staged == null) {
                      return;
                    }
                    sendCount++;
                    controller.clear();
                    setState(() => staged = null);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('1 photo attached'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.bySemanticsLabel('Remove attachment'), findsOneWidget);

      // Replace keeps strictly 1 attachment slot
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text('1 photo attached'), findsOneWidget);
      expect(staged?.path, '/tmp/second.jpg');

      // Send enabled even with empty text
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(sendCount, 1);
      expect(find.text('1 photo attached'), findsNothing);

      // Tapping send when both text and attachment are empty does nothing
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(sendCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CasamaMessageBubble renders photo-only & captioned attachments and opens Lightbox',
    (tester) async {
      const tinyPngDataUrl =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: Scaffold(
              body: Column(
                children: [
                  CasamaMessageBubble(
                    message: ChatMessage(
                      id: 'p1',
                      senderId: 'u1',
                      senderName: 'Alex',
                      content: '',
                      attachmentUrl: tinyPngDataUrl,
                      createdAt: DateTime(2026, 1, 1, 19, 0),
                      isCurrentUser: true,
                      deliveryStatus: MessageDeliveryStatus.delivered,
                    ),
                    timeLabel: '7:00 PM',
                  ),
                  CasamaMessageBubble(
                    message: ChatMessage(
                      id: 'p2',
                      senderId: 'u2',
                      senderName: 'Maria',
                      content: 'Dinner is ready!',
                      attachmentUrl: tinyPngDataUrl,
                      createdAt: DateTime(2026, 1, 1, 19, 1),
                      isCurrentUser: false,
                      deliveryStatus: MessageDeliveryStatus.delivered,
                    ),
                    timeLabel: '7:01 PM',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dinner is ready!'), findsOneWidget);
      expect(find.bySemanticsLabel('View attached photo'), findsNWidgets(2));

      // Open Lightbox on first delivered photo
      await tester.tap(find.bySemanticsLabel('View attached photo').first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ChatDirectoryScreen displays photo snippet for attachment messages',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      repo.sendChatMessage('', attachmentFile: XFile('/tmp/photo.jpg'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You: 📷 Photo'), findsOneWidget);

      repo.sendChatMessage(
        'Look at this',
        attachmentFile: XFile('/tmp/photo2.jpg'),
      );
      await tester.pumpAndSettle();
      expect(find.text('You: 📷 Look at this'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GroupChatScreen Share in Chat launches Ask the Wheel in Chat Question mode without cooldown',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      // Spin a task first to confirm Chat Question mode operates independently.
      final firstTask = repo.tasks.first;
      final nonCreatorMember = repo.members.firstWhere(
        (m) => m.profile.id != firstTask.createdBy,
      );
      await repo.spinTaskRoulette(firstTask.id, nonCreatorMember.profile.id);
      final initialMsgCount = repo.groupMessages.length;
      final initialPoints = repo.kasamaPoints;

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
              home: const GroupChatScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Ask the Wheel'), findsOneWidget);

      await tester.tap(find.text('Ask the Wheel'));
      await tester.pumpAndSettle();

      expect(find.text('Ask the Wheel'), findsOneWidget);
      expect(find.text('Your Question'), findsOneWidget);
      expect(find.text('SPINNING FOR TASK'), findsNothing);

      // Empty question validation
      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a question before spinning.'),
        findsOneWidget,
      );
      expect(find.text('Send to Chat'), findsNothing);

      // Enter question and spin
      await tester.enterText(
        find.byType(TextField).last,
        "Who's buying dinner tonight?",
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('was chosen!'), findsOneWidget);
      expect(find.text('Send to Chat'), findsOneWidget);

      await tester.tap(find.text('Send to Chat'));
      await tester.pumpAndSettle();

      expect(repo.groupMessages.length, initialMsgCount + 1);
      final sent = repo.groupMessages.last;
      expect(
        sent.content,
        matches(
          RegExp(
            r'^🎡 Just spun the wheel!\n\n"Who' "'" r's buying dinner tonight\?"\n👉 Landed on: (me! 😂|.+! 🎉)$',
          ),
        ),
      );
      expect(sent.clientMessageId, isNotNull);
      expect(sent.clientMessageId, isNotEmpty);
      expect(repo.kasamaPoints, initialPoints);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Done agendas are hidden from ChatDirectoryScreen & Casa Schedule, disable historical card RSVPs, and arrival messages render',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      final todayAt7Pm = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        19,
        0,
      );
      final doneAgenda = HousematesAgendaInvitation(
        id: 'ha_done_1',
        activity: 'Evening Study',
        location: 'Lounge',
        scheduledTime: todayAt7Pm,
        status: 'done',
        reminderSent: true,
        arrivalHandled: true,
        goingCount: 2,
        currentUserResponse: 'maybe',
      );
      repo.setActiveHousematesAgendaForTest(doneAgenda);
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_agenda_hist',
          senderId: repo.currentUser.id,
          senderName: repo.currentUser.displayName,
          content: '',
          createdAt: todayAt7Pm,
          isCurrentUser: true,
          housematesAgendaInvitation: doneAgenda,
        ),
      );
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_arrival_1',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Evening Study is starting now at Lounge!',
          clientMessageId: 'housemates_agenda_arrival_ha_done_1',
          createdAt: todayAt7Pm,
          isCurrentUser: false,
        ),
      );

      // 1. ChatDirectoryScreen hides done agenda under Housemates Agenda
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('done_dir_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No active agendas'), findsOneWidget);
      expect(find.text('Evening Study'), findsNothing);

      // 2. HouseholdCalendarView excludes done agenda from Casa Schedule
      final calRepo = MockRepository()..login();
      calRepo.setActiveHousematesAgendaForTest(doneAgenda);
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('done_cal_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => calRepo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: HouseholdCalendarView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Evening Study'), findsNothing);

      // 3. GroupChatScreen renders Completed inline card with disabled RSVPs + arrival message
      final chatRepo = MockRepository()..login();
      chatRepo.setActiveHousematesAgendaForTest(doneAgenda);
      chatRepo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_agenda_hist',
          senderId: chatRepo.currentUser.id,
          senderName: chatRepo.currentUser.displayName,
          content: '',
          createdAt: todayAt7Pm,
          isCurrentUser: true,
          housematesAgendaInvitation: doneAgenda,
        ),
      );
      chatRepo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_arrival_1',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Evening Study is starting now at Lounge!',
          clientMessageId: 'housemates_agenda_arrival_ha_done_1',
          createdAt: todayAt7Pm,
          isCurrentUser: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('done_group_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => chatRepo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const GroupChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HOUSEMATES AGENDA'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(
        find.text('Evening Study is starting now at Lounge!'),
        findsOneWidget,
      );
      await tester.tap(find.text('Going (2)'));
      await tester.pumpAndSettle();
      expect(chatRepo.activeHousematesAgenda.goingCount, 2);
      expect(chatRepo.activeHousematesAgenda.currentUserResponse, 'maybe');
    },
  );

  testWidgets(
    'ChatDirectoryScreen filters All Upcoming vs My Agendas, shows 2-line cards, and lets creators delete with confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      final otherMember = repo.members.firstWhere(
        (m) => m.profile.id != repo.currentUser.id,
      );
      repo.addHousematesAgendaForTest(
        HousematesAgendaInvitation(
          id: 'ha_other_1',
          creatorId: otherMember.profile.id,
          activity: 'Movie Marathon',
          location: 'Living Room',
          scheduledTime: DateTime.now().add(const Duration(hours: 6)),
          goingCount: 2,
          maybeCount: 2,
          currentUserResponse: 'maybe',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('agenda_filter_delete_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Movie Marathon'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Both active agendas appear under All Active
      expect(find.text('All Active'), findsOneWidget);
      expect(find.text('My Agendas'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Study Session 🎓'), findsOneWidget);
      expect(find.text('Movie Marathon'), findsOneWidget);
      expect(find.text('Living Room • 2 going'), findsOneWidget);

      // Non-creator sheet hides Delete button (open by tapping card)
      expect(find.text('View'), findsNothing);
      expect(find.text('Tap to view'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Movie Marathon'));
      await tester.tap(find.text('Movie Marathon'));
      await tester.pumpAndSettle();
      expect(
        find.text('Coordinate plans & RSVP with your housemates'),
        findsOneWidget,
      );
      expect(find.text('Movie Marathon'), findsWidgets);
      expect(find.byKey(const Key('agenda_delete_button')), findsNothing);
      await tester.tap(find.bySemanticsLabel('Close Housemates Agenda'));
      await tester.pumpAndSettle();

      // Switch to My Agendas: only creator's agenda remains
      await tester.tap(find.text('My Agendas'));
      await tester.pumpAndSettle();
      expect(find.text('Study Session 🎓'), findsOneWidget);
      expect(find.text('Movie Marathon'), findsNothing);

      // Open creator's agenda sheet by tapping card -> Delete button is visible
      await tester.ensureVisible(find.text('Study Session 🎓'));
      await tester.tap(find.text('Study Session 🎓'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agenda_delete_button')), findsOneWidget);

      // Tap Delete -> confirmation dialog appears; Cancel keeps agenda
      await tester.tap(find.byKey(const Key('agenda_delete_button')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Agenda?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        repo.housematesAgendaInvitations.any((m) => m.id == 'm1'),
        isTrue,
      );

      // Confirm Delete -> removes agenda, closes sheet, shows My Agendas empty state
      await tester.tap(find.byKey(const Key('agenda_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agenda_confirm_delete_button')));
      await tester.pumpAndSettle();
      expect(
        repo.housematesAgendaInvitations.any((m) => m.id == 'm1'),
        isFalse,
      );
      expect(
        find.text('Coordinate plans & RSVP with your housemates'),
        findsNothing,
      );
      expect(
        find.text('You have no active agendas'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Individual Conversations show unread badges, sort newest message first with alphabetical empty threads, and clear unread on open',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository.clean()..login();
      final maria = UserProfile(
        id: 'u_maria',
        displayName: 'Maria',
      );
      final alex = UserProfile(
        id: 'u_alex',
        displayName: 'Alex',
      );
      final zoe = UserProfile(
        id: 'u_zoe',
        displayName: 'Zoe',
      );
      final bea = UserProfile(
        id: 'u_bea',
        displayName: 'Bea',
      );
      repo.setMembersForTest([
        MemberPresence(
          profile: repo.currentUser,
          isHome: true,
          updatedAt: DateTime.now(),
        ),
        MemberPresence(profile: zoe, isHome: true, updatedAt: DateTime.now()),
        MemberPresence(profile: maria, isHome: true, updatedAt: DateTime.now()),
        MemberPresence(profile: bea, isHome: false, updatedAt: DateTime.now()),
        MemberPresence(profile: alex, isHome: true, updatedAt: DateTime.now()),
      ]);

      final now = DateTime.now();
      final yesterday350Pm = DateTime(now.year, now.month, now.day - 1, 15, 50);
      final today128Am = DateTime(now.year, now.month, now.day, 1, 28);

      // Alex has an older message (yesterday 3:50 PM), Maria has a newer message (today 1:28 AM) with 2 unread
      repo.addIncomingDirectMessageForTest(
        'alex',
        ChatMessage(
          id: 'dm_alex_1',
          senderId: repo.currentUser.id,
          senderName: repo.currentUser.displayName,
          content: 'Hey Alex',
          createdAt: yesterday350Pm,
          isCurrentUser: true,
        ),
      );
      repo.addIncomingDirectMessageForTest(
        'maria',
        ChatMessage(
          id: 'dm_maria_1',
          senderId: maria.id,
          senderName: maria.displayName,
          content: 'First unread',
          createdAt: today128Am.subtract(const Duration(minutes: 2)),
          isCurrentUser: false,
        ),
      );
      repo.addIncomingDirectMessageForTest(
        'maria',
        ChatMessage(
          id: 'dm_maria_2',
          senderId: maria.id,
          senderName: maria.displayName,
          content: 'Latest from Maria',
          createdAt: today128Am,
          isCurrentUser: false,
        ),
      );

      Widget wrapWithRepo(Widget home) => ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(theme: CasamaTheme.lightTheme, home: home),
          );

      await tester.pumpWidget(wrapWithRepo(const ChatDirectoryScreen()));
      await tester.pumpAndSettle();

      // Unread badge visible for Maria ('2'), hidden for Alex (0)
      expect(find.byKey(const Key('dm_unread_badge_maria')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('dm_unread_badge_maria')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dm_unread_badge_alex')), findsNothing);
      expect(find.textContaining('2 Unread'), findsOneWidget);

      // Verify order: Maria (today 1:28 AM) -> Alex (yesterday 3:50 PM) -> Bea -> Zoe (alphabetical empty)
      final mariaY = tester.getTopLeft(find.text('Maria')).dy;
      final alexY = tester.getTopLeft(find.text('Alex')).dy;
      final beaY = tester.getTopLeft(find.text('Bea')).dy;
      final zoeY = tester.getTopLeft(find.text('Zoe')).dy;
      expect(mariaY, lessThan(alexY));
      expect(alexY, lessThan(beaY));
      expect(beaY, lessThan(zoeY));

      // Incoming message to Zoe re-sorts Zoe above Maria and updates badge live
      repo.addIncomingDirectMessageForTest(
        'zoe',
        ChatMessage(
          id: 'dm_zoe_1',
          senderId: zoe.id,
          senderName: zoe.displayName,
          content: 'Just arrived!',
          createdAt: today128Am.add(const Duration(minutes: 10)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dm_unread_badge_zoe')), findsOneWidget);
      expect(find.textContaining('3 Unread'), findsOneWidget);
      final zoeYAfter = tester.getTopLeft(find.text('Zoe')).dy;
      final mariaYAfter = tester.getTopLeft(find.text('Maria')).dy;
      expect(zoeYAfter, lessThan(mariaYAfter));

      // Opening DirectChatScreen for Maria clears Maria's unread badge & decrements totalUnreadChatCount
      await tester.pumpWidget(
        wrapWithRepo(
          const DirectChatScreen(contactKey: 'maria', contactName: 'Maria'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.getDirectUnreadCount('maria'), 0);
      expect(repo.totalUnreadChatCount, 1);

      // Receiving a new message while viewing Maria's DirectChatScreen keeps it read
      repo.addIncomingDirectMessageForTest(
        'maria',
        ChatMessage(
          id: 'dm_maria_3',
          senderId: maria.id,
          senderName: maria.displayName,
          content: 'While viewing',
          createdAt: today128Am.add(const Duration(minutes: 12)),
          isCurrentUser: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.getDirectUnreadCount('maria'), 0);
      expect(repo.totalUnreadChatCount, 1);

      // Bottom-nav Chat badge reflects remaining unread (1 from Zoe) and clears when Zoe's DM is read
      await tester.pumpWidget(
        wrapWithRepo(const MainNavigationShell(initialIndex: 3)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1 Unread'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      repo.markDirectChatAsRead('zoe');
      await tester.pumpAndSettle();
      expect(repo.totalUnreadChatCount, 0);
      expect(find.textContaining('0 Unread'), findsOneWidget);
    },
  );

  testWidgets(
    'Multi-line wheel spin and agenda messages render cleanly in GroupChatScreen and collapse newlines in ChatDirectoryScreen preview',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      const multilineWheel =
          '🎡 Just spun the wheel!\n\n'
          '"Who is ordering dinner?"\n'
          '👉 Landed on: Maria! 🎉';
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_wheel_multiline',
          senderId: repo.currentUser.id,
          senderName: repo.currentUser.displayName,
          content: multilineWheel,
          createdAt: DateTime.now(),
          isCurrentUser: true,
        ),
      );

      Widget wrap(Widget home) => ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(theme: CasamaTheme.lightTheme, home: home),
          );

      await tester.pumpWidget(wrap(const GroupChatScreen()));
      await tester.pumpAndSettle();

      expect(find.text(multilineWheel), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(const ChatDirectoryScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'You: 🎡 Just spun the wheel! "Who is ordering dinner?" 👉 Landed on: Maria! 🎉',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Housemates Agenda 4-status lifecycle: My Agendas green dot, View button only on upcoming, and creator Done/Missed confirmation moves to History',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      final otherMember = repo.members.firstWhere(
        (m) => m.profile.id != repo.currentUser.id,
      );
      final now = DateTime.now();

      // Seeded 'm1' is upcoming by currentUser; add ongoing (currentUser), ongoing (other), missed (history)
      repo.addHousematesAgendaForTest(
        HousematesAgendaInvitation(
          id: 'ha_ongoing_mine',
          creatorId: repo.currentUser.id,
          activity: 'My Live Sync',
          location: 'Online / Discord',
          scheduledTime: now.subtract(const Duration(minutes: 10)),
          status: 'ongoing',
          goingCount: 2,
          currentUserResponse: 'going',
        ),
      );
      repo.addHousematesAgendaForTest(
        HousematesAgendaInvitation(
          id: 'ha_ongoing_other',
          creatorId: otherMember.profile.id,
          activity: 'Other Live Call',
          location: 'Living Room',
          scheduledTime: now.subtract(const Duration(minutes: 5)),
          status: 'ongoing',
          goingCount: 1,
          currentUserResponse: 'maybe',
        ),
      );
      repo.addHousematesAgendaForTest(
        HousematesAgendaInvitation(
          id: 'ha_missed_past',
          creatorId: otherMember.profile.id,
          activity: 'Yesterday Cleanup',
          location: 'Kitchen',
          scheduledTime: now.subtract(const Duration(days: 1)),
          status: 'missed',
          goingCount: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ChatDirectoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('My Live Sync'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Green dot visible on My Agendas pill because creator has ongoing agenda
      expect(find.byKey(const Key('my_agendas_ongoing_dot')), findsOneWidget);

      // Colored status pills render; View button NEVER renders; Tap to view + chevron cue renders on every card
      expect(find.text('Ongoing'), findsNWidgets(2));
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('View'), findsNothing);
      expect(find.text('Tap to view'), findsNWidgets(3));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));

      // Tapping upcoming card opens Housemates Agenda sheet with enabled RSVPs
      await tester.ensureVisible(find.text('Study Session 🎓'));
      await tester.tap(find.text('Study Session 🎓'));
      await tester.pumpAndSettle();
      expect(find.text('YOUR RESPONSE'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close Housemates Agenda'));
      await tester.pumpAndSettle();

      // Ongoing agendas sort before upcoming under All Active
      final ongoingMineY = tester.getTopLeft(find.text('My Live Sync')).dy;
      final upcomingY = tester.getTopLeft(find.text('Study Session 🎓')).dy;
      expect(ongoingMineY, lessThan(upcomingY));

      // Tapping non-creator ongoing agenda hides Done/Missed confirmation buttons
      await tester.ensureVisible(find.text('Other Live Call'));
      await tester.tap(find.text('Other Live Call'));
      await tester.pumpAndSettle();
      expect(find.text('• Agenda is currently ongoing'), findsOneWidget);
      expect(find.byKey(const Key('agenda_mark_done_button')), findsNothing);
      expect(find.byKey(const Key('agenda_mark_missed_button')), findsNothing);
      await tester.tap(find.bySemanticsLabel('Close Housemates Agenda'));
      await tester.pumpAndSettle();

      // Tapping creator's ongoing agenda reveals Done & Missed buttons; tapping Done moves it to History & removes green dot
      await tester.ensureVisible(find.text('My Live Sync'));
      await tester.tap(find.text('My Live Sync'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agenda_mark_done_button')), findsOneWidget);
      expect(find.byKey(const Key('agenda_mark_missed_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('agenda_mark_done_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_agendas_ongoing_dot')), findsNothing);
      expect(find.text('My Live Sync'), findsNothing);

      // Switch to History: shows Done ('My Live Sync') above older Missed ('Yesterday Cleanup'), no View buttons
      await tester.drag(find.text('My Agendas'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('My Live Sync'), findsOneWidget);
      expect(find.text('Yesterday Cleanup'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('View'), findsNothing);
      expect(find.text('Tap to view'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('My Live Sync')).dy,
        lessThan(tester.getTopLeft(find.text('Yesterday Cleanup')).dy),
      );

      // Tapping a History ('missed') card opens read-only Housemates Agenda sheet
      await tester.ensureVisible(find.text('Yesterday Cleanup'));
      await tester.tap(find.text('Yesterday Cleanup'));
      await tester.pumpAndSettle();
      expect(find.text('FINAL RESPONSES'), findsOneWidget);
    },
  );
}
