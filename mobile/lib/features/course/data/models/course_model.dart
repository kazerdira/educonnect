import 'package:educonnect/features/course/domain/entities/course.dart';

class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    required super.title,
    super.description,
    super.subjectId,
    super.subjectName,
    super.levelId,
    super.levelName,
    required super.price,
    required super.isPublished,
    super.thumbnailUrl,
    required super.enrollmentCount,
    super.chapters,
    required super.createdAt,
    required super.updatedAt,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      subjectId: json['subject_id'] as String?,
      subjectName: json['subject_name'] as String?,
      levelId: json['level_id'] as String?,
      levelName: json['level_name'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isPublished: json['is_published'] as bool? ?? false,
      thumbnailUrl: json['thumbnail_url'] as String?,
      enrollmentCount: (json['enrollment_count'] as num?)?.toInt() ?? 0,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((e) => ChapterModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class ChapterModel extends Chapter {
  const ChapterModel({
    required super.id,
    required super.courseId,
    required super.title,
    required super.order,
    super.lessons,
    required super.createdAt,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class LessonModel extends Lesson {
  const LessonModel({
    required super.id,
    required super.chapterId,
    required super.title,
    super.description,
    super.videoUrl,
    required super.duration,
    required super.order,
    required super.isPreview,
    required super.createdAt,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as String? ?? '',
      chapterId: json['chapter_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      order: (json['order'] as num?)?.toInt() ?? 0,
      isPreview: json['is_preview'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class EnrollmentModel extends Enrollment {
  const EnrollmentModel({
    required super.id,
    required super.courseId,
    required super.courseTitle,
    required super.studentId,
    required super.progressPercent,
    super.lastLessonId,
    required super.enrolledAt,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      id: json['id'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseTitle: json['course_title'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0,
      lastLessonId: json['last_lesson_id'] as String?,
      enrolledAt: json['enrolled_at'] as String? ?? '',
    );
  }
}
