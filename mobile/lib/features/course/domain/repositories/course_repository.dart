import 'package:educonnect/features/course/domain/entities/course.dart';

abstract class CourseRepository {
  Future<Course> createCourse({
    required String title,
    String? description,
    String? subjectId,
    String? levelId,
    required double price,
    bool isPublished = false,
  });

  Future<List<Course>> listCourses();
  Future<Course> getCourse(String id);

  Future<Course> updateCourse(
    String id, {
    String? title,
    String? description,
    String? subjectId,
    String? levelId,
    double? price,
    bool? isPublished,
    String? thumbnailUrl,
  });

  Future<void> deleteCourse(String id);

  Future<Chapter> addChapter(
    String courseId, {
    required String title,
    required int order,
  });

  Future<Lesson> addLesson(
    String courseId, {
    required String title,
    String? description,
    required int order,
    bool isPreview = false,
  });

  Future<Enrollment> enrollCourse(String courseId);
}
