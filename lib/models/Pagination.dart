class Pagination {
  int? totalRecord;
  int? pageIndex;
  int? pageSize;
  String? sortBy;
  bool? isSortByAscending;
  String? searchTerm;

  Pagination({
    this.totalRecord,
    this.pageIndex,
    this.pageSize,
    this.sortBy,
    this.isSortByAscending,
    this.searchTerm,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      totalRecord: json['totalRecord'] as int?,
      pageIndex: json['pageIndex'] as int?,
      pageSize: json['pageSize'] as int?,
      sortBy: json['sortBy'] as String?,
      isSortByAscending: json['isSortByAscending'] as bool?,
      searchTerm: json['searchTerm'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRecord': totalRecord,
      'pageIndex': pageIndex,
      'pageSize': pageSize,
      'sortBy': sortBy,
      'isSortByAscending': isSortByAscending,
      'searchTerm': searchTerm,
    };
  }
}
