import '../../../models/app_user.dart';
import '../../../models/child_info.dart';

/// The editable part of a member's profile, normalized so "did anything
/// change?" and "what do we write?" don't depend on formatting — a phone
/// stored as "+15045551234" and typed as "(504) 555-1234" is the same number,
/// and a child row left blank isn't a child.
class ProfileDraft {
  const ProfileDraft({required this.name, required this.phoneDigits, required this.kids});

  final String name;

  /// Ten digits (US), or empty.
  final String phoneDigits;

  /// Children with a non-blank name.
  final List<ChildInfo> kids;

  factory ProfileDraft.fromUser(AppUser user) {
    return ProfileDraft(name: user.name, phoneDigits: user.phone, kids: user.kids)._normalized();
  }

  factory ProfileDraft.fromForm({required String name, required String phone, required List<ChildInfo> kids}) {
    return ProfileDraft(name: name, phoneDigits: phone, kids: kids)._normalized();
  }

  ProfileDraft _normalized() {
    return ProfileDraft(
      name: name.trim(),
      phoneDigits: _tenDigits(phoneDigits),
      kids: [
        for (final k in kids)
          if (k.name.trim().isNotEmpty) ChildInfo(name: k.name.trim(), grade: k.grade.trim()),
      ],
    );
  }

  static String _tenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 && digits.startsWith('1') ? digits.substring(1) : digits;
  }

  bool _sameKids(ProfileDraft other) {
    if (kids.length != other.kids.length) return false;
    for (var i = 0; i < kids.length; i++) {
      if (kids[i].name != other.kids[i].name || kids[i].grade != other.kids[i].grade) return false;
    }
    return true;
  }

  bool sameAs(ProfileDraft other) =>
      name == other.name && phoneDigits == other.phoneDigits && _sameKids(other);

  /// Only the fields that differ from [original], ready for
  /// `UserRepository.updateProfile`; empty when nothing changed. Unchanged
  /// fields are left out so, for instance, saving a name fix never rewrites
  /// the phone number in a different format.
  Map<String, dynamic> changesFrom(ProfileDraft original) {
    return {
      if (name != original.name) 'name': name,
      if (phoneDigits != original.phoneDigits) 'phone': phoneDigits,
      if (!_sameKids(original)) 'kids': [for (final k in kids) k.toMap()],
    };
  }

  static String? validateName(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Please enter your name' : null;

  /// Optional, but if given it must be a full 10-digit US number.
  static String? validatePhone(String? value) {
    final digits = _tenDigits(value ?? '');
    if (digits.isEmpty || digits.length == 10) return null;
    return 'Enter a 10-digit phone number';
  }
}
