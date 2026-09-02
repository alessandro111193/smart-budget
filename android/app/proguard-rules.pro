# WorkManager (usato internamente da firebase_messaging per lo scheduling in
# background su Android) genera classi Room (androidx.work.impl.WorkDatabase e
# le sue _Impl) accedute via reflection: senza queste regole, la build
# release con isMinifyEnabled=true le rimuoveva/rinominava, causando un crash
# immediato all'avvio ("Failed to create an instance of
# androidx.work.impl.WorkDatabase"). Non attive finché isMinifyEnabled resta
# false in build.gradle.kts, ma pronte per quando verrà riattivata.
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class **_Impl { *; }
-dontwarn androidx.work.**
