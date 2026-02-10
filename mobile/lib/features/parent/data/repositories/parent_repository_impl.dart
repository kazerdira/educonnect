import 'package:educonnect/features/parent/data/datasources/parent_remote_datasource.dart';
import 'package:educonnect/features/parent/domain/entities/child.dart';
import 'package:educonnect/features/parent/domain/repositories/parent_repository.dart';

class ParentRepositoryImpl implements ParentRepository {
  final ParentRemoteDataSource remoteDataSource;

  ParentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<ParentDashboard> getDashboard() => remoteDataSource.getDashboard();

  @override
  Future<List<Child>> listChildren() => remoteDataSource.listChildren();

  @override
  Future<Child> addChild({
    required String firstName,
    required String lastName,
    required String levelCode,
    String? filiere,
    String? school,
    String? dateOfBirth,
  }) =>
      remoteDataSource.addChild(
        firstName: firstName,
        lastName: lastName,
        levelCode: levelCode,
        filiere: filiere,
        school: school,
        dateOfBirth: dateOfBirth,
      );

  @override
  Future<Child> updateChild(
    String childId, {
    String? firstName,
    String? lastName,
    String? levelCode,
    String? school,
  }) =>
      remoteDataSource.updateChild(
        childId,
        firstName: firstName,
        lastName: lastName,
        levelCode: levelCode,
        school: school,
      );

  @override
  Future<void> deleteChild(String childId) =>
      remoteDataSource.deleteChild(childId);

  @override
  Future<Map<String, dynamic>> getChildProgress(String childId) =>
      remoteDataSource.getChildProgress(childId);
}
