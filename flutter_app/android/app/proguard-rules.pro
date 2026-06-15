# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# App Links
-keep class com.llfbandit.app_links.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Keep widget receiver
-keep class com.example.foodlens_ai.QuickActionsWidget { *; }

# Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.**
