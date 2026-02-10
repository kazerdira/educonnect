import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/network/api_constants.dart';
import 'package:educonnect/features/course/data/models/course_model.dart';

class CourseRemoteDataSource {
  final ApiClient apiClient;

  CourseRemoteDataSource({required this.apiClient});

  /// POST /courses
  Future<CourseModel> createCourse({
    required String title,
    String? description,
    String? subjectId,
    String? levelId,
    required double price,
    bool isPublished = false,
  }) async {
    final response = await apiClient.post(
      ApiConstants.courses,
      data: {
        'title': title,
        if (description != null) 'description': description,
        if (subjectId != null) 'subject_id': subjectId,
        if (levelId != null) 'level_id': levelId,
        'price': price,
        'is_published': isPublished,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from createCourse');
    return CourseModel.fromJson(data);
  }

  /// GET /courses
  Future<List<CourseModel>> listCourses() async {
    final response = await apiClient.get(ApiConstants.courses);
    final list = response.data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /courses/:id
  Future<CourseModel> getCourse(String id) async {
    final response = await apiClient.get(ApiConstants.courseDetail(id));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Course $id not found');
    return CourseModel.fromJson(data);
  }

  /// PUT /courses/:id
  Future<CourseModel> updateCourse(
    String id, {
    String? title,
    String? description,
    String? subjectId,
    String? levelId,
    double? price,
    bool? isPublished,
    String? thumbnailUrl,
  }) async {
    final response = await apiClient.put(
      ApiConstants.courseDetail(id),
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (subjectId != null) 'subject_id': subjectId,
        if (levelId != null) 'level_id': levelId,
        if (price != null) 'price': price,
        if (isPublished != null) 'is_published': isPublished,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from updateCourse');
    return CourseModel.fromJson(data);
  }

  /// DELETE /courses/:id
  Future<void> deleteCourse(String id) async {
    await apiClient.delete(ApiConstants.courseDetail(id));
  }

  /// POST /courses/:id/chapters
  Future<ChapterModel> addChapter(
    String courseId, {
    required String title,
    required int order,
  }) async {
    final response = await apiClient.post(
      ApiConstants.courseChapters(courseId),
      data: {'title': title, 'order': order},
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from addChapter');
    return ChapterModel.fromJson(data);
  }

  /// POST /courses/:id/lessons
  Future<LessonModel> addLesson(
    String courseId, {
    required String title,
    String? description,
    required int order,
    bool isPreview = false,
  }) async {
    final response = await apiClient.post(
      ApiConstants.courseLessons(courseId),
      data: {
        'title': title,
        if (description != null) 'description': description,
        'order': order,
        'is_preview': isPreview,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from addLesson');
    return LessonModel.fromJson(data);
  }

  /// POST /courses/:id/enroll
  Future<EnrollmentModel> enrollCourse(String courseId) async {
    final response = await apiClient.post(ApiConstants.enrollCourse(courseId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('No data returned from enrollCourse');
    return EnrollmentModel.fromJson(data);
  }
}
