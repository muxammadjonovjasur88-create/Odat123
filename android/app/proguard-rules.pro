# Flutter wrapper rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase & Google Services
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn com.google.firebase.**
-keep public class com.google.firebase.** { *; }
-dontwarn com.google.android.gms.**
-keep public class com.google.android.gms.** { *; }

# MediaPipe & ML Kit
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.** { *; }

# Application models & code
-keep class com.flowa.** { *; }
-keep class com.company.flova.** { *; }

# Play Core & Split Install
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
