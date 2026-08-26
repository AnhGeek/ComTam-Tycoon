using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace ComTam.Unity.EditorTools
{
    /// <summary>
    /// Applies every Android player setting in code, and drives the CI build.
    ///
    /// Why a script instead of committing ProjectSettings.asset: that file is
    /// dense, version-specific Unity YAML. Hand-editing it is fragile and a
    /// malformed one is rejected silently or corrupts settings. Doing it through
    /// PlayerSettings is version-safe, reviewable in a diff, and re-runnable, so
    /// a fresh clone and CI end up byte-identical without anyone clicking through
    /// the Inspector.
    ///
    /// Run once after opening the project:  Cơm Tấm ▸ Android ▸ Apply Settings
    /// </summary>
    public static class AndroidBuildSetup
    {
        // ADR-0006
        private const string PackageId = "com.anhgeek.comtamtycoon";
        private const string ProductName = "Cơm Tấm Tycoon";
        private const string CompanyName = "AnhGeek";

        private const AndroidSdkVersions MinSdk = AndroidSdkVersions.AndroidApiLevel24;

        private const string ScenePath = "Assets/_Project/Scenes/Restaurant.unity";

        [MenuItem("Cơm Tấm/Android/Apply Settings")]
        public static void ApplyAndroidSettings()
        {
            ApplyAndroidSettings(null, 0);
        }

        /// <summary>
        /// <paramref name="version"/> is the human-readable name ("0.1.0");
        /// <paramref name="versionCode"/> is the integer Play orders builds by.
        /// Both come from the release tag in CI. Passing null/0 leaves them alone.
        /// </summary>
        public static void ApplyAndroidSettings(string version, int versionCode)
        {
            PlayerSettings.companyName = CompanyName;
            PlayerSettings.productName = ProductName;
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, PackageId);

            if (!string.IsNullOrEmpty(version)) PlayerSettings.bundleVersion = version;
            if (versionCode > 0) PlayerSettings.Android.bundleVersionCode = versionCode;

            // --- Orientation: portrait, locked (ADR-0002) ---
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = true;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;

            // --- SDK levels ---
            PlayerSettings.Android.minSdkVersion = MinSdk;
            // Play raises its target-API floor every August. AndroidApiLevelAuto
            // tracks the newest level this Unity install supports; verify against
            // Play's current requirement before submitting.
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;

            // --- Architectures: ARM64 is mandatory on Play; ARMv7 widens reach ---
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures =
                AndroidArchitecture.ARMv7 | AndroidArchitecture.ARM64;

            // --- Rendering ---
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[]
            {
                UnityEngine.Rendering.GraphicsDeviceType.Vulkan,
                UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3
            });
            PlayerSettings.Android.blitType = AndroidBlitType.Auto;
            PlayerSettings.MTRendering = true;

            // --- Size and stripping ---
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.Android, ManagedStrippingLevel.Medium);
            PlayerSettings.stripEngineCode = true;
            PlayerSettings.Android.useAPKExpansionFiles = false;

            // Play requires AAB; APK is for sideload testing. CI overrides this
            // per-build, so this is only the interactive default.
            EditorUserBuildSettings.buildAppBundle = false;

            PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.forceSDCardPermission = false;

            PlayerSettings.SetApiCompatibilityLevel(
                NamedBuildTarget.Android, ApiCompatibilityLevel.NET_Standard_2_1);

            AssetDatabase.SaveAssets();
            Debug.Log("[AndroidBuildSetup] Android settings applied. minSdk=" + MinSdk
                      + " id=" + PackageId);
        }

        /// <summary>
        /// CI entry point. Invoked headlessly:
        ///   -executeMethod ComTam.Unity.EditorTools.AndroidBuildSetup.BuildFromCommandLine
        /// Recognised args: -outputPath &lt;path&gt;  -buildAppBundle  -development
        /// </summary>
        public static void BuildFromCommandLine()
        {
            string[] args = Environment.GetCommandLineArgs();
            string output = ArgValue(args, "-outputPath") ?? "build/ComTamTycoon.apk";
            string version = ArgValue(args, "-appVersion");
            int versionCode;
            int.TryParse(ArgValue(args, "-versionCode") ?? "0", out versionCode);
            bool aab = args.Contains("-buildAppBundle");
            bool development = args.Contains("-development");

            ApplyAndroidSettings(version, versionCode);
            EditorUserBuildSettings.buildAppBundle = aab;

            if (!File.Exists(ScenePath))
            {
                Fail("Scene not found: " + ScenePath
                     + "\n\nThe Restaurant scene has not been built yet. Everything else"
                     + "\nin the pipeline is ready - this is the one remaining step, and"
                     + "\nit needs the Unity Editor once. See unity/SCENE-SETUP.md.");
                return;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output)));

            BuildPlayerOptions options = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = output,
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = development
                    ? BuildOptions.Development | BuildOptions.AllowDebugging
                    : BuildOptions.None
            };

            BuildReport report = BuildPipeline.BuildPlayer(options);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log(string.Format(
                    "[AndroidBuildSetup] BUILD OK  {0}  {1:N1} MB  {2:N0}s",
                    output, summary.totalSize / (1024f * 1024f), summary.totalTime.TotalSeconds));
                EditorApplication.Exit(0);
            }
            else
            {
                Fail("BUILD FAILED: " + summary.result
                     + " (" + summary.totalErrors + " errors)");
            }
        }

        private static void Fail(string message)
        {
            Debug.LogError("[AndroidBuildSetup] " + message);
            EditorApplication.Exit(1);
        }

        private static string ArgValue(string[] args, string flag)
        {
            int i = Array.IndexOf(args, flag);
            return (i >= 0 && i + 1 < args.Length) ? args[i + 1] : null;
        }

        /// <summary>
        /// Fails loudly if the font atlas is missing Vietnamese glyphs (ADR-0005).
        /// The failure mode is silent — tone marks vanish and a word becomes a
        /// different word — so it is checked mechanically rather than by eye.
        /// </summary>
        [MenuItem("Cơm Tấm/Android/Verify Vietnamese Font Coverage")]
        public static void VerifyVietnameseCoverage()
        {
            const string sample = "Cơm tấm sườn bì chả trứng — 45,000đ";
            TMPro.TMP_FontAsset font = TMPro.TMP_Settings.defaultFontAsset;

            if (font == null)
            {
                Debug.LogError("[FontCheck] No default TMP font asset assigned.");
                return;
            }

            string missing = new string(sample
                .Where(c => !char.IsWhiteSpace(c) && !font.HasCharacter(c))
                .Distinct()
                .ToArray());

            if (missing.Length == 0)
                Debug.Log("[FontCheck] OK — '" + font.name + "' covers the Vietnamese sample.");
            else
                Debug.LogError("[FontCheck] '" + font.name + "' is MISSING: " + missing
                               + "\nRegenerate the atlas with range 1EA0-1EF9 (see unity/SCENE-SETUP.md §1).");
        }
    }
}
