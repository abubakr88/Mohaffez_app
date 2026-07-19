# App-specific R8 rules only.
# Flutter and Android/Firebase libraries publish their own consumer rules. Broad
# keep rules here would prevent R8 from shrinking and optimizing the release.

# Preserve metadata used by libraries that inspect generic types or annotations.
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

# Preserve Java/Kotlin native method names used across JNI boundaries.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# SafetyNet is intentionally excluded in favor of Play Integrity. Older
# Firebase App Check artifacts retain optional references to these classes.
-dontwarn com.google.android.gms.safetynet.SafetyNet
-dontwarn com.google.android.gms.safetynet.SafetyNetApi$AttestationResponse
-dontwarn com.google.android.gms.safetynet.SafetyNetClient
