/// Central registry of route paths so screens never hardcode path strings.
class RoutePaths {
  RoutePaths._();

  static const home = '/home';
  static const finance = '/finance';
  static const spendAnalyzer = '/finance/analyzer';
  static const recurringTransactions = '/finance/recurring';
  static const bills = '/finance/bills';
  static const netWorth = '/finance/net-worth';
  static const reports = '/finance/reports';
  static const tasksHabits = '/tasks-habits';
  static String habitDetail(String id) => '/tasks-habits/$id';
  static const calendar = '/calendar';
  static const more = '/more';

  static const notes = '/more/notes';
  static const documents = '/more/documents';
  static const goals = '/more/goals';
  static const aiAnalyser = '/more/ai-analyser';
  static const settings = '/more/settings';
  static const search = '/more/search';
}
