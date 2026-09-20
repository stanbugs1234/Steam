import 'package:firebase_auth/firebase_auth.dart';

import '../../../models/app_user.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../directory/data/profile_photo_repository.dart';
import '../../notifications/data/reminder_service.dart';
import '../../volunteering/data/volunteer_repository.dart';
import 'user_repository.dart';

/// The member is the club's only admin; deleting them would leave nobody able
/// to approve members or manage events.
class LastAdminException implements Exception {
  const LastAdminException();
}

/// Firebase only lets a recently signed-in user delete their auth account.
class RecentLoginRequiredException implements Exception {
  const RecentLoginRequiredException();
}

/// Permanently deletes the signed-in member's account: their spot in every
/// volunteer slot, their check-in (points) history, their photo, their member
/// record, and their login.
///
/// Order matters. Everything that needs the member to still be an approved
/// member (leaving volunteer slots, removing their attendance) happens first;
/// the auth account goes last, so a failure earlier leaves them signed in and
/// able to retry. The router sends the app to a signed-out screen as soon as
/// the member record disappears, which can dispose the screen that started
/// this — so the service holds everything it needs itself and never touches UI.
class AccountDeletionService {
  AccountDeletionService({
    required this.auth,
    required this.users,
    required this.photos,
    required this.volunteer,
    required this.attendance,
    required this.reminders,
  });

  final FirebaseAuth auth;
  final UserRepository users;
  final ProfilePhotoRepository photos;
  final VolunteerRepository volunteer;
  final AttendanceRepository attendance;
  final ReminderService reminders;

  /// How recently the member must have signed in. Firebase's own cutoff for
  /// deleting an account is about five minutes; this stays comfortably inside
  /// it so the last step can't fail after their data is already gone.
  static const recentSignInWindow = Duration(minutes: 3);

  bool get signedInRecently {
    final lastSignIn = auth.currentUser?.metadata.lastSignInTime;
    return lastSignIn != null && DateTime.now().difference(lastSignIn) < recentSignInWindow;
  }

  Future<void> deleteMyAccount({required AppUser me, required bool isOnlyAdmin}) async {
    final user = auth.currentUser;
    if (user == null || user.uid != me.uid) throw StateError('Not signed in as this member.');
    if (me.isAdmin && isOnlyAdmin) throw const LastAdminException();
    if (!signedInRecently) throw const RecentLoginRequiredException();

    // Only approved members can read events/slots or hold check-ins, so
    // there's nothing to clean up for anyone else.
    if (me.isApproved) {
      for (final slot in await volunteer.removeUserFromAllSlots(me.uid)) {
        try {
          await reminders.cancelVolunteerReminder(slot.eventId, slot.slotId);
        } catch (_) {
          // Best-effort — the slot itself is already freed.
        }
      }
      await attendance.deleteAllFor(me.uid);
    }

    try {
      await photos.deleteProfilePhoto(me.uid);
    } catch (_) {
      // Best-effort; the photo isn't reachable once the profile is gone.
    }

    await users.deleteAccountDoc(me.uid);

    try {
      await user.delete();
    } catch (_) {
      // The profile is already gone, so don't leave them signed in to
      // nothing; they can sign in again and the account will be re-created
      // as a new signup.
      await auth.signOut();
      rethrow;
    }
  }
}
