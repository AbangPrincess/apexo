import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repository.dart';
import 'fb_alerts.dart';
import 'fb_auth.dart';
import 'fb_circles.dart';
import 'fb_profile.dart';
import 'fb_social.dart';

/// The real backend: Firebase Auth and Cloud Firestore on the free Spark
/// plan, laid out exactly like FakeRepository (SPEC G4).
class FirebaseRepository extends AppRepository
    with FbAuth, FbProfile, FbCircles, FbAlerts, FbMemberProfiles, FbWalkie {
  FirebaseRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : auth = auth ?? FirebaseAuth.instance,
      db = db ?? FirebaseFirestore.instance {
    startAuth();
  }

  @override
  final FirebaseAuth auth;

  @override
  final FirebaseFirestore db;

  @override
  void dispose() => disposeAuth();
}
