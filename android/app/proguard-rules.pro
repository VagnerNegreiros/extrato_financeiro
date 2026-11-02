# Flutter and its plugins ship their own consumer rules; nothing extra is
# needed today. Add keep rules here when a plugin requires them.

# Strip verbose and debug logs from release builds.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}
