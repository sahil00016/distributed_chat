class User {
  final String username;
  final bool isOnline;

  User({
    required this.username,
    this.isOnline = true,
  });

  factory User.fromString(String username) {
    return User(username: username);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.username == username;
  }

  @override
  int get hashCode => username.hashCode;
}

