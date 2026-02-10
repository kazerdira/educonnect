import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String title;
  final String? description;
  final String? subjectId;
  final String? subjectName;
  final String? levelId;
  final String? levelName;
  final double price;
  final bool isPublished;
  final String? thumbnailUrl;
  final int enrollmentCount;
  final List<Chapter> chapters;
  final String createdAt;
  final String updatedAt;

  const Course({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    this.description,
    this.subjectId,
    this.subjectName,
    this.levelId,
    this.levelName,
    required this.price,
    required this.isPublished,
    this.thumbnailUrl,
    required this.enrollmentCount,
    this.chapters = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id];
}

class Chapter extends Equatable {
  final String id;
  final String courseId;
  final String title;
  final int order;
  final List<Lesson> lessons;
  final String createdAt;

  const Chapter({
    required this.id,
    required this.courseId,
    required this.title,
    required this.order,
    this.lessons = const [],
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}

class Lesson extends Equatable {
  final String id;
  final String chapterId;
  final String title;
  final String? description;
  final String? videoUrl;
  final int duration;
  final int order;
  final bool isPreview;
  final String createdAt;

  const Lesson({
    required this.id,
    required this.chapterId,
    required this.title,
    this.description,
    this.videoUrl,
    required this.duration,
    required this.order,
    required this.isPreview,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}

class Enrollment extends Equatable {
  final String id;
  final String courseId;
  final String courseTitle;
  final String studentId;
  final double progressPercent;
  final String? lastLessonId;
  final String enrolledAt;

  const Enrollment({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.studentId,
    required this.progressPercent,
    this.lastLessonId,
    required this.enrolledAt,
  });

  @override
  List<Object?> get props => [id];
}
