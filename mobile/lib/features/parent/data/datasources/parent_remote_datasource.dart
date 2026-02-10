import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/parent/data/models/child_model.dart';

class ParentRemoteDataSource {
  final ApiClient apiClient;

  ParentRemoteDataSource({required this.apiClient});

  /// GET /parents/dashboard
  Future<ParentDashboardModel> getDashboard() async {
    final response = await apiClient.get(ApiConstants.parentDashboard);
    final data = response.data['data'] as Map<String, dynamic>?;
    return ParentDashboardModel.fromJson(data ?? {});
  }

  /// GET /parents/children
  Future<List<ChildModel>> listChildren() async {
    final response = await apiClient.get(ApiConstants.children);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => ChildModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /parents/children
  Future<ChildModel> addChild({
    required String firstName,
    required String lastName,
    required String levelCode,
    String? filiere,
    String? school,
    String? dateOfBirth,
  }) async {
    final response = await apiClient.post(
      ApiConstants.children,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'level_code': levelCode,
        if (filiere != null) 'filiere': filiere,
        if (school != null) 'school': school,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from addChild');
    return ChildModel.fromJson(data);
  }

  /// PUT /parents/children/:id
  Future<ChildModel> updateChild(
    String childId, {
    String? firstName,
    String? lastName,
    String? levelCode,
    String? school,
  }) async {
    final response = await apiClient.put(
      ApiConstants.childDetail(childId),
      data: {
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (levelCode != null) 'level_code': levelCode,
        if (school != null) 'school': school,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from updateChild');
    return ChildModel.fromJson(data);
  }

  /// DELETE /parents/children/:id
  Future<void> deleteChild(String childId) async {
    await apiClient.delete(ApiConstants.childDetail(childId));
  }

  /// GET /parents/children/:id/progress
  Future<Map<String, dynamic>> getChildProgress(String childId) async {
    final response = await apiClient.get(ApiConstants.childProgress(childId));
    return response.data['data'] as Map<String, dynamic>? ?? {};
  }
}
