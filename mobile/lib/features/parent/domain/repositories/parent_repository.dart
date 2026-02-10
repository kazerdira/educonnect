import 'package:educonnect/features/parent/domain/entities/child.dart';

abstract class ParentRepository {
  Future<ParentDashboard> getDashboard();
  Future<List<Child>> listChildren();
  Future<Child> addChild({
    required String firstName,
    required String lastName,
    required String levelCode,
    String? filiere,
    String? school,
    String? dateOfBirth,
  });
  Future<Child> updateChild(
    String childId, {
    String? firstName,
    String? lastName,
    String? levelCode,
    String? school,
  });
  Future<void> deleteChild(String childId);
  Future<Map<String, dynamic>> getChildProgress(String childId);
}
