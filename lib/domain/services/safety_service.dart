class SafetyResult {
  final bool emergency;
  final String? matchedTerm;
  const SafetyResult({required this.emergency, this.matchedTerm});
}

class MedicalSafetyService {
  static final List<RegExp> _patterns = [
    RegExp(r'نزيف شديد|نزيف لا يتوقف|فقدان دم', caseSensitive: false),
    RegExp(r'ألم صدر شديد|ألم في الصدر مع ضيق|اشتباه جلطة|جلطة قلبية', caseSensitive: false),
    RegExp(r'اختناق|صعوبة شديدة في التنفس|انقطاع التنفس', caseSensitive: false),
    RegExp(r'تسمم|جرعة زائدة|ابتلاع مادة سامة', caseSensitive: false),
    RegExp(r'فقدان الوعي|إغماء مستمر|تشنج مستمر', caseSensitive: false),
    RegExp(r'نزيف دماغي|سكتة دماغية|شلل مفاجئ|ضعف مفاجئ في جهة', caseSensitive: false),
  ];

  SafetyResult check(String input) {
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) return SafetyResult(emergency: true, matchedTerm: match.group(0));
    }
    return const SafetyResult(emergency: false);
  }

  String emergencyMessage() => 'قد تكون الأعراض المذكورة حالة طارئة. يجب طلب المساعدة الطبية الطارئة أو التوجه إلى أقرب قسم طوارئ فوراً، ولا ينبغي الاعتماد على التطبيق لتشخيص الحالة أو تأخير الرعاية.';
}
