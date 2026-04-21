import 'package:natproxy/config/supabase_config.dart';
import 'package:natproxy/models/profile.dart';

class ProfileService {
  static Future<Profile?> getMyProfile() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return null;

    final res = await SupabaseConfig.client
        .from('profiles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

    if (res == null) return null;
    return Profile.fromJson(res as Map<String, dynamic>);
  }
}
