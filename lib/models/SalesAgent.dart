class SalesAgent {
  int? salesAgentID;
  String? name;
  String? description;
  bool? isActive;

  SalesAgent({
    this.salesAgentID,
    this.name,
    this.description,
    this.isActive,
  });

  // Convert JSON to SalesAgent object
  factory SalesAgent.fromJson(Map<String, dynamic> json) {
    return SalesAgent(
      salesAgentID: json['salesAgentID'] as int?,
      name: json['salesAgent'] as String?,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool?,
    );
  }

  // Convert SalesAgent object to JSON
  Map<String, dynamic> toJson() {
    return {
      'salesAgentID': salesAgentID,
      'name': name,
      'description': description,
      'isActive': isActive,
    };
  }
}
