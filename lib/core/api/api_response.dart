enum ApiErrorKind {
  network,

  timeout,

  server,

  parse,

  apiError,

  unauthorized,

  forbidden,

  captchaNeeded,

  unknown,
}

class ApiError {
  final ApiErrorKind kind;
  final String message;
  final int? code;
  final String? technicalDetails;
  final String? captchaSid;
  final String? captchaImg;

  const ApiError({
    required this.kind,
    required this.message,
    this.code,
    this.technicalDetails,
    this.captchaSid,
    this.captchaImg,
  });

  @override
  String toString() =>
      'ApiError(kind: $kind, message: "$message", code: $code)';
}

sealed class ApiResponse<T> {
  const ApiResponse();

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;
  bool get isFromCache => this is ApiSuccess<T> && (this as ApiSuccess<T>).isFromCache;

  T? get dataOrNull => switch (this) {
    ApiSuccess<T>(:final data) => data,
    ApiFailure<T>() => null,
  };

  ApiError? get errorOrNull => switch (this) {
    ApiSuccess<T>() => null,
    ApiFailure<T>(:final error) => error,
  };

  T getOrElse(T fallback) => switch (this) {
    ApiSuccess<T>(:final data) => data,
    ApiFailure<T>(:final fallbackData) => fallbackData ?? fallback,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiError error, T? fallback) failure,
  }) => switch (this) {
    ApiSuccess<T>(:final data) => success(data),
    ApiFailure<T>(:final error, :final fallbackData) => failure(
      error,
      fallbackData,
    ),
  };
}

class ApiSuccess<T> extends ApiResponse<T> {
  final T data;
  final Map<String, dynamic>? rawJson;
  @override
  final bool isFromCache;

  const ApiSuccess(this.data, {this.rawJson, this.isFromCache = false});

  @override
  String toString() => 'ApiSuccess(data: $data, isFromCache: $isFromCache)';
}

class ApiFailure<T> extends ApiResponse<T> {
  final ApiError error;

  final T? fallbackData;

  const ApiFailure(this.error, {this.fallbackData});

  @override
  String toString() =>
      'ApiFailure(error: $error, hasFallback: ${fallbackData != null})';
}
