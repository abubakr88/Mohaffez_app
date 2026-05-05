# ProGuard/R8 Rules for Mohaffez App
# These rules prevent code shrinking from breaking Flutter, Firebase, and other libraries

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Firebase App Check
-keep class com.google.firebase.appcheck.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Kotlin Coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Dart/Flutter JSON serialization
-keep class **.dart_tool.** { *; }
-keep class **.freezed.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable
-keep class * implements java.io.Serializable { *; }

# Keep R8 annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Prevent R8 from stripping interface methods from their implementations
-keepclassmembers class * {
    @java.lang.annotation.Retention *;
}
-keep @interface *

# Image loading libraries
-keep class com.bumptech.glide.** { *; }
-keep class com.squareup.picasso.** { *; }
-dontwarn com.bumptech.glide.**
-dontwarn com.squareup.picasso.**

# Location services
-keep class android.location.** { *; }
-keep class com.google.android.gms.location.** { *; }

# Notifications
-keep class androidx.core.app.** { *; }
-keep class androidx.core.content.** { *; }
