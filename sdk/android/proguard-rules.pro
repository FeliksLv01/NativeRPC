# Add project specific ProGuard rules here.
# Keep kotlinx.serialization annotations
-keepattributes *Annotation*

# Keep serializable classes
-keep class com.nativerpc.core.** { *; }
-keep class com.nativerpc.dsl.** { *; }
-keep class com.nativerpc.connection.** { *; }

# kotlinx.serialization
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.nativerpc.**$$serializer { *; }
-keepclassmembers class com.nativerpc.** {
    *** Companion;
}
-keepclasseswithmembers class com.nativerpc.** {
    kotlinx.serialization.KSerializer serializer(...);
}
