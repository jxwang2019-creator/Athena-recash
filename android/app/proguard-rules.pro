# ========== GOOGLE PLAY CORE ==========
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.common.** { *; }
-keep class com.google.android.play.core.assetdelivery.** { *; }
-keep class com.google.android.play.core.ktx.** { *; }

# ========== GOOGLE PLAY SERVICES ==========
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.common.annotation.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.** { *; }

# ========== TENSORFLOW LITE ==========
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-keep class org.tensorflow.lite.task.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keep class org.tensorflow.lite.examples.** { *; }

# ========== FLUTTER ENGINE ==========
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# ========== GENERAL RULES ==========
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Signature

-keepclasseswithmembers class * {
    native <methods>;
}

-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# ========== PLATFORM CHANNELS ==========
-keep class * extends io.flutter.plugin.common.MethodCallHandler { *; }
-keep class * extends io.flutter.plugin.common.EventChannel { *; }
-keep class * extends io.flutter.plugin.common.MethodChannel { *;

# ========== MAIN KEEP RULES ==========
-keep class com.google.android.play.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class io.flutter.** { *; }

# ========== ANNOTATION SUPPORT ==========
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature

# ========== NATIVE METHODS ==========
-keepclasseswithmembernames class * {
    native <methods>;
}

# ========== PARCELABLE MODELS ==========
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}