import 'package:go_router/go_router.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/finance/presentation/screens/finance_home_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/sync/presentation/sync_screen.dart';
import '../../features/finance/presentation/screens/finance_overview_screen.dart';
import '../../features/finance/presentation/screens/recurring_transactions_screen.dart';
import '../../features/finance/presentation/screens/bills_screen.dart';
import '../../features/finance/presentation/screens/net_worth_screen.dart';
import '../../features/finance/presentation/screens/reports_screen.dart';
import '../../features/spend_analyzer/presentation/screens/spend_analyzer_screen.dart';
import '../../features/habits/presentation/screens/habit_detail_screen.dart';
import '../../features/habits/presentation/screens/habits_overview_screen.dart';
import '../../features/health/presentation/screens/health_screen.dart';
import '../../features/habits/presentation/screens/archived_habits_screen.dart';
import '../../features/tasks/presentation/screens/tasks_habits_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/learn/presentation/screens/learn_screen.dart';
import '../../features/learn/presentation/screens/note_reader_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/documents/presentation/screens/folder_documents_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/ai_analyser/presentation/screens/ai_analyser_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'app_shell.dart';
import 'menu_origin.dart';
import 'route_paths.dart';
import 'navigator_keys.dart';
import '../../features/finance/presentation/screens/accounts_screen.dart';

/// Root go_router config: a StatefulShellRoute with 5 bottom-nav branches,
/// each branch preserving its own navigation stack.
GoRouter createAppRouter() => GoRouter(
  initialLocation: RoutePaths.home,
  redirect: (context, state) =>
      offRouteRedirect(state.uri, tabRoot: MenuOrigin.tabRoot),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          navigatorKey: branchNavigatorKeys[0],
          routes: [
            GoRoute(
              path: RoutePaths.home,
              builder: (context, state) => const HomeScreen(),
              routes: _menuRoutes(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: branchNavigatorKeys[1],
          routes: [
            GoRoute(
              path: RoutePaths.finance,
              builder: (context, state) => const FinanceHomeScreen(),
              routes: [
                ..._menuRoutes(),
                GoRoute(
                  path: 'overview',
                  builder: (context, state) => const FinanceOverviewScreen(),
                ),
                GoRoute(
                  path: 'analyzer',
                  builder: (context, state) => const SpendAnalyzerScreen(),
                ),
                GoRoute(
                  path: 'recurring',
                  builder: (context, state) =>
                      const RecurringTransactionsScreen(),
                ),
                GoRoute(
                  path: 'bills',
                  builder: (context, state) => const BillsScreen(),
                ),
                GoRoute(
                  path: 'net-worth',
                  builder: (context, state) => const NetWorthScreen(),
                ),
                GoRoute(
                  path: 'accounts',
                  builder: (context, state) => const AccountsScreen(),
                ),
                GoRoute(
                  path: 'reports',
                  builder: (context, state) => const ReportsScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: branchNavigatorKeys[2],
          routes: [
            GoRoute(
              path: RoutePaths.tasksHabits,
              builder: (context, state) => TasksHabitsScreen(
                initialHabitsTab: state.uri.queryParameters['tab'] == 'habits',
              ),
              routes: [
                // Before ':habitId', which would otherwise claim "more".
                ..._menuRoutes(),
                GoRoute(
                  path: 'archived-habits',
                  builder: (context, state) => const ArchivedHabitsScreen(),
                ),
                GoRoute(
                  path: 'task/:taskId',
                  builder: (context, state) =>
                      TaskDetailScreen(taskId: state.pathParameters['taskId']!),
                ),
                GoRoute(
                  path: ':habitId',
                  builder: (context, state) => HabitDetailScreen(
                    habitId: state.pathParameters['habitId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: branchNavigatorKeys[3],
          routes: [
            GoRoute(
              path: RoutePaths.calendar,
              builder: (context, state) => const CalendarScreen(),
              routes: _menuRoutes(),
            ),
          ],
        ),
      ],
    ),

    // Sync account, deliberately outside the shell: the design draws these
    // full-screen with no bottom nav, and free use never reaches them.
    GoRoute(
      path: RoutePaths.sync,
      builder: (context, state) => const SyncScreen(),
    ),
    GoRoute(
      path: RoutePaths.syncSignIn,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: RoutePaths.syncSignUp,
      builder: (context, state) => const SignUpScreen(),
    ),
  ],
);

/// Addresses that aren't screens. The sign-in return link
/// (personalos://auth-callback?code=…) belongs to Supabase, which reads it
/// itself; if it ever reaches the router, it goes to Sync & account, where
/// the sign-in shows. A bare "/" goes Home.
String? offRouteRedirect(Uri uri, {String tabRoot = RoutePaths.home}) {
  // 'lifeos' was the scheme before the app was renamed; a sign-in email
  // sent then can still be opened.
  if (uri.scheme == 'personalos' ||
      uri.scheme == 'lifeos' ||
      uri.host == 'auth-callback' ||
      uri.path.startsWith('/auth-callback')) {
    return RoutePaths.sync;
  }
  // '/more' was the old More page; it has no screen of its own any more.
  if (uri.path.isEmpty || uri.path == '/' || uri.path == RoutePaths.more) {
    return RoutePaths.home;
  }
  // A side-menu screen opens on top of the tab that's showing.
  if (uri.path.startsWith('${RoutePaths.more}/')) {
    return uri.replace(path: '$tabRoot${uri.path}').toString();
  }
  return null;
}

/// Shared router used by isolated widget tests. The live app creates a fresh
/// router for each in-app restart.
final appRouter = createAppRouter();

/// The side menu's screens (Notes, Goals, Documents, Settings…), mounted
/// under each bottom-nav tab: `/home/more/notes`, `/finance/more/notes`, and
/// so on. Opened this way a screen sits on top of the tab it was opened
/// from, so back slides it away and returns there — the same as any other
/// screen in the app. They used to live in a tab of their own with nothing
/// beneath them, so back had nowhere to go but an abrupt jump Home.
///
/// Callers keep using `RoutePaths.notes` (`/more/notes`); [offRouteRedirect]
/// moves it under whichever tab is showing.
List<RouteBase> _menuRoutes() => [
  GoRoute(
    path: _under(RoutePaths.habitsOverview),
    builder: (context, state) => const HabitsOverviewScreen(),
  ),
  GoRoute(
    path: _under(RoutePaths.health),
    builder: (context, state) => const HealthScreen(),
  ),
  GoRoute(
    path: _under(RoutePaths.learn),
    builder: (context, state) => const LearnScreen(),
    routes: [
      GoRoute(
        path: ':noteId',
        builder: (context, state) =>
            NoteReaderScreen(noteId: state.pathParameters['noteId']!),
      ),
    ],
  ),
  GoRoute(
    path: _under(RoutePaths.notes),
    builder: (context, state) => const NotesScreen(),
  ),
  GoRoute(
    path: _under(RoutePaths.documents),
    builder: (context, state) => const DocumentsScreen(),
    routes: [
      GoRoute(
        path: 'folder/:folderId',
        builder: (context, state) => FolderDocumentsScreen(
          folderId: state.pathParameters['folderId']!,
          folderName: state.uri.queryParameters['name'] ?? 'Folder',
        ),
      ),
    ],
  ),
  GoRoute(
    path: _under(RoutePaths.goals),
    builder: (context, state) => const GoalsScreen(),
  ),
  GoRoute(
    path: _under(RoutePaths.aiAnalyser),
    builder: (context, state) => const AiAnalyserScreen(),
  ),
  GoRoute(
    path: _under(RoutePaths.settings),
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: _under(RoutePaths.search),
    builder: (context, state) => const SearchScreen(),
  ),
];

/// `/more/notes` as a child path: `more/notes`.
String _under(String path) => path.substring(1);
