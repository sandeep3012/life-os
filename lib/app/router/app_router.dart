import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/more_screen.dart';
import '../../features/finance/presentation/screens/finance_home_screen.dart';
import '../../features/finance/presentation/screens/recurring_transactions_screen.dart';
import '../../features/finance/presentation/screens/bills_screen.dart';
import '../../features/finance/presentation/screens/net_worth_screen.dart';
import '../../features/finance/presentation/screens/reports_screen.dart';
import '../../features/spend_analyzer/presentation/screens/spend_analyzer_screen.dart';
import '../../features/habits/presentation/screens/habit_detail_screen.dart';
import '../../features/habits/presentation/screens/archived_habits_screen.dart';
import '../../features/tasks/presentation/screens/tasks_habits_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/ai_analyser/presentation/screens/ai_analyser_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/voice_commands/presentation/screens/voice_commands_screen.dart';
import 'app_shell.dart';
import 'route_paths.dart';

/// Root go_router config: a StatefulShellRoute with 5 bottom-nav branches,
/// each branch preserving its own navigation stack.
final appRouter = GoRouter(
  initialLocation: RoutePaths.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: RoutePaths.home, builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.finance,
            builder: (context, state) => const FinanceHomeScreen(),
            routes: [
              GoRoute(path: 'analyzer', builder: (context, state) => const SpendAnalyzerScreen()),
              GoRoute(
                path: 'recurring',
                builder: (context, state) => const RecurringTransactionsScreen(),
              ),
              GoRoute(path: 'bills', builder: (context, state) => const BillsScreen()),
              GoRoute(path: 'net-worth', builder: (context, state) => const NetWorthScreen()),
              GoRoute(path: 'reports', builder: (context, state) => const ReportsScreen()),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.tasksHabits,
            builder: (context, state) => const TasksHabitsScreen(),
            routes: [
              GoRoute(
                path: 'archived-habits',
                builder: (context, state) => const ArchivedHabitsScreen(),
              ),
              GoRoute(
                path: ':habitId',
                builder: (context, state) =>
                    HabitDetailScreen(habitId: state.pathParameters['habitId']!),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: RoutePaths.calendar, builder: (context, state) => const CalendarScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: RoutePaths.more,
            builder: (context, state) => const MoreScreen(),
            routes: [
              GoRoute(path: 'notes', builder: (context, state) => const NotesScreen()),
              GoRoute(path: 'documents', builder: (context, state) => const DocumentsScreen()),
              GoRoute(path: 'goals', builder: (context, state) => const GoalsScreen()),
              GoRoute(path: 'ai-analyser', builder: (context, state) => const AiAnalyserScreen()),
              GoRoute(path: 'settings', builder: (context, state) => const SettingsScreen()),
              GoRoute(path: 'search', builder: (context, state) => const SearchScreen()),
              GoRoute(path: 'voice-commands', builder: (context, state) => const VoiceCommandsScreen()),
            ],
          ),
        ]),
      ],
    ),
  ],
);
