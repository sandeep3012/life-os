/// Central registry of route paths so screens never hardcode path strings.
class RoutePaths {
  RoutePaths._();

  static const home = '/home';
  static const finance = '/finance';
  static const financeLedger = '/finance/ledger';
  static const spendAnalyzer = '/finance/analyzer';
  static const recurringTransactions = '/finance/recurring';
  static const bills = '/finance/bills';
  static const netWorth = '/finance/net-worth';
  static const reports = '/finance/reports';
  static const tasksHabits = '/tasks-habits';
  static const archivedHabits = '/tasks-habits/archived-habits';
  static String habitDetail(String id) => '/tasks-habits/$id';
  static const calendar = '/calendar';
  static const more = '/more';

  static const habitsOverview = '/more/habits';
  static const health = '/more/health';
  static const learn = '/more/learn';
  static String learnNote(String id) => '/more/learn/$id';
  static const notes = '/more/notes';
  static const documents = '/more/documents';
  static const goals = '/more/goals';
  static const aiAnalyser = '/more/ai-analyser';
  static const settings = '/more/settings';
  static const search = '/more/search';

  // Sync account. Outside the shell: these are full-screen and carry no bottom
  // nav, and nothing routes here on launch — free use needs no account.
  static const syncSignIn = '/sync/sign-in';
  static const syncSignUp = '/sync/sign-up';
}
