import 'package:educonnect/features/course/data/datasources/course_remote_datasource.dart';
import 'package:educonnect/features/course/domain/entities/course.dart';
import 'package:educonnect/features/course/domain/repositories/course_repository.dart';

class CourseRepositoryImpl implements CourseRepository {
  final CourseRemoteDataSource remoteDataSource;

  CourseRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Course> createCourse({
    required String title,
    String? description,
    String? subjectId,
    String? levelId,
    required double price,
    bool isPublished = false,
  }) =>
      remoteDataSource.createCourse(
        title: title,
        description: description,
        subjectId: subjectId,
        levelId: levelId,
        price: price,
        isPublished: isPublished,
      );

  @override
  Future<List<Course>> listCourses() => remoteDataSource.listCourses();

  @override
  Future<Course> getCourse(String id) => remoteDataSource.getCourse(id);

  @override
  Future<Course> updateCourse(
    String id, {
    String? title,
    String? description,
    String? subjectId,
    String? levelId,
    double? price,
    bool? isPublished,
    String? thumbnailUrl,
  }) =>
      remoteDataSource.updateCourse(
        id,
        title: title,
        description: description,
        subjectId: subjectId,
        levelId: levelId,
        price: price,
        isPublished: isPublished,
        thumbnailUrl: thumbnailUrl,
      );

  @override
  Future<void> deleteCourse(String id) => remoteDataSource.deleteCourse(id);

  @override
  Future<Chapter> addChapter(
    String courseId, {
    required String title,
    required int order,
  }) =>
      remoteDataSource.addChapter(courseId, title: title, order: order);

  @override
  Future<Lesson> addLesson(
    String courseId, {
    required String title,
    String? description,
    required int order,
    bool isPreview = false,
  }) =>
      remoteDataSource.addLesson(
        courseId,
        title: title,
        description: description,
        order: order,
        isPreview: isPreview,
      );

  @override
  Future<Enrollment> enrollCourse(String courseId) =>
      remoteDataSource.enrollCourse(courseId);
}
