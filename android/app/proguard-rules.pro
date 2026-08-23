# Flutter engine - must keep
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# InAppWebView - must keep
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.**

# OkHttp (used by http package internally)
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep our MainActivity
-keep class com.sphereplayer.app.MainActivity { *; }

# Obfuscate everything else aggressively
-optimizationpasses 5
-repackageclasses 'x'
-allowaccessmodification
-mergeinterfacesaggressively

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Remove Dart-visible debug info
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
