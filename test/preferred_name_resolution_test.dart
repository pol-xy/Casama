import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/chat/direct_chat_screen.dart';
import 'package:casama/features/dashboard/dashboard_screen.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PreferredNameTestMockRepository extends MockRepository {
  late final UserProfile _trixterProfile;
  late final UserProfile _jonPaulProfile;
  late final List<MemberPresence> _customMembers;
  late final List<MaintenanceTask> _customTasks;
  late final List<ChoreRouletteRecord> _customRoulette;
  late final List<ParcelItem> _customParcels;
  late final List<QuickSnap> _customSnaps;
  late final List<ChatMessage> _customGroupMessages;
  late final List<ChatSpace> _customSpaces;

  _PreferredNameTestMockRepository() {
    _trixterProfile = const UserProfile(
      id: 'u-trixter',
      displayName: 'lanzdonatos212006',
      handle: '@trixter',
      fullName: 'Trixter Lanz C. Donatos',
      nickname: 'Trixter',
      hasConsentedTerms: true,
      hasCompletedOnboarding: true,
    );
    _jonPaulProfile = const UserProfile(
      id: 'u-jonpaul',
      displayName: 'beranajonpaul14',
      handle: '@jpberana',
      fullName: 'Jon Paul Berana',
      nickname: '   ',
      hasConsentedTerms: true,
      hasCompletedOnboarding: true,
    );

    final now = DateTime(2026, 11, 27, 9, 0);
    _customMembers = [
      MemberPresence(
        profile: _trixterProfile,
        isHome: true,
        note: 'At desk',
        updatedAt: now,
      ),
      MemberPresence(
        profile: _jonPaulProfile,
        isHome: true,
        note: 'In kitchen',
        updatedAt: now,
      ),
    ];

    _customTasks = [
      MaintenanceTask(
        id: 't-pref-1',
        householdId: 'hh-pref',
        title: 'Wipe kitchen counter',
        category: TaskCategory.cleaning,
        urgency: TaskUrgency.medium,
        status: TaskStatus.open,
        createdBy: _jonPaulProfile.id,
        createdByName: 'beranajonpaul14',
        createdAt: now,
      ),
    ];

    _customRoulette = [
      ChoreRouletteRecord(
        id: 'r-pref-1',
        taskId: 't-pref-1',
        householdId: 'hh-pref',
        choreTitle: 'Wipe kitchen counter',
        selectedUserId: _trixterProfile.id,
        selectedUserName: 'lanzdonatos212006',
        spunByUserId: _jonPaulProfile.id,
        spunByName: 'beranajonpaul14',
        bonusPoints: 4,
        createdAt: now,
      ),
    ];

    _customParcels = [
      ParcelItem(
        id: 'p-pref-1',
        householdId: 'hh-pref',
        buyerId: _trixterProfile.id,
        buyerName: 'lanzdonatos212006',
        courier: 'J&T Express',
        expectedArrival: now,
        paymentType: ParcelPaymentType.cod,
        codAmount: 250,
        status: ParcelStatus.expected,
      ),
    ];

    _customSnaps = [
      QuickSnap(
        id: 's-pref-1',
        householdId: 'hh-pref',
        senderId: _jonPaulProfile.id,
        senderName: 'beranajonpaul14',
        imageUrl: '',
        caption: 'Morning coffee',
        createdAt: now,
      ),
    ];

    _customGroupMessages = [
      ChatMessage(
        id: 'gm-pref-1',
        senderId: _jonPaulProfile.id,
        senderName: 'beranajonpaul14',
        content: 'On my way home',
        createdAt: now,
        isCurrentUser: false,
      ),
    ];

    _customSpaces = [
      ChatSpace(
        id: 'sp-pref-1',
        householdId: 'hh-pref',
        name: 'Bills & WiFi',
        description: 'Monthly bills',
        inviteCode: '',
        creatorId: _trixterProfile.id,
        creatorName: 'lanzdonatos212006',
        memberNames: const ['Trixter', 'Jon Paul Berana'],
        createdAt: now,
        messages: [
          ChatMessage(
            id: 'sm-pref-1',
            senderId: _jonPaulProfile.id,
            senderName: 'beranajonpaul14',
            content: 'Paid internet',
            createdAt: now,
            isCurrentUser: false,
          ),
        ],
      ),
    ];
  }

  @override
  UserProfile get currentUser => _trixterProfile;

  @override
  List<MemberPresence> get members => _customMembers;

  @override
  List<MaintenanceTask> get tasks => _customTasks;

  @override
  List<ChoreRouletteRecord> get rouletteRecords => _customRoulette;

  @override
  ChoreRouletteRecord? rouletteRecordForTask(String taskId) {
    for (final r in _customRoulette) {
      if (r.taskId == taskId) return r;
    }
    return null;
  }

  @override
  List<ParcelItem> get parcels => _customParcels;

  @override
  List<QuickSnap> get quickSnaps => _customSnaps;

  @override
  List<ChatMessage> get groupMessages => _customGroupMessages;

  @override
  List<ChatSpace> get chatSpaces => _customSpaces;

  @override
  bool isHousemateAuthorized(String contactKey) {
    final key = contactKey.toLowerCase().replaceAll('@', '').trim();
    return _customMembers.any((m) {
      final p = m.profile;
      return p.preferredName.toLowerCase().trim() == key ||
          (p.nickname?.toLowerCase().trim() == key) ||
          (p.fullName?.toLowerCase().trim() == key) ||
          p.displayName.toLowerCase().trim() == key ||
          p.handle.toLowerCase().replaceAll('@', '').trim() == key ||
          p.id.toLowerCase().trim() == key;
    });
  }
}

void main() {
  group('Canonical Housemate preferredName Resolution', () {
    test('UserProfile.preferredName prioritizes nickname -> fullName -> displayName', () {
      const withNickname = UserProfile(
        id: 'u1',
        displayName: 'lanzdonatos212006',
        handle: '@trixter',
        fullName: 'Trixter Lanz C. Donatos',
        nickname: 'Trixter',
      );
      expect(withNickname.preferredName, 'Trixter');

      const blankNickname = UserProfile(
        id: 'u2',
        displayName: 'beranajonpaul14',
        handle: '@jp',
        fullName: 'Jon Paul Berana',
        nickname: '   ',
      );
      expect(blankNickname.preferredName, 'Jon Paul Berana');

      const onlyDisplay = UserProfile(
        id: 'u3',
        displayName: 'grizzlylanz10',
        handle: '@grizzly',
        fullName: '  ',
        nickname: null,
      );
      expect(onlyDisplay.preferredName, 'grizzlylanz10');

      const allBlank = UserProfile(
        id: 'u4',
        displayName: '  ',
        handle: '@u4',
      );
      expect(allBlank.preferredName, 'Housemate');
    });

    test('CasamaRepository.resolveHousemateName overrides stale record names with live preferredName', () {
      final repo = _PreferredNameTestMockRepository();

      expect(
        repo.resolveHousemateName('u-trixter', fallback: 'lanzdonatos212006'),
        'Trixter',
      );
      expect(
        repo.resolveHousemateName(
          'u-trixter',
          fallback: 'lanzdonatos212006',
          useYouForCurrentUser: true,
        ),
        'You',
      );
      expect(
        repo.resolveHousemateName('u-jonpaul', fallback: 'beranajonpaul14'),
        'Jon Paul Berana',
      );
      expect(
        repo.resolveHousemateName('unknown-id', fallback: 'Guest'),
        'Guest',
      );
    });

    testWidgets(
      'DashboardScreen renders preferredName across hero greeting, presence, attention, and CASnaps',
      (tester) async {
        final repo = _PreferredNameTestMockRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hello, Trixter!'), findsOneWidget);
        expect(find.text('Jon Paul Berana'), findsWidgets);
        expect(find.textContaining('J&T Express COD for Trixter'), findsOneWidget);
        expect(find.text('lanzdonatos212006'), findsNothing);
        expect(find.text('beranajonpaul14'), findsNothing);
      },
    );

    testWidgets(
      'MaintenanceBoardView renders preferredName on task creator and roulette pills',
      (tester) async {
        final repo = _PreferredNameTestMockRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const Scaffold(body: TasksBoardView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('By Jon Paul Berana'), findsOneWidget);
        expect(find.text('Spun by Jon Paul Berana'), findsOneWidget);
        expect(find.text('Chosen: You'), findsOneWidget);
        expect(find.textContaining('beranajonpaul14'), findsNothing);
        expect(find.textContaining('lanzdonatos212006'), findsNothing);
      },
    );

    testWidgets(
      'ChatDirectoryScreen and DirectChatScreen render preferredName instead of fullName or email displayName',
      (tester) async {
        final repo = _PreferredNameTestMockRepository();
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

        expect(
          find.text('Jon Paul Berana: On my way home'),
          findsOneWidget,
        );
        expect(
          find.text('Jon Paul Berana: Paid internet'),
          findsOneWidget,
        );
        expect(find.text('Jon Paul Berana'), findsWidgets);
        expect(find.textContaining('beranajonpaul14'), findsNothing);
        expect(find.textContaining('lanzdonatos212006'), findsNothing);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const DirectChatScreen(
                contactKey: 'lanzdonatos212006',
                contactName: 'Trixter Lanz C. Donatos',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trixter'), findsOneWidget);
        expect(find.text('Trixter Lanz C. Donatos'), findsNothing);
        expect(find.text('lanzdonatos212006'), findsNothing);
      },
    );
  });
}
