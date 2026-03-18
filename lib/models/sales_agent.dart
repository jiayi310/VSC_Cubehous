class SalesAgent {
  int? salesAgentID;
  String? name;
  String? description;
  bool? isDisabled;

  SalesAgent({
    this.salesAgentID,
    this.name,
    this.description,
    this.isDisabled,
  });

  // Convert JSON to SalesAgent object
  factory SalesAgent.fromJson(Map<String, dynamic> json) {
    return SalesAgent(
      salesAgentID: json['salesAgentID'] as int?,
      name: json['salesAgent'] as String?,
      description: json['description'] as String?,
      isDisabled: json['isDisabled'] as bool?,
    );
  }

  // Convert SalesAgent object to JSON
  Map<String, dynamic> toJson() {
    return {
      'salesAgentID': salesAgentID,
      'name': name,
      'description': description,
      'isActive': isDisabled,
    };
  }
}
