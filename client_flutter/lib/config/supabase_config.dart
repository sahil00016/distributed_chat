/// Supabase Configuration
class SupabaseConfig {
  // TODO: Replace with your Supabase project credentials
  // Get these from: https://app.supabase.com/project/_/settings/api
  
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Table name for users
  static const String usersTable = 'chat_users';
  
  // Table name for private messages
  static const String messagesTable = 'private_messages';
}

