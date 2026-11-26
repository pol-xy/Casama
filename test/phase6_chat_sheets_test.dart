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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

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

      // Top-right Add Housemate / Plan a Meet-up header buttons are removed
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
      expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);

      // Open Plan a Meet-up sheet from in-body Meet-up Invitations 'New' pill
      await tester.ensureVisible(find.text('New'));
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('Plan a Meet-up'), findsOneWidget);
      expect(
        find.text('Manual spot label only — zero GPS tracking used.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();
      expect(repo.groupMessages.length, initialGroupMsgs);
      expect(repo.activeMeetUp.activity, 'Study Session 🎓');
      expect(repo.activeMeetUp.scheduledTime.hour, 19);
      expect(repo.activeMeetUp.scheduledTime.minute, 0);
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

      expect(find.text('MEET-UP INVITATION'), findsNothing);

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
    'ChatDirectoryScreen hides phantom Meet-up card when empty and opens RSVP sheet from View',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyRepo = MockRepository()..login();
      await emptyRepo.createMeetUp(
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
        find.text('No meet-up invitations yet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No meet-up invitations yet'), findsOneWidget);
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

      expect(find.text('No meet-up invitations yet'), findsNothing);
      await tester.ensureVisible(find.text('View'));
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(find.text('Meet-up Invitation'), findsOneWidget);
      expect(find.text('None yet'), findsOneWidget);
      expect(find.byType(Tooltip), findsWidgets);

      await tester.tap(find.textContaining('Maybe (').first);
      await tester.pumpAndSettle();
      expect(activeRepo.activeMeetUp.currentUserResponse, 'maybe');
      expect(
        activeRepo.activeMeetUp.maybeResponders
            .any((r) => r.userId == activeRepo.currentUser.id),
        isTrue,
      );
      expect(
        activeRepo.activeMeetUp.goingResponders
            .any((r) => r.userId == activeRepo.currentUser.id),
        isFalse,
      );

      await tester.tap(find.byKey(const Key('meetup_responders_Maybe')));
      await tester.pumpAndSettle();
      expect(find.text(activeRepo.currentUser.displayName), findsOneWidget);
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
    'Plan a Meet-up opens native Date and Time pickers',
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

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('7:00 PM'));
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
    'GroupChatScreen Share in Chat launches Spin Chore Roulette in Chat Question mode without cooldown',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      // Trigger a task roulette spin first so a 24h task cooldown is active.
      await repo.recordRouletteSpin(
        taskTitle: 'Take Out Trash',
        selectedUserId: repo.members.first.profile.id,
      );
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

      await tester.tap(find.byIcon(Icons.attach_file_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Spin Chore Roulette'), findsOneWidget);

      await tester.tap(find.text('Spin Chore Roulette'));
      await tester.pumpAndSettle();

      expect(find.text('Spin Chore Roulette'), findsOneWidget);
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

      // Enter question and spin (bypasses task cooldown)
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
            r'^JP asked the wheel "Who' "'" r's buying dinner tonight\?", and the wheel replied:\n".+"$',
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
    'Done meetups are hidden from ChatDirectoryScreen & Casa Schedule, disable historical card RSVPs, and arrival messages render',
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
      final doneMeetup = MeetUpInvitation(
        id: 'mu_done_1',
        activity: 'Evening Study',
        location: 'Lounge',
        scheduledTime: todayAt7Pm,
        status: 'done',
        reminderSent: true,
        arrivalHandled: true,
        goingCount: 2,
        currentUserResponse: 'maybe',
      );
      repo.setActiveMeetUpForTest(doneMeetup);
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_meetup_hist',
          senderId: repo.currentUser.id,
          senderName: repo.currentUser.displayName,
          content: '',
          createdAt: todayAt7Pm,
          isCurrentUser: true,
          meetUpInvitation: doneMeetup,
        ),
      );
      repo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_arrival_1',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Evening Study is starting now at Lounge!',
          clientMessageId: 'meetup_arrival_mu_done_1',
          createdAt: todayAt7Pm,
          isCurrentUser: false,
        ),
      );

      // 1. ChatDirectoryScreen hides done meetup under Active Meet-up Invitations
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
      expect(find.text('No meet-up invitations yet'), findsOneWidget);
      expect(find.text('Evening Study'), findsNothing);

      // 2. HouseholdCalendarView excludes done meetup from Casa Schedule
      final calRepo = MockRepository()..login();
      calRepo.setActiveMeetUpForTest(doneMeetup);
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
      chatRepo.setActiveMeetUpForTest(doneMeetup);
      chatRepo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_meetup_hist',
          senderId: chatRepo.currentUser.id,
          senderName: chatRepo.currentUser.displayName,
          content: '',
          createdAt: todayAt7Pm,
          isCurrentUser: true,
          meetUpInvitation: doneMeetup,
        ),
      );
      chatRepo.addGroupMessageForTest(
        ChatMessage(
          id: 'msg_arrival_1',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'Evening Study is starting now at Lounge!',
          clientMessageId: 'meetup_arrival_mu_done_1',
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

      expect(find.text('Completed'), findsOneWidget);
      expect(
        find.text('Evening Study is starting now at Lounge!'),
        findsOneWidget,
      );
      await tester.tap(find.text('Going (2)'));
      await tester.pumpAndSettle();
      expect(chatRepo.activeMeetUp.goingCount, 2);
      expect(chatRepo.activeMeetUp.currentUserResponse, 'maybe');
    },
  );
}
